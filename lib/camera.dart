import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NextPage(),
    );
  }
}

class NextPage extends StatefulWidget {
  const NextPage({Key? key}) : super(key: key);

  @override
  _NextPageState createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final List<Uint8List> _frames = [];
  bool _isConnected = false;
  bool _isPaused = false;
  bool _isSendingFrames = true;
  int _currentIndex = 0; // current index of displayed frame

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchFramesPeriodically();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.isNotEmpty ? cameras.first : null;

      if (frontCamera != null) {
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.low,
          imageFormatGroup: ImageFormatGroup.yuv420, // YUV formatında gönder
        );

        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });

        _cameraController!.startImageStream((CameraImage image) {
          if (_isSendingFrames) {
            _sendFrameToFlask(image);
          }
        });
      } else {
        print('Ön kamera bulunamadı.');
      }
    } catch (e) {
      print('Kamera başlatma hatası: $e');
    }
  }

  void _sendFrameToFlask(CameraImage image) async {
    try {
      // Image'ı Uint8List formatına dönüştürün
      final int width = image.width;
      final int height = image.height;
      final List<int> bytes = [];
      for (int i = 0; i < image.planes.length; i++) {
        bytes.addAll(image.planes[i].bytes);
      }
      final Uint8List data = Uint8List.fromList(bytes);

      // HTTP isteği yaparak Flask sunucusuna gönderin
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/upload_frame'),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Frame-Width': width.toString(),
          'Frame-Height': height.toString(),
        },
        body: data,
      );

      if (response.statusCode == 200) {
        print('Çerçeve başarıyla gönderildi');
      } else {
        print('Çerçeve gönderilirken hata oluştu: ${response.statusCode}');
      }
    } catch (e) {
      print('Çerçeve gönderilirken hata oluştu: $e');
    }
  }

  Future<void> _fetchFramesPeriodically() async {
    setState(() {
      _isConnected = true;
    });

    while (_isConnected) {
      if (!_isPaused) {
        await _fetchFrameFromFlask();
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _fetchFrameFromFlask() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:5001/get_frame'));
      if (response.statusCode == 200) {
        final decodedFrame = base64Decode(jsonDecode(response.body)['frame']);
        setState(() {
          _frames.add(decodedFrame);
          _currentIndex = _frames.length - 1; // update index to show the latest frame
        });
      } else {
        print('Çerçeve alınırken hata oluştu: ${response.statusCode}');
      }
    } catch (e) {
      print('Çerçeve alınırken hata oluştu: $e');
    }
  }

  void _togglePaused() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _isConnected = false;
    } else {
      _fetchFramesPeriodically();
    }
  }

  void _showNextFrame() {
    if (_frames.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _frames.length;
      });
    }
  }

  void _stopSendingFrames() {
    setState(() {
      _isSendingFrames = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görüntü Gösterimi'),
        actions: <Widget>[
          IconButton(
            icon: _isPaused ? Icon(Icons.play_arrow) : Icon(Icons.pause),
            onPressed: _togglePaused,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: _showNextFrame,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: _isConnected
                ? _frames.isNotEmpty
                ? Image.memory(
              _frames[_currentIndex],
              gaplessPlayback: true,
            )
                : const Center(child: CircularProgressIndicator())
                : const Center(
              child: Text("Bağlantı Kurulmadı"),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _isCameraInitialized
                  ? AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              )
                  : const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _stopSendingFrames,
        child: Icon(Icons.stop),
      ),
    );
  }
}
