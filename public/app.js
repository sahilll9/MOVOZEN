// MoboSafe Pocket Dashcam App Client
(function () {
  'use strict';

  // DOM Elements
  const webcamPreview = document.getElementById('webcamPreview');
  const rollNoInput = document.getElementById('rollNoInput');
  const saveRollBtn = document.getElementById('saveRollBtn');
  const rtmpTargetUrl = document.getElementById('rtmpTargetUrl');
  const toggleStreamBtn = document.getElementById('toggleStreamBtn');
  const statusPill = document.getElementById('statusPill');
  const statusText = document.getElementById('statusText');
  const recBadge = document.getElementById('recBadge');
  const hudRoll = document.getElementById('hudRoll');
  const hudTime = document.getElementById('hudTime');
  const hudBitrate = document.getElementById('hudBitrate');
  const hudData = document.getElementById('hudData');
  const audioBarFill = document.getElementById('audioBarFill');
  const ipList = document.getElementById('ipList');
  const openFlvBtn = document.getElementById('openFlvBtn');
  const segBtns = document.querySelectorAll('.seg-btn');
  const wakeLockBadge = document.getElementById('wakeLockBadge');

  // App State
  let selectedCamera = 'front';
  let rollNumber = localStorage.getItem('movozen_roll_no') || 'BTECH/25102/23';
  let mediaStream = null;
  let mediaRecorder = null;
  let ws = null;
  let isStreaming = false;
  let wakeLock = null;

  // Telemetry & Stats
  let streamStartTime = 0;
  let streamTimerInterval = null;
  let totalBytesSent = 0;
  let bytesInLastSecond = 0;
  let bitrateInterval = null;

  // Audio Context
  let audioContext = null;
  let analyser = null;
  let microphoneSource = null;

  const RTMP_BASE = 'rtmp://15.207.177.194:1936/hackathon';

  init();

  async function init() {
    rollNoInput.value = rollNumber;
    updateHudRollNumber();
    updateRtmpUrlDisplay();
    fetchServerInfo();
    setupCameraControls();

    // Try camera preview, if blocked wait for user tap
    try {
      await requestCameraAndMic();
    } catch (e) {
      console.log('Camera permission pending user gesture...');
    }

    requestWakeLock();
  }

  async function fetchServerInfo() {
    try {
      const res = await fetch('/api/info');
      const data = await res.json();
      if (data.localIps && data.localIps.length > 0) {
        ipList.innerHTML = data.localIps.map(ip => `<code>http://${ip}:${data.port}</code>`).join('<br>');
      }
    } catch (e) {}
  }

  function updateHudRollNumber() {
    const raw = rollNoInput.value || 'BTECH2510223';
    const clean = raw.replace(/[\/\\ ]/g, '').toUpperCase();
    hudRoll.textContent = `ID: ${clean}`;
  }

  function updateRtmpUrlDisplay() {
    const raw = rollNoInput.value || 'BTECH2510223';
    const clean = raw.replace(/[\/\\ ]/g, '').toUpperCase();
    rtmpTargetUrl.textContent = `${RTMP_BASE}/${clean}_${selectedCamera}`;
  }

  rollNoInput.addEventListener('input', () => {
    updateHudRollNumber();
    updateRtmpUrlDisplay();
  });

  saveRollBtn.addEventListener('click', () => {
    rollNumber = rollNoInput.value.trim().toUpperCase();
    localStorage.setItem('movozen_roll_no', rollNumber);
    alert(`Roll number ${rollNumber} saved!`);
  });

  function setupCameraControls() {
    segBtns.forEach(btn => {
      btn.addEventListener('click', async () => {
        segBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        selectedCamera = btn.getAttribute('data-cam');
        updateRtmpUrlDisplay();
        await requestCameraAndMic();
      });
    });
  }

  // Direct User Gesture Camera & Mic Request (Triggers Permission Popup)
  async function requestCameraAndMic() {
    if (mediaStream) {
      mediaStream.getTracks().forEach(t => t.stop());
    }

    const facing = (selectedCamera === 'front') ? 'user' : { exact: 'environment' };
    
    try {
      mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: facing, width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: true
      });
    } catch (e) {
      // Fallback constraint
      mediaStream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true
      });
    }

    webcamPreview.srcObject = mediaStream;
    setupAudioAnalyzer(mediaStream);
    return mediaStream;
  }

  function setupAudioAnalyzer(stream) {
    if (audioContext) audioContext.close();
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      audioContext = new AudioCtx();
      analyser = audioContext.createAnalyser();
      analyser.fftSize = 64;
      microphoneSource = audioContext.createMediaStreamSource(stream);
      microphoneSource.connect(analyser);

      const dataArray = new Uint8Array(analyser.frequencyBinCount);
      function updateAudioMeter() {
        if (!analyser) return;
        analyser.getByteFrequencyData(dataArray);
        let sum = dataArray.reduce((a, b) => a + b, 0);
        let volumePct = Math.min(100, Math.round((sum / dataArray.length / 128) * 100));
        audioBarFill.style.width = `${volumePct}%`;
        requestAnimationFrame(updateAudioMeter);
      }
      updateAudioMeter();
    } catch (e) {}
  }

  async function requestWakeLock() {
    try {
      if ('wakeLock' in navigator) {
        wakeLock = await navigator.wakeLock.request('screen');
      }
    } catch (err) {}
  }

  // Handle Stream Start Button Click
  toggleStreamBtn.addEventListener('click', async () => {
    if (isStreaming) {
      stopStreaming();
      return;
    }

    const roll = (rollNoInput.value || '').trim().toUpperCase();
    if (!roll) {
      alert('Please enter your Student Roll Number!');
      rollNoInput.focus();
      return;
    }

    // Force permission popup request directly on button tap!
    try {
      if (!mediaStream || !mediaStream.active) {
        await requestCameraAndMic();
      }
    } catch (err) {
      alert('Camera & Microphone permission is required to stream! Please allow permissions when prompted by your browser.');
      return;
    }

    startStreaming(roll);
  });

  function startStreaming(roll) {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.host}`;
    
    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      ws.send(JSON.stringify({
        type: 'start',
        rollNo: roll,
        camera: selectedCamera
      }));

      startMediaRecorder();
      setUiStreamingState(true);
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'ffmpeg-stat' && msg.data.includes('bitrate=')) {
          const match = msg.data.match(/bitrate=\s*([\d\.]+\s*\w+\/s)/);
          if (match) hudBitrate.textContent = match[1];
        }
      } catch (e) {}
    };

    ws.onclose = () => {
      if (isStreaming) {
        setTimeout(() => { if (isStreaming) startStreaming(roll); }, 2000);
      }
    };
  }

  function startMediaRecorder() {
    let options = { mimeType: 'video/webm;codecs=vp8,opus' };
    if (!MediaRecorder.isTypeSupported(options.mimeType)) {
      options = MediaRecorder.isTypeSupported('video/webm') ? { mimeType: 'video/webm' } : {};
    }

    try {
      mediaRecorder = new MediaRecorder(mediaStream, options);
    } catch (e) {
      alert('MediaRecorder error: ' + e.message);
      return;
    }

    totalBytesSent = 0;
    bytesInLastSecond = 0;

    mediaRecorder.ondataavailable = async (event) => {
      if (event.data && event.data.size > 0 && ws && ws.readyState === WebSocket.OPEN) {
        const buffer = await event.data.arrayBuffer();
        ws.send(buffer);
        totalBytesSent += buffer.byteLength;
        bytesInLastSecond += buffer.byteLength;
        hudData.textContent = (totalBytesSent / (1024 * 1024)).toFixed(1) + ' MB';
      }
    };

    mediaRecorder.start(500);
  }

  function stopStreaming() {
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
    }
    if (ws) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'stop' }));
      }
      ws.close();
    }
    setUiStreamingState(false);
  }

  function setUiStreamingState(streaming) {
    isStreaming = streaming;
    if (streaming) {
      statusPill.classList.add('live');
      statusText.textContent = 'LIVE DASHCAM';
      recBadge.classList.add('active');
      toggleStreamBtn.classList.add('streaming');
      toggleStreamBtn.innerHTML = '<span class="btn-icon">⏹️</span> STOP DASHCAM STREAM';

      streamStartTime = Date.now();
      streamTimerInterval = setInterval(updateStreamTimer, 1000);
      bitrateInterval = setInterval(updateBitrateCalc, 1000);
    } else {
      statusPill.classList.remove('live');
      statusText.textContent = 'STANDBY';
      recBadge.classList.remove('active');
      toggleStreamBtn.classList.remove('streaming');
      toggleStreamBtn.innerHTML = '<span class="btn-icon">🔴</span> START DASHCAM STREAM';

      clearInterval(streamTimerInterval);
      clearInterval(bitrateInterval);
      hudTime.textContent = '00:00:00';
      hudBitrate.textContent = '0 kbps';
    }
  }

  function updateStreamTimer() {
    const elapsedSec = Math.floor((Date.now() - streamStartTime) / 1000);
    const hrs = String(Math.floor(elapsedSec / 3600)).padStart(2, '0');
    const mins = String(Math.floor((elapsedSec % 3600) / 60)).padStart(2, '0');
    const secs = String(elapsedSec % 60).padStart(2, '0');
    hudTime.textContent = `${hrs}:${mins}:${secs}`;
  }

  function updateBitrateCalc() {
    const kbps = Math.round((bytesInLastSecond * 8) / 1024);
    hudBitrate.textContent = `${kbps} kbps`;
    bytesInLastSecond = 0;
  }

  openFlvBtn.addEventListener('click', () => {
    const roll = (rollNoInput.value || 'BTECH/25102/23').trim().toUpperCase();
    window.open(`http://15.207.177.194:8081/hackathon/${roll}_${selectedCamera}.flv`, '_blank');
  });

})();
