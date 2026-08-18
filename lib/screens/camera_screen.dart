import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'issue_submission_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // Get the current location
    _currentPosition = await Geolocator.getCurrentPosition();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras found');
    }
    _cameras = cameras;
    _initializeCameraController(0);
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller!.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await _controller!.initialize();
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isCameraInitialized = false);
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    await _initializeCameraController(_selectedCameraIndex);
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null) return;

    // Capture the BuildContext before any async operations
    final BuildContext currentContext = this.context;

    try {
      final XFile picture = await _controller!.takePicture();

      if (!mounted) return;

      final File imageFile = File(picture.path);
      if (!await imageFile.exists()) {
        debugPrint('Error: Image file does not exist at ${picture.path}');
        if (mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Error: Failed to capture image')),
          );
        }
        return;
      }

      if (!mounted) return;

      await Navigator.of(currentContext).push(
        MaterialPageRoute(
          builder: (BuildContext context) => IssueSubmissionScreen(
            initialImage: imageFile,
            latitude: _currentPosition?.latitude,
            longitude: _currentPosition?.longitude,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in _takePicture: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(
            currentContext,
          ).showSnackBar(SnackBar(content: Text('Error taking picture: $e')));
        } catch (_) {
          // Ignore if context is no longer valid
        }
      }
    }
  }

  void _updateZoom(double zoom) {
    if (!_isCameraInitialized || _controller == null) return;

    setState(() {
      _currentZoomLevel = zoom;
    });

    _controller!.setZoomLevel(zoom);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Initializing camera...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_controller != null && _controller!.value.hasError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${_controller!.value.errorDescription}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Zoom Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _currentZoomLevel,
                          min: _minZoomLevel,
                          max: _maxZoomLevel,
                          onChanged: _updateZoom,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white54,
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Camera Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        // Toggle flash
                        _controller!.setFlashMode(
                          _controller!.value.flashMode == FlashMode.off
                              ? FlashMode.torch
                              : FlashMode.off,
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cameraswitch,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _toggleCamera,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
