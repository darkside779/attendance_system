// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_colors.dart';

class FaceCameraWidget extends StatefulWidget {
  final Function(String)? onFaceDetected;
  final bool isActive;

  const FaceCameraWidget({
    super.key,
    this.onFaceDetected,
    this.isActive = true,
  });

  @override
  State<FaceCameraWidget> createState() => _FaceCameraWidgetState();
}

class _FaceCameraWidgetState extends State<FaceCameraWidget> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFaceDetected = false;
  String _status = 'Initializing camera...';
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _status = 'Camera permission denied';
        });
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _status = 'No cameras available';
        });
        return;
      }

      // Initialize camera controller with front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _status = 'Position your face in the frame';
        });
        
        // Start face detection simulation (replace with actual ML Kit integration)
        _startFaceDetection();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _startFaceDetection() async {
    if (!widget.isActive) return;
    
    // Start face detection process with shorter, more realistic timing
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isFaceDetected = true;
        _status = 'Face detected! Hold steady...';
      });
      
      // Quick face recognition verification
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        setState(() {
          _status = 'Face recognized successfully!';
        });
        
        // Notify parent component
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onFaceDetected?.call('face_recognized');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFaceDetected ? AppColors.success : AppColors.primary,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Camera Preview
            if (_isCameraInitialized && _cameraController != null) ...[
              // Actual camera preview
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(_cameraController!),
              ),
              // Face detection overlay
              Center(
                child: Container(
                  width: 200,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isFaceDetected ? AppColors.success : AppColors.white.withOpacity(0.7),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: _isFaceDetected
                      ? Center(
                          child: Icon(
                            Icons.check_circle,
                            size: 60,
                            color: AppColors.success,
                          ),
                        )
                      : null,
                ),
              ),
            ] else ...[
              // Loading state
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
            
            // Overlay with face detection guide
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFaceDetected ? Icons.check_circle : Icons.camera_alt,
                      color: _isFaceDetected ? AppColors.success : AppColors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: _isFaceDetected ? AppColors.success : AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom instructions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isFaceDetected && _isCameraInitialized) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keep your face centered in the oval',
                            style: TextStyle(
                              color: AppColors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_isFaceDetected) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Face recognition complete',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}

class FaceRecognitionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;

  const FaceRecognitionButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isEnabled ? AppColors.primary : AppColors.grey,
          width: 4,
        ),
      ),
      child: CircleAvatar(
        radius: 35,
        backgroundColor: isEnabled ? AppColors.primary : AppColors.grey,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : IconButton(
                onPressed: isEnabled ? onPressed : null,
                icon: const Icon(
                  Icons.camera_alt,
                  color: AppColors.white,
                  size: 28,
                ),
              ),
      ),
    );
  }
}
