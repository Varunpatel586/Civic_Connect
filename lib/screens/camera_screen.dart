import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'issue_submission_screen.dart';

/// Captures the photograph that opens a complaint.
///
/// Location is gathered in parallel with the preview warming up, because the
/// GPS fix usually takes longer than the citizen does to frame a pothole. It is
/// deliberately non-fatal here: [IssueSubmissionScreen] retries and blocks
/// filing if it still cannot get one.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _isReady = false;
  bool _isCapturing = false;
  String? _fatalError;

  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    _startLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Releases the camera when the app goes to the background and takes it back
  /// on return. Without this, coming back from the app switcher leaves a frozen
  /// preview — an easy way to lose a live demo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      if (mounted) setState(() => _isReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _openCamera(_cameraIndex);
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() => _fatalError = 'This device has no camera available.');
        return;
      }

      _cameras = cameras;
      await _openCamera(0);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _fatalError =
            'Camera could not be opened. Check that Civic Connect has camera permission.',
      );
    }
  }

  Future<void> _openCamera(int index) async {
    if (_cameras.isEmpty) return;

    await _controller?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;

    try {
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();

      if (!mounted) return;
      setState(() {
        _cameraIndex = index;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
        _isReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _fatalError =
            'Camera could not start. Check that Civic Connect has camera permission.',
      );
    }
  }

  /// Best-effort. Errors are swallowed on purpose — a missing fix must not stop
  /// the citizen taking the photograph.
  Future<void> _startLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('CameraScreen: no location fix yet: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isReady = false);
    await _openCamera(_cameraIndex == 0 ? 1 : 0);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_isReady) return;

    final next = controller.value.flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    await controller.setFlashMode(next);
    if (mounted) setState(() {});
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null || !_isReady) return;
    setState(() => _zoom = value);
    await controller.setZoomLevel(value);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !_isReady || _isCapturing) return;

    setState(() => _isCapturing = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // takePicture returns an XFile, which works on every platform — there is
      // no dart:io handle to wrap it in on web.
      final shot = await controller.takePicture();

      if (await shot.length() == 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The photo could not be saved.')),
        );
        return;
      }

      await navigator.push(
        MaterialPageRoute(
          builder: (_) => IssueSubmissionScreen(
            initialImage: shot,
            latitude: _latitude,
            longitude: _longitude,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not take the photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _fatalError != null
          ? _CameraError(message: _fatalError!)
          : !_isReady
          ? const _CameraWarmup()
          : _buildPreview(),
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        const _TopScrim(),
        Positioned(
          top: 8,
          left: 4,
          right: 8,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _LocationPill(hasFix: _latitude != null),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_maxZoom > _minZoom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Slider(
                      value: _zoom.clamp(_minZoom, _maxZoom),
                      min: _minZoom,
                      max: _maxZoom,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: _setZoom,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 28,
                      color: Colors.white,
                      icon: Icon(
                        _controller?.value.flashMode == FlashMode.torch
                            ? Icons.flash_on
                            : Icons.flash_off,
                      ),
                      onPressed: _toggleFlash,
                    ),
                    _ShutterButton(
                      isCapturing: _isCapturing,
                      onTap: _capture,
                    ),
                    IconButton(
                      iconSize: 28,
                      color: _cameras.length > 1 ? Colors.white : Colors.white38,
                      icon: const Icon(Icons.cameraswitch_outlined),
                      onPressed: _cameras.length > 1 ? _flipCamera : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the white controls legible over a bright sky.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Tells the citizen up front whether this photo will carry coordinates.
class _LocationPill extends StatelessWidget {
  final bool hasFix;

  const _LocationPill({required this.hasFix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFix ? Icons.my_location : Icons.location_searching,
            size: 12,
            color: hasFix ? Colors.white : AppColors.amber700,
          ),
          const SizedBox(width: 5),
          Text(
            hasFix ? 'LOCATION READY' : 'FINDING LOCATION',
            style: AppTypography.badge(
              color: hasFix ? Colors.white : AppColors.amber700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _ShutterButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: Container(
        width: 68,
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isCapturing ? Colors.white54 : Colors.white,
            shape: BoxShape.circle,
          ),
          child: isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.navy900,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _CameraWarmup extends StatelessWidget {
  const _CameraWarmup();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Starting camera…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final String message;

  const _CameraError({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 42,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
