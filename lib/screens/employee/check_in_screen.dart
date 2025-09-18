// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/face_camera_widget.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _isLocationChecked = false;
  bool _isFaceRecognitionEnabled = false;

  @override
  void initState() {
    super.initState();
    // Schedule the call to run *after* the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocation();
    });
  }

  Future<void> _checkLocation() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // Load settings if not already loaded
    if (!settingsProvider.hasSettings) {
      await settingsProvider.initialize();
    }

    // Initialize location provider with company location if available
    if (settingsProvider.companyLocation != null) {
      await locationProvider.initialize(settingsProvider.companyLocation!);
    }

    await locationProvider.getCurrentLocation();
    setState(() {
      _isLocationChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Check'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer4<AuthProvider, AttendanceProvider, LocationProvider,
          SettingsProvider>(
        builder: (context, authProvider, attendanceProvider, locationProvider,
            settingsProvider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location Settings Warning
                  if (!settingsProvider.isLocationConfigured)
                    _buildLocationWarning(),

                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getCurrentTime(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _getCurrentDate(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const SizedBox(height: 20),
                  _buildStatusChecks(locationProvider, settingsProvider),

                  const SizedBox(height: 24),

                  // Face Recognition Section
                  if (_isFaceRecognitionEnabled) ...[
                    _buildFaceRecognitionSection(),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  _buildActionButtons(
                      authProvider, attendanceProvider, locationProvider),

                  const SizedBox(height: 16),

                  // Current Status
                  if (attendanceProvider.todayAttendance != null)
                    _buildCurrentStatus(attendanceProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChecks(
      LocationProvider locationProvider, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Checks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Location Check
        _StatusCheckItem(
          icon: Icons.location_on_outlined,
          title: 'Location Verification',
          status: _getLocationStatus(locationProvider, settingsProvider),
          isSuccess: _isLocationVerified(locationProvider, settingsProvider),
          isError: _hasLocationError(locationProvider, settingsProvider),
          onRetry: _getLocationRetryAction(locationProvider, settingsProvider),
        ),

        // Face Recognition Check
        _StatusCheckItem(
          icon: Icons.face_outlined,
          title: 'Face Recognition',
          status: _isFaceRecognitionEnabled ? 'Ready' : 'Not enabled',
          isSuccess: _isFaceRecognitionEnabled,
          onRetry: _isFaceRecognitionEnabled
              ? null
              : () {
                  setState(() {
                    _isFaceRecognitionEnabled = true;
                  });
                },
        ),

        // Network Check
        _StatusCheckItem(
          icon: Icons.wifi_outlined,
          title: 'Network Connection',
          status: 'Connected',
          isSuccess: true,
        ),
      ],
    );
  }

  Widget _buildFaceRecognitionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Face Recognition',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey.withOpacity(0.3)),
          ),
          child: const FaceCameraWidget(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    AuthProvider authProvider,
    AttendanceProvider attendanceProvider,
    LocationProvider locationProvider,
  ) {
    final user = authProvider.currentUser;
    if (user == null) return const SizedBox.shrink();

    final canProceed =
        _isLocationChecked && locationProvider.isWithinCompanyLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Check In Button
        if (attendanceProvider.canCheckIn)
          CustomButton(
            text: 'Check In',
            icon: Icons.login,
            onPressed: canProceed
                ? () => _handleCheckIn(
                    user.userId, attendanceProvider, locationProvider)
                : null,
            isLoading: attendanceProvider.isLoading,
          ),

        // Check Out Button
        if (attendanceProvider.canCheckOut)
          CustomButton(
            text: 'Check Out',
            icon: Icons.logout,
            onPressed: canProceed
                ? () => _handleCheckOut(
                    user.userId, attendanceProvider, locationProvider)
                : null,
            isLoading: attendanceProvider.isLoading,
          ),

        // Already completed message
        if (!attendanceProvider.canCheckIn && !attendanceProvider.canCheckOut)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance completed for today!',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Enable Face Recognition Button
        if (!_isFaceRecognitionEnabled)
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isFaceRecognitionEnabled = true;
              });
            },
            icon: const Icon(Icons.face),
            label: const Text('Enable Face Recognition'),
          ),
      ],
    );
  }

  Widget _buildCurrentStatus(AttendanceProvider attendanceProvider) {
    final attendance = attendanceProvider.todayAttendance!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusItem(
                  label: 'Check In',
                  value: attendance.checkInTime != null
                      ? _formatTime(attendance.checkInTime!)
                      : 'Not checked in',
                  icon: Icons.login,
                ),
              ),
              Expanded(
                child: _StatusItem(
                  label: 'Check Out',
                  value: attendance.checkOutTime != null
                      ? _formatTime(attendance.checkOutTime!)
                      : 'Not checked out',
                  icon: Icons.logout,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusItem(
            label: 'Working Hours',
            value: attendanceProvider.todayWorkingHours,
            icon: Icons.schedule,
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn(
    String userId,
    AttendanceProvider attendanceProvider,
    LocationProvider locationProvider,
  ) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Use company location from settings
    if (settingsProvider.companyLocation == null) {
      _showErrorDialog('Company location not configured. Please contact admin.');
      return;
    }

    final success = await attendanceProvider.checkIn(
      userId: userId,
      companyLocation: settingsProvider.companyLocation!,
    );

    if (mounted) {
      if (success) {
        _showSuccessDialog('Check-in successful!');
      } else {
        _showErrorDialog(attendanceProvider.errorMessage ?? 'Check-in failed');
      }
    }
  }

  Future<void> _handleCheckOut(
    String userId,
    AttendanceProvider attendanceProvider,
    LocationProvider locationProvider,
  ) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Use company location from settings
    if (settingsProvider.companyLocation == null) {
      _showErrorDialog('Company location not configured. Please contact admin.');
      return;
    }

    final companyLocation = settingsProvider.companyLocation!;

    final success = await attendanceProvider.checkOut(
      userId: userId,
      companyLocation: companyLocation,
    );

    if (mounted) {
      if (success) {
        _showSuccessDialog('Check-out successful!');
      } else {
        _showErrorDialog(attendanceProvider.errorMessage ?? 'Check-out failed');
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLocationWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Colors.orange[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Not Configured',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin needs to configure work location settings for location verification to work properly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationStatus(LocationProvider locationProvider, SettingsProvider settingsProvider) {
    if (!settingsProvider.isLocationConfigured) {
      return 'Location not configured';
    }
    
    if (!_isLocationChecked) {
      return 'Checking...';
    }
    
    if (!locationProvider.canUseLocation) {
      return 'Permission required';
    }
    
    return locationProvider.isWithinCompanyLocation ? 'Verified' : 'Outside work area';
  }

  bool _isLocationVerified(LocationProvider locationProvider, SettingsProvider settingsProvider) {
    return settingsProvider.isLocationConfigured && 
           _isLocationChecked && 
           locationProvider.canUseLocation &&
           locationProvider.isWithinCompanyLocation;
  }

  bool _hasLocationError(LocationProvider locationProvider, SettingsProvider settingsProvider) {
    if (!settingsProvider.isLocationConfigured) {
      return true;
    }
    
    if (!locationProvider.canUseLocation) {
      return true;
    }
    
    return _isLocationChecked && !locationProvider.isWithinCompanyLocation;
  }

  VoidCallback? _getLocationRetryAction(LocationProvider locationProvider, SettingsProvider settingsProvider) {
    if (!settingsProvider.isLocationConfigured) {
      return null; // Admin needs to configure location
    }
    
    if (!locationProvider.canUseLocation) {
      return () => locationProvider.requestLocationPermission();
    }
    
    if (_isLocationChecked && !locationProvider.isWithinCompanyLocation) {
      return () => _checkLocation(); // Retry location check
    }
    
    return null;
  }
}

class _StatusCheckItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool isSuccess;
  final bool isError;
  final VoidCallback? onRetry;

  const _StatusCheckItem({
    required this.icon,
    required this.title,
    required this.status,
    this.isSuccess = false,
    this.isError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.textSecondary;
    IconData statusIcon = Icons.pending;

    if (isSuccess) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    } else if (isError) {
      statusColor = AppColors.error;
      statusIcon = Icons.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  iconSize: 20,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatusItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
