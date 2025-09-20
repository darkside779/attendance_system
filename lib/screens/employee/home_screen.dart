// ignore_for_file: unused_import, use_build_context_synchronously, deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/loading_widget.dart';
import 'face_management_screen.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/system_lock_guard.dart';
import '../../widgets/incomplete_checkout_warning.dart';
import '../../models/settings_model.dart';
import '../auth/login_screen.dart';
import 'check_in_screen.dart';
import 'history_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeData();
      }
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      // Load shift data first
      await shiftProvider.loadShifts();
      
      // Load today's attendance
      await attendanceProvider.loadTodayAttendance(authProvider.currentUser!.userId);
      
      // Load settings
      if (!settingsProvider.hasSettings) {
        await settingsProvider.initialize();
      }
      
      // Initialize location if settings are configured
      if (settingsProvider.isLocationConfigured) {
        await locationProvider.initialize(settingsProvider.companyLocation!);
        await locationProvider.getCurrentLocation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemLockGuard(
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeTab(),
          _AttendanceHistoryTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthProvider, AttendanceProvider, LocationProvider, SettingsProvider>(
      builder: (context, authProvider, attendanceProvider, locationProvider, settingsProvider, child) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incomplete Checkout Warning
                IncompleteCheckoutWarning(userId: user.userId),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _refreshAttendanceData(context),
                          icon: const Icon(Icons.refresh),
                          iconSize: 28,
                          tooltip: 'Refresh Attendance Data',
                        ),
                        IconButton(
                          onPressed: () => _showNotifications(context),
                          icon: const Icon(Icons.notifications_outlined),
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Location Configuration Warning
                if (!settingsProvider.isLocationConfigured)
                  _buildLocationConfigWarning(context),
                
                // Today's Attendance Card
                AttendanceCard(
                  title: 'Today\'s Status',
                  status: attendanceProvider.todayStatus,
                  workingHours: attendanceProvider.todayWorkingHours,
                  canCheckIn: attendanceProvider.canCheckIn,
                  canCheckOut: attendanceProvider.canCheckOut,
                  onCheckIn: () => _navigateToCheckIn(context),
                  onCheckOut: () => _handleCheckOut(context),
                ),
                
                const SizedBox(height: 20),
                
                // Shift Status Message
                if (attendanceProvider.shiftStatusMessage.isNotEmpty)
                  _buildShiftStatusMessage(context, attendanceProvider),
                
                // Shift Information
                _buildShiftInformation(context),
                
                // Quick Actions
                _buildQuickActions(context),
                
                const SizedBox(height: 20),
                
                // Location Status
                _buildLocationStatus(context, locationProvider),
                
                const SizedBox(height: 20),
                
                // Recent Activity
                _buildRecentActivity(context, attendanceProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Check In/Out',
                subtitle: 'Face Recognition',
                onTap: () => _navigateToCheckIn(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history_outlined,
                title: 'Attendance',
                subtitle: 'View History',
                onTap: () => _navigateToHistory(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationConfigWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Not Configured',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please contact your administrator to configure the company location for attendance tracking.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.warning.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStatusMessage(BuildContext context, AttendanceProvider attendanceProvider) {
    final isCompleted = attendanceProvider.hasCompletedShiftToday;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted 
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? Colors.green.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3)
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_outline : Icons.info_outline,
            color: isCompleted ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? 'Shift Completed' : 'Check-in Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attendanceProvider.shiftStatusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: (isCompleted ? Colors.green : Colors.blue).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInformation(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        if (shiftProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading shift information...'),
              ],
            ),
          );
        }

        if (!shiftProvider.hasShifts) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Shifts Configured',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact your administrator to configure work shifts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final currentShift = shiftProvider.getCurrentShift(DateTime.now());
        final availableShifts = shiftProvider.getAvailableShiftsForCheckIn(DateTime.now());

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
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Shift Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              if (currentShift != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.work_outline,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Shift: ${currentShift.shiftName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Time: ${currentShift.formattedShiftTime}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.success.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (availableShifts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available for Check-in:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...availableShifts.map((shift) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${shift.shiftName}: ${shift.formattedShiftTime}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary.withOpacity(0.8),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shiftProvider.getShiftStatusMessage(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // All shifts summary
              Text(
                'All Shifts (${shiftProvider.activeShifts.length}):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...shiftProvider.activeShifts.map((shift) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${shift.shiftName}: ${shift.formattedShiftTime}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationStatus(BuildContext context, LocationProvider locationProvider) {
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
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: locationProvider.isWithinCompanyLocation 
                    ? AppColors.success 
                    : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                'Location Status',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            locationProvider.isWithinCompanyLocation
                ? 'Within work area'
                : 'Outside work area (${locationProvider.formattedDistanceFromCompany})',
            style: TextStyle(
              fontSize: 14,
              color: locationProvider.isWithinCompanyLocation 
                  ? AppColors.success 
                  : AppColors.warning,
            ),
          ),
          if (!locationProvider.canUseLocation) ...[
            const SizedBox(height: 8),
            Text(
              'Location access required for attendance tracking',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => locationProvider.requestLocationPermission(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(120, 32),
              ),
              child: const Text('Enable Location'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, AttendanceProvider attendanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToHistory(context),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (attendanceProvider.todayAttendance != null) ...[
          _ActivityItem(
            icon: Icons.login,
            title: 'Check In',
            time: attendanceProvider.todayAttendance!.checkInTime != null
                ? _formatTime(attendanceProvider.todayAttendance!.checkInTime!)
                : 'Not checked in',
            status: attendanceProvider.todayAttendance!.hasCheckedIn ? 'Done' : 'Pending',
          ),
          if (attendanceProvider.todayAttendance!.hasCheckedOut)
            _ActivityItem(
              icon: Icons.logout,
              title: 'Check Out',
              time: _formatTime(attendanceProvider.todayAttendance!.checkOutTime!),
              status: 'Done',
            ),
        ] else ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No activity today',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToCheckIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CheckInScreen(),
      ),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AttendanceHistoryScreen(),
      ),
    );
  }

  Future<void> _handleCheckOut(BuildContext context) async {
    // For now, navigate to check-in screen for check-out
    _navigateToCheckIn(context);
  }

  void _refreshAttendanceData(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      print('🔄 Manual refresh triggered for user: ${authProvider.currentUser!.userId}');
      await attendanceProvider.loadTodayAttendance(authProvider.currentUser!.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance data refreshed'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Text('No new notifications'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistoryTab extends StatelessWidget {
  const _AttendanceHistoryTab();

  @override
  Widget build(BuildContext context) {
    return const AttendanceHistoryScreen();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.white,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.position,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Profile Options
                _ProfileOption(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  subtitle: 'Edit your profile details',
                  onTap: () => _showComingSoon(context),
                ),
                _ProfileOption(
                  icon: Icons.face,
                  title: 'Face Recognition',
                  subtitle: 'Manage face data',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FaceManagementScreen(),
                    ),
                  ),
                ),
                _ProfileOption(
                  icon: Icons.security,
                  title: 'Security',
                  subtitle: 'Change password',
                  onTap: () => _showComingSoon(context),
                ),
                _ProfileOption(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'App preferences',
                  onTap: () => _showComingSoon(context),
                ),
                _ProfileOption(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help and support',
                  onTap: () => _showComingSoon(context),
                ),
                
                const SizedBox(height: 24),
                
                // Logout Button
                CustomButton(
                  text: 'Logout',
                  onPressed: () => _handleLogout(context),
                  backgroundColor: AppColors.error,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String status;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
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
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Done' ? AppColors.success : AppColors.warning,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
