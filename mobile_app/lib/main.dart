import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error fetching cameras: $e');
  }
  runApp(const MovozenApp());
}

class MovozenApp extends StatelessWidget {
  const MovozenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movozen Dashcam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
        ),
      ),
      home: const DashcamHomeScreen(),
    );
  }
}

class DashcamHomeScreen extends StatefulWidget {
  const DashcamHomeScreen({super.key});

  @override
  State<DashcamHomeScreen> createState() => _DashcamHomeScreenState();
}

class _DashcamHomeScreenState extends State<DashcamHomeScreen> {
  CameraController? _cameraController;
  WebSocketChannel? _channel;
  
  final TextEditingController _rollNoController = TextEditingController(text: 'BTECH2510223');
  final TextEditingController _serverIpController = TextEditingController(text: '10.21.31.200');

  bool _isStreaming = false;
  bool _isCameraReady = false;
  int _selectedCameraIndex = 0;
  String _statusText = 'STANDBY';
  int _streamSeconds = 0;
  Timer? _timer;
  int _totalBytesSent = 0;
  int _frameCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestPermissionsAndInitCamera();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoll = prefs.getString('movozen_roll_no');
    final savedIp = prefs.getString('movozen_server_ip');
    if (savedRoll != null && savedRoll.isNotEmpty) {
      _rollNoController.text = savedRoll;
    }
    if (savedIp != null && savedIp.isNotEmpty) {
      _serverIpController.text = savedIp;
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('movozen_roll_no', _rollNoController.text.trim());
    await prefs.setString('movozen_server_ip', _serverIpController.text.trim());
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (_cameras.isNotEmpty) {
      await _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int index) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initCamera(_selectedCameraIndex);
  }

  void _startStreaming() {
    final rawRoll = _rollNoController.text.trim().toUpperCase();
    final roll = rawRoll.replaceAll(RegExp(r'[\/\\ ]'), '');
    if (roll.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter student roll number!')),
      );
      return;
    }

    final ip = _serverIpController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter server IP address!')),
      );
      return;
    }

    _saveSettings();

    final wsUrl = 'ws://$ip:3000';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.sink.add('{"type":"start","rollNo":"$roll","camera":"${_selectedCameraIndex == 0 ? "front" : "back"}","format":"raw_yuv","width":640,"height":480}');

      WakelockPlus.enable();

      setState(() {
        _isStreaming = true;
        _statusText = 'LIVE DASHCAM';
        _streamSeconds = 0;
        _totalBytesSent = 0;
        _frameCounter = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _streamSeconds++;
          });
        }
      });

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        _cameraController!.startImageStream((CameraImage image) {
          if (!_isStreaming || _channel == null) return;
          _frameCounter++;
          if (_frameCounter % 2 != 0) return; // Drop alternate frames for smooth transmission

          try {
            final WriteBuffer allBytes = WriteBuffer();
            for (final Plane plane in image.planes) {
              allBytes.putUint8List(plane.bytes);
            }
            final bytes = allBytes.done().buffer.asUint8List();
            _channel!.sink.add(bytes);
            _totalBytesSent += bytes.length;
          } catch (e) {
            debugPrint('Frame send error: $e');
          }
        });
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WebSocket Connection Failed: $e')),
      );
    }
  }

  void _stopStreaming() {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    if (_channel != null) {
      _channel!.sink.add('{"type":"stop"}');
      _channel!.sink.close();
      _channel = null;
    }

    _timer?.cancel();
    WakelockPlus.disable();

    setState(() {
      _isStreaming = false;
      _statusText = 'STANDBY';
    });
  }

  String _formatTime(int sec) {
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _channel?.sink.close();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF12131C),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'MOVOZEN DASHCAM',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isStreaming ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isStreaming ? Colors.red : Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 4,
                          backgroundColor: _isStreaming ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: _isStreaming ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Camera Viewport
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _isCameraReady && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator()),
                  ),

                  // HUD Overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ID: ${_rollNoController.text}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatTime(_streamSeconds),
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isStreaming)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'SENT: ${(_totalBytesSent / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Controls Panel
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF12131C),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rollNoController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _serverIpController,
                          decoration: const InputDecoration(
                            labelText: 'Relay Server IP',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 0, height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _cameras.length > 1 ? _switchCamera : null,
                        icon: const Icon(Icons.switch_camera, size: 28),
                        tooltip: 'Switch Camera',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isStreaming ? Colors.red : Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                          label: Text(
                            _isStreaming ? 'STOP DASHCAM STREAM' : 'START DASHCAM STREAM',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
