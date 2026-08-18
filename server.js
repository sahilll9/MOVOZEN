const express = require('express');
const http = require('http');
const https = require('https');
const WebSocket = require('ws');
const path = require('path');
const { spawn } = require('child_process');
const ffmpegPath = require('ffmpeg-static');
const os = require('os');
const selfsigned = require('selfsigned');

const app = express();
const PORT = process.env.PORT || 3000;
const HTTPS_PORT = process.env.HTTPS_PORT || 3443;
const RTMP_SERVER_BASE = 'rtmp://15.207.177.194:1936/hackathon';

// Generate Self-Signed SSL Certificate for HTTPS Camera Access on Mobile
const attrs = [{ name: 'commonName', value: 'MovozenDashcam' }];
const pkey = selfsigned.generate(attrs, { days: 365 });

const options = {
  key: pkey.private,
  cert: pkey.cert
};

app.use(express.static(path.join(__dirname, 'public')));
app.use('/apk', express.static(path.join(__dirname, 'mobile_app', 'build', 'app', 'outputs', 'flutter-apk')));

function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses;
}

app.get('/api/info', (req, res) => {
  res.json({
    rtmpServer: RTMP_SERVER_BASE,
    viewerUrl: 'http://15.207.177.194:8081/web/player.html',
    localIps: getLocalIpAddresses(),
    port: PORT,
    httpsPort: HTTPS_PORT
  });
});

const httpServer = http.createServer(app);
const httpsServer = https.createServer(options, app);

// WebSocket Server attached to both HTTP and HTTPS
const wss = new WebSocket.Server({ noServer: true });

httpServer.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

httpsServer.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

wss.on('connection', (ws) => {
  console.log('[WebSocket] Client connected');
  let ffmpegProcess = null;
  let currentRollNo = '';
  let currentCamera = 'front';
  let isStreaming = false;

  function stopFfmpeg() {
    if (ffmpegProcess) {
      console.log('[FFmpeg] Terminating process...');
      try {
        ffmpegProcess.stdin.end();
        ffmpegProcess.kill('SIGINT');
      } catch (err) {
        console.error('[FFmpeg] Error stopping:', err.message);
      }
      ffmpegProcess = null;
    }
    isStreaming = false;
  }

  function startFfmpeg(rollNo, cameraSuffix, formatInfo = {}) {
    if (ffmpegProcess) {
      console.log('[FFmpeg] Stream already active, skipping re-start.');
      return;
    }

    // Strip slashes and spaces so RTMP treats it as stream key (e.g. BTECH/25102/23 -> BTECH2510223)
    const cleanRollNo = (rollNo || '').replace(/[\/\\ ]/g, '').toUpperCase();
    const targetUrl = `${RTMP_SERVER_BASE}/${cleanRollNo}_${cameraSuffix}`;
    console.log(`[FFmpeg] Starting RTMP stream to target: ${targetUrl} (format: ${formatInfo.format || 'webm'})`);

    let inputArgs = ['-f', 'webm', '-i', '-'];
    if (formatInfo.format === 'raw_yuv') {
      const w = formatInfo.width || 640;
      const h = formatInfo.height || 480;
      const fps = formatInfo.fps || 15;
      inputArgs = [
        '-f', 'rawvideo',
        '-pix_fmt', 'nv21',
        '-s', `${w}x${h}`,
        '-r', `${fps}`,
        '-i', '-'
      ];
    }

    const ffmpegArgs = [
      ...inputArgs,
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-tune', 'zerolatency',
      '-g', '30',
      '-r', '25',
      '-s', '1280x720',
      '-b:v', '1500k',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-f', 'flv',
      targetUrl
    ];

    ffmpegProcess = spawn(ffmpegPath, ffmpegArgs);
    ffmpegProcess.stdin.on('error', (e) => {
      console.log('[FFmpeg stdin error]', e.message);
    });
    isStreaming = true;

    ffmpegProcess.stderr.on('data', (data) => {
      const msg = data.toString();
      console.log('[FFmpeg Log]', msg);
      if (msg.includes('frame=') || msg.includes('fps=')) {
        ws.send(JSON.stringify({ type: 'ffmpeg-stat', data: msg.trim() }));
      }
    });

    ffmpegProcess.on('close', (code) => {
      console.log(`[FFmpeg] Process exited with code ${code}`);
      isStreaming = false;
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'status', status: 'stopped', code }));
      }
    });

    ffmpegProcess.on('error', (err) => {
      console.error('[FFmpeg] Error:', err);
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'error', message: err.message }));
      }
    });
  }

  ws.on('message', (message, isBinary) => {
    if (isBinary || Buffer.isBuffer(message) || message instanceof ArrayBuffer || ArrayBuffer.isView(message)) {
      const buf = Buffer.isBuffer(message) ? message : Buffer.from(message);
      if (!ffmpegProcess) {
        console.log('[WebSocket] Auto-starting FFmpeg for incoming binary video stream...');
        startFfmpeg(currentRollNo || 'BTECH2510223', currentCamera || 'front');
      }
      if (ffmpegProcess && ffmpegProcess.stdin && ffmpegProcess.stdin.writable) {
        ffmpegProcess.stdin.write(buf);
      }
      return;
    }

    try {
      const data = JSON.parse(message.toString());
      console.log('[WebSocket] Control message parsed:', data);
      if (data.type === 'start') {
        currentRollNo = (data.rollNo || 'DEMO').trim().toUpperCase();
        currentCamera = data.camera || 'front';
        startFfmpeg(currentRollNo, currentCamera, data);
        ws.send(JSON.stringify({
          type: 'status',
          status: 'streaming',
          streamUrl: `${RTMP_SERVER_BASE}/${currentRollNo}_${currentCamera}`
        }));
      } else if (data.type === 'stop') {
        stopFfmpeg();
        ws.send(JSON.stringify({ type: 'status', status: 'stopped' }));
      }
    } catch (e) {
      // If it failed JSON parse, try writing to FFmpeg as fallback binary
      const buf = Buffer.isBuffer(message) ? message : Buffer.from(message);
      if (ffmpegProcess && ffmpegProcess.stdin && ffmpegProcess.stdin.writable) {
        ffmpegProcess.stdin.write(buf);
      }
    }
  });

  ws.on('close', () => {
    stopFfmpeg();
  });
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`[HTTP] Running on port ${PORT}`);
});

httpsServer.listen(HTTPS_PORT, '0.0.0.0', () => {
  const ips = getLocalIpAddresses();
  console.log(`\n==================================================`);
  console.log(`🚗 MOVOZEN POCKET DASHCAM SERVER (HTTPS ACTIVE) 🚀`);
  ips.forEach(ip => {
    console.log(`- HTTPS Mobile URL: https://${ip}:${HTTPS_PORT} (FOR MOBILE CAMERA)`);
  });
  console.log(`==================================================\n`);
});
