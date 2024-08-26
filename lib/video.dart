import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';

class NextPage1 extends StatefulWidget {
  const NextPage1.NextPage1({Key? key}) : super(key: key);

  @override
  _NextPage1State createState() => _NextPage1State();
}

class _NextPage1State extends State<NextPage1> {
  late VideoPlayerController _videoController;
  late CameraController _cameraController;
  bool _isVideoLoading = false;
  bool _isCameraInitialized = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeCamera();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoUrl = 'http://10.0.2.2:8000/video_feed'; // Emülatörde localhost için IP adresi
      _videoController = VideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          setState(() {
            _isVideoLoading = false;
          });
          _videoController.play();
        });
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void initialize() async{
    WidgetsFlutterBinding.ensureInitialized();
    final cameras =await availableCameras();

    await _initializeCamera();
    await _initializeVideo();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front);

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController.startImageStream((image) {
        print('Got frame');
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    initialize();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Stream'),
      ),
      body: Center(
        child: Column(
          children: [
            _isVideoLoading
                ? const CircularProgressIndicator()
                : AspectRatio(
              aspectRatio: _videoController.value.aspectRatio,
              child: VideoPlayer(_videoController),
            ),
            _isCameraInitialized
                ? AspectRatio(
              aspectRatio: _cameraController.value.aspectRatio,
              child: CameraPreview(_cameraController),
            )
                : const CircularProgressIndicator(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _videoController.value.isPlaying
                ? _videoController.pause()
                : _videoController.play();
          });
        },
        child: Icon(
          _videoController.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
