// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/face_recognition_service.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/face_camera_widget.dart';

class FaceManagementScreen extends StatefulWidget {
  const FaceManagementScreen({super.key});

  @override
  State<FaceManagementScreen> createState() => _FaceManagementScreenState();
}

class _FaceManagementScreenState extends State<FaceManagementScreen> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  
  bool _isLoading = false;
  bool _hasFaceData = false;
  bool _showCamera = false;
  bool _faceDetectedByCamera = false;
  
  @override
  void initState() {
    super.initState();
    _checkFaceRegistration();
  }

  Future<void> _checkFaceRegistration() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        final hasface = await _faceService.hasRegisteredFace(authProvider.currentUser!.userId);
        setState(() {
          _hasFaceData = hasface;
        });
      }
    } catch (e) {
      _showSnackBar('Error checking face registration: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading 
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  _buildFaceImageSection(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildInformationSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _hasFaceData ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasFaceData ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hasFaceData ? AppColors.success : AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _hasFaceData ? Icons.check_circle : Icons.warning,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasFaceData ? 'Face Data Registered' : 'Face Data Not Registered',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _hasFaceData ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    Text(
                      _hasFaceData 
                          ? 'Your face is registered for attendance verification'
                          : 'Register your face to enable secure attendance',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaceImageSection() {
    if (_showCamera && !_hasFaceData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Face Registration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FaceCameraWidget(
                  onFaceDetected: _onFaceDetected,
                  isActive: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Face Preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(75),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: _hasFaceData 
                ? const Icon(
                    Icons.face,
                    size: 60,
                    color: AppColors.primary,
                  )
                : const Icon(
                    Icons.face_outlined,
                    size: 60,
                    color: AppColors.grey,
                  ),
          ),
          
          const SizedBox(height: 16),
          Text(
            _hasFaceData 
                ? 'Face data is registered and secure'
                : 'No face data registered',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!_hasFaceData) ...[
          if (!_showCamera) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _showCamera = true;
                  _faceDetectedByCamera = false; // Reset detection state
                }),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start Face Registration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showCamera = false),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grey,
                      side: const BorderSide(color: AppColors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || !_faceDetectedByCamera) 
                        ? null 
                        : _registerFaceFromCamera,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Registering...' : 'Register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _faceDetectedByCamera 
                          ? AppColors.success 
                          : AppColors.grey,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateFace(),
              icon: const Icon(Icons.refresh),
              label: const Text('Update Face Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _testFaceRecognition(),
              icon: const Icon(Icons.face_retouching_natural),
              label: const Text('Test Face Recognition'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.info,
                side: const BorderSide(color: AppColors.info),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteFaceData(),
              icon: const Icon(Icons.delete),
              label: const Text('Delete Face Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInformationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Face Recognition Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('• Face data is securely stored and encrypted'),
          _buildInfoItem('• Only you can access your face data'),
          _buildInfoItem('• Face recognition speeds up attendance check-in'),
          _buildInfoItem('• You can update or delete your face data anytime'),
          _buildInfoItem('• Use camera only - no gallery access needed'),
          _buildInfoItem('• Ensure good lighting when taking photo'),
          _buildInfoItem('• Keep your face centered and clearly visible'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _onFaceDetected(String result) {
    // Face has been detected by camera widget
    setState(() {
      _faceDetectedByCamera = true;
    });
    _showSnackBar('Face detected! Click Register to save.', isError: false);
  }

  Future<void> _registerFaceFromCamera() async {
    // Validation: Check if face was actually detected
    if (!_faceDetectedByCamera) {
      _showSnackBar('No face detected! Please position your face in the camera first.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        _showSnackBar('User not logged in', isError: true);
        return;
      }

      // Call the actual face recognition service to save to Firebase
      final result = await _faceService.registerFaceDataFromCamera(
        userId: authProvider.currentUser!.userId,
        // For demo purposes, we'll pass simulated face data
        // In real implementation, you would pass actual face image or features
        faceFeatures: {
          'registered': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'source': 'camera_registration',
          'boundingBox': {'left': 0, 'top': 0, 'width': 100, 'height': 100},
          'landmarks': {},
          'headEulerAngleY': 0.0,
          'headEulerAngleZ': 0.0,
        },
      );

      if (result.success) {
        setState(() {
          _hasFaceData = true;
          _showCamera = false;
          _faceDetectedByCamera = false; // Reset for next time
        });
        _showSnackBar(result.message);
      } else {
        _showSnackBar(result.message, isError: true);
      }
      
    } catch (e) {
      _showSnackBar('Error registering face: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _updateFace() async {
    final confirmed = await _showConfirmDialog(
      'Update Face Data',
      'Are you sure you want to update your face data? This will replace your current registration.',
    );

    if (confirmed) {
      setState(() {
        _hasFaceData = false;
        _showCamera = true;
        _faceDetectedByCamera = false; // Reset detection state
      });
    }
  }

  Future<void> _testFaceRecognition() async {
    setState(() => _showCamera = true);
    
    // Show info dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: AppColors.info),
            SizedBox(width: 8),
            Text('Test Face Recognition'),
          ],
        ),
        content: const Text(
          'Position your face in the camera to test face recognition. The system will verify if your face matches the registered data.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFaceData() async {
    final confirmed = await _showConfirmDialog(
      'Delete Face Data',
      'Are you sure you want to delete your face data? This action cannot be undone and you will need to register your face again.',
    );

    if (confirmed) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await _faceService.deleteUserFace(authProvider.currentUser!.userId);

        if (success) {
          setState(() {
            _hasFaceData = false;
          });
          _showSnackBar('Face data deleted successfully');
        } else {
          _showSnackBar('Failed to delete face data', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error deleting face data: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }


  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _faceService.dispose();
    super.dispose();
  }
}
