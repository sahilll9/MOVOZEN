const { spawn } = require('child_process');
const ffmpegPath = require('ffmpeg-static');

const ROLL_NO = 'BTECH2510223';
const RTMP_BASE = 'rtmp://15.207.177.194:1936/hackathon';

console.log(`🚀 Launching Direct Hardware Dashcam Streamer for Roll: ${ROLL_NO}...`);

// Stream 1: Real Hardware Camera (HP Wide Vision HD Camera) -> _front
function startFrontHardwareStream() {
  const url = `${RTMP_BASE}/${ROLL_NO}_front`;
  console.log(`[FRONT CAM] Direct Hardware Stream -> ${url}`);

  const args = [
    '-f', 'dshow',
    '-i', 'video=HP Wide Vision HD Camera',
    '-f', 'lavfi',
    '-i', 'sine=frequency=1000:sample_rate=44100',
    '-c:v', 'libx264',
    '-preset', 'ultrafast',
    '-tune', 'zerolatency',
    '-g', '50',
    '-r', '25',
    '-s', '1280x720',
    '-b:v', '1500k',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
    '-b:a', '128k',
    '-f', 'flv',
    url
  ];

  const p = spawn(ffmpegPath, args);

  p.stderr.on('data', d => {
    const s = d.toString();
    if (s.includes('frame=')) console.log(`[FRONT REAL CAM] ${s.trim()}`);
  });

  p.on('close', code => {
    console.log(`[FRONT] Hardware stream exited (code ${code}), restarting...`);
    setTimeout(startFrontHardwareStream, 2000);
  });
}

// Stream 2: Vivid Dynamic Feed -> _back
function startBackVividStream() {
  const url = `${RTMP_BASE}/${ROLL_NO}_back`;
  console.log(`[BACK CAM] Vivid Test Pattern -> ${url}`);

  const args = [
    '-re',
    '-f', 'lavfi',
    '-i', 'testsrc2=size=1280x720:rate=25',
    '-f', 'lavfi',
    '-i', 'sine=frequency=800:sample_rate=44100',
    '-c:v', 'libx264',
    '-preset', 'ultrafast',
    '-tune', 'zerolatency',
    '-g', '50',
    '-b:v', '1500k',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
    '-b:a', '128k',
    '-f', 'flv',
    url
  ];

  const p = spawn(ffmpegPath, args);

  p.stderr.on('data', d => {
    const s = d.toString();
    if (s.includes('frame=')) console.log(`[BACK VIVID] ${s.trim()}`);
  });

  p.on('close', code => {
    console.log(`[BACK] Exited (code ${code}), restarting...`);
    setTimeout(startBackVividStream, 2000);
  });
}

startFrontHardwareStream();
startBackVividStream();
