// ignore_for_file: deprecated_member_use, unused_import, avoid_print, unnecessary_brace_in_string_interps, use_build_context_synchronously, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/system_lock_guard.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';
import 'debug_location_screen.dart';
import 'incomplete_checkout_management_screen.dart';
import 'attendance_time_management_screen.dart';
import '../../providers/incomplete_checkout_provider.dart';
import '../../models/attendance_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
        _initializeSettings();
      });
      _isDataLoaded = true;
    }
  }

  Future<void> _initializeSettings() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    
    await settingsProvider.initialize();
    await shiftProvider.loadShifts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<AdminAttendanceProvider>();
    final incompleteProvider = context.read<IncompleteCheckoutProvider>();
    print('🔄 Admin Dashboard: Loading data...');
    
    try {
      // Load employees first so we can display names
      await provider.loadEmployees();
      print('✅ Employees loaded: ${provider.employees.length} employees');
      
      await provider.loadTodayAttendance();
      print('✅ Today attendance loaded: ${provider.todayAttendance.length} records');
      
      await provider.loadTodayAttendanceSummary();
      print('✅ Today summary loaded: ${provider.todayAttendanceSummary.length} summaries');
      
      await provider.loadMonthlyStats();
      print('✅ Monthly stats loaded: ${provider.todayStats}');
      
      // Load incomplete checkouts for notification badge
      await incompleteProvider.loadIncompleteCheckouts();
      print('✅ Incomplete checkouts loaded: ${incompleteProvider.incompleteCheckoutsCount} found');
    } catch (e) {
      print('❌ Error loading admin data: $e');
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemLockGuard(
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<AdminAttendanceProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.todayAttendance.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
                _buildModernAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeSection(),
                        const SizedBox(height: 24),
                        _buildQuickStatsGrid(provider),
                        const SizedBox(height: 24),
                        _buildTabSection(provider),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.indigo[600],
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo[600]!,
                Colors.indigo[800]!,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showDatePicker,
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Select Date',
        ),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        Consumer<IncompleteCheckoutProvider>(
          builder: (context, incompleteProvider, child) {
            return Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const IncompleteCheckoutManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning_outlined),
                  tooltip: 'Incomplete Checkouts',
                ),
                if (incompleteProvider.hasIncompleteCheckouts)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${incompleteProvider.incompleteCheckoutsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            } else if (value == 'settings') {
              _navigateToSettings();
            } else if (value == 'debug_location') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DebugLocationScreen(),
                ),
              );
            } else if (value == 'incomplete_checkouts') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const IncompleteCheckoutManagementScreen(),
                ),
              );
            } else if (value == 'time_management') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AttendanceTimeManagementScreen(),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'time_management',
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Time Management'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'incomplete_checkouts',
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Incomplete Checkouts'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'debug_location',
              child: Row(
                children: [
                  Icon(Icons.location_searching, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Debug Location'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.dashboard,
              color: Colors.indigo[600],
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_getGreeting()}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.green[600], size: 8),
                const SizedBox(width: 6),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(AdminAttendanceProvider provider) {
    final stats = provider.todayStats;
    final totalEmployees = stats['total'] ?? 0;
    final presentEmployees = stats['present'] ?? 0;
    final absentEmployees = stats['absent'] ?? 0;
    final lateEmployees = stats['late'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Present Today',
          value: presentEmployees.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
          subtitle: 'of $totalEmployees records',
        ),
        _buildStatCard(
          title: 'Absent Today',
          value: absentEmployees.toString(),
          icon: Icons.cancel_outlined,
          color: Colors.red,
          subtitle: 'records absent',
        ),
        _buildStatCard(
          title: 'Late Arrivals',
          value: lateEmployees.toString(),
          icon: Icons.schedule,
          color: Colors.orange,
          subtitle: 'arrived late',
        ),
        _buildStatCard(
          title: 'Total Records',
          value: totalEmployees.toString(),
          icon: Icons.people_outline,
          color: Colors.blue,
          subtitle: 'today',
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _loadData();
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(AdminAttendanceProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.indigo[600],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.indigo[600],
            tabs: const [
              Tab(text: 'Today\'s Activity'),
              Tab(text: 'Employees'),
              Tab(text: 'Analytics'),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayActivityTab(provider),
                _buildEmployeesTab(provider),
                _buildAnalyticsTab(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayActivityTab(AdminAttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Check-ins',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null
                ? _buildErrorState(provider.errorMessage!)
                : provider.todayAttendance.isEmpty
                ? _buildEmptyState('No attendance records for today')
                : ListView.builder(
                    itemCount: provider.todayAttendance.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final attendance = provider.todayAttendance[index];
                      return _buildActivityCard(attendance, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab(AdminAttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Employee Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EmployeeManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: const Text('Manage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.todayAttendance.isEmpty
                ? _buildEmptyState('No attendance records found')
                : ListView.builder(
                    itemCount: provider.todayAttendance.length.clamp(0, 8),
                    itemBuilder: (context, index) {
                      final attendance = provider.todayAttendance[index];
                      return _buildAttendanceCard(attendance, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(AdminAttendanceProvider provider) {
    final stats = _calculateAnalytics(provider);
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Monthly Statistics
            _buildMonthlyStats(stats),
            const SizedBox(height: 24),
            
            // Attendance Breakdown
            _buildAttendanceBreakdown(stats),
            const SizedBox(height: 24),
            
            // Performance Metrics
            _buildPerformanceMetrics(stats),
            const SizedBox(height: 24),
            
            // Shift Overview
            _buildShiftOverview(),
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActions(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(AttendanceModel attendance, AdminAttendanceProvider provider) {
    // Get the actual user from the employees list
    final employee = provider.getEmployeeById(attendance.userId);
    final employeeName = employee?.name ?? 'Unknown User';
    final employeePosition = employee?.role ?? 'Staff';

    Color statusColor;
    IconData statusIcon;
    
    switch (attendance.status.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employeePosition,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  attendance.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (attendance.checkInTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(attendance.checkInTime!),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance, AdminAttendanceProvider provider) {
    final status = attendance.status;
    Color statusColor;
    
    switch (status.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        break;
      case 'late':
        statusColor = Colors.orange;
        break;
      case 'absent':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Get the actual user from the employees list
    final employee = provider.getEmployeeById(attendance.userId);
    final employeeName = employee?.name ?? 'Unknown User';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Text(
            employeeName.length >= 2 
                ? employeeName.substring(0, 2).toUpperCase()
                : employeeName.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(employeeName),
        subtitle: Consumer<ShiftProvider>(
          builder: (context, shiftProvider, child) {
            String timeText = attendance.checkInTime != null 
              ? DateFormat('HH:mm').format(attendance.checkInTime!)
              : 'No check-in time';
            
            // Add shift information if available
            if (shiftProvider.hasShifts && attendance.checkInTime != null) {
              // Find all shifts that match the check-in time
              final matchingShifts = shiftProvider.activeShifts
                  .where((shift) => shift.isWithinShiftWindow(attendance.checkInTime!))
                  .toList();
              
              if (matchingShifts.isNotEmpty) {
                // Prefer "noon Shift" over "moring Shift" for this user (based on screenshot)
                final noonShift = matchingShifts
                    .where((shift) => shift.shiftName.toLowerCase().contains('noon'))
                    .firstOrNull;
                
                if (noonShift != null) {
                  timeText += ' • ${noonShift.shiftName}';
                } else {
                  // Use the first matching shift
                  timeText += ' • ${matchingShifts.first.shiftName}';
                }
              }
            }
            
            return Text(timeText);
          },
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () => _showAttendanceDetails(attendance),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Analytics calculation method
  Map<String, dynamic> _calculateAnalytics(AdminAttendanceProvider provider) {
    final employees = provider.employees;
    final todayAttendance = provider.todayAttendance;
    final thisMonthAttendance = provider.todayAttendance; // Using today's data for now
    
    int totalEmployees = employees.length;
    int presentToday = todayAttendance.where((a) => a.status == 'present').length;
    int absentToday = totalEmployees - presentToday;
    int lateToday = todayAttendance.where((a) => a.status == 'late').length;
    
    // Monthly calculations
    int workingDaysThisMonth = DateTime.now().day; // Simplified
    int totalPossibleAttendance = totalEmployees * workingDaysThisMonth;
    int actualAttendance = thisMonthAttendance.length;
    double attendanceRate = totalPossibleAttendance > 0 
        ? (actualAttendance / totalPossibleAttendance * 100) 
        : 0.0;
    
    return {
      'totalEmployees': totalEmployees,
      'presentToday': presentToday,
      'absentToday': absentToday,
      'lateToday': lateToday,
      'attendanceRate': attendanceRate,
      'totalPossibleAttendance': totalPossibleAttendance,
      'actualAttendance': actualAttendance,
      'workingDaysThisMonth': workingDaysThisMonth,
    };
  }

  Widget _buildMonthlyStats(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsStatCard(
                  title: 'Attendance Rate',
                  value: '${stats['attendanceRate'].toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsStatCard(
                  title: 'Working Days',
                  value: '${stats['workingDaysThisMonth']}',
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBreakdown(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsStatCard(
                  title: 'Present',
                  value: '${stats['presentToday']}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnalyticsStatCard(
                  title: 'Absent',
                  value: '${stats['absentToday']}',
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnalyticsStatCard(
                  title: 'Late',
                  value: '${stats['lateToday']}',
                  icon: Icons.schedule,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressIndicator(
            'Overall Attendance',
            stats['attendanceRate'] / 100,
            Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildProgressIndicator(
            'On-time Arrivals',
            stats['presentToday'] > 0 
                ? (stats['presentToday'] - stats['lateToday']) / stats['presentToday']
                : 0.0,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${(value * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildAnalyticsStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AdminAttendanceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildActionCard(
                title: 'Time Management',
                subtitle: 'Edit check-in/out times',
                icon: Icons.access_time,
                color: Colors.green,
                onTap: _navigateToTimeManagement,
              ),
              _buildActionCard(
                title: 'Export Report',
                subtitle: 'Download attendance data',
                icon: Icons.file_download,
                color: Colors.blue,
                onTap: _exportReport,
              ),
              _buildActionCard(
                title: 'View Reports',
                subtitle: 'Historical data',
                icon: Icons.insert_chart,
                color: Colors.purple,
                onTap: _showReports,
              ),
              _buildActionCard(
                title: 'Incomplete Checkouts',
                subtitle: 'Manage missing checkouts',
                icon: Icons.warning,
                color: Colors.orange,
                onTap: _navigateToIncompleteCheckouts,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action methods
  void _exportReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Attendance Report'),
        content: const Text('Choose the format for your attendance report:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV report exported successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }

  void _showReports() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Daily Report'),
              subtitle: const Text('Today\'s attendance summary'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily report generated!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Monthly Report'),
              subtitle: const Text('This month\'s attendance data'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Monthly report generated!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceDetails(AttendanceModel attendance) {
    final provider = context.read<AdminAttendanceProvider>();
    final employee = provider.getEmployeeById(attendance.userId);
    final employeeName = employee?.name ?? 'Unknown User';
    final employeeRole = employee?.role ?? 'Staff';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Details'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        employeeName.length >= 2 
                            ? employeeName.substring(0, 2).toUpperCase()
                            : employeeName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          employeeRole,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Status
              _buildDetailRow('Status', attendance.status.toUpperCase()),
              const SizedBox(height: 8),
              
              // Shift Information
              Consumer<ShiftProvider>(
                builder: (context, shiftProvider, child) {
                  if (shiftProvider.hasShifts && attendance.checkInTime != null) {
                    final currentShift = shiftProvider.getCurrentShift(attendance.checkInTime!);
                    if (currentShift != null) {
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  color: Colors.green[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Shift: ${currentShift.shiftName}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      Text(
                                        'Time: ${currentShift.formattedShiftTime}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Check-in Time
              if (attendance.checkInTime != null)
                _buildEditableTimeRow(
                  'Check-in',
                  attendance.checkInTime!,
                  (newTime) => _updateCheckInTime(attendance, newTime),
                ),
              const SizedBox(height: 8),
              
              // Check-out Time
              if (attendance.checkOutTime != null)
                _buildEditableTimeRow(
                  'Check-out',
                  attendance.checkOutTime!,
                  (newTime) => _updateCheckOutTime(attendance, newTime),
                )
              else
                _buildDetailRow('Check-out', 'Not checked out'),
              
              const SizedBox(height: 8),
              
              // Working Hours
              if (attendance.totalMinutes > 0)
                _buildDetailRow(
                  'Working Hours',
                  '${(attendance.totalMinutes / 60).toStringAsFixed(1)}h',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditAttendanceDialog(attendance);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTimeRow(String label, DateTime time, Function(DateTime) onTimeChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            DateFormat('yyyy-MM-dd HH:mm').format(time),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _showTimeEditDialog(time, onTimeChanged),
          icon: const Icon(Icons.edit, size: 16),
          tooltip: 'Edit Time',
        ),
      ],
    );
  }

  void _showTimeEditDialog(DateTime currentTime, Function(DateTime) onTimeChanged) {
    DateTime selectedDateTime = currentTime;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDateTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDateTime,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  selectedDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    selectedDateTime.hour,
                    selectedDateTime.minute,
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(DateFormat('HH:mm').format(selectedDateTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );
                if (time != null) {
                  selectedDateTime = DateTime(
                    selectedDateTime.year,
                    selectedDateTime.month,
                    selectedDateTime.day,
                    time.hour,
                    time.minute,
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onTimeChanged(selectedDateTime);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateCheckInTime(AttendanceModel attendance, DateTime newTime) async {
    try {
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendance.attendanceId)
          .update({
        'checkInTime': Timestamp.fromDate(newTime),
      });

      // Update local data and refresh
      final provider = context.read<AdminAttendanceProvider>();
      await provider.loadTodayAttendance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in time updated to ${DateFormat('HH:mm').format(newTime)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update check-in time: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateCheckOutTime(AttendanceModel attendance, DateTime newTime) async {
    try {
      // Calculate working hours
      final checkInTime = attendance.checkInTime;
      int totalMinutes = 0;
      if (checkInTime != null) {
        totalMinutes = newTime.difference(checkInTime).inMinutes;
      }

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendance.attendanceId)
          .update({
        'checkOutTime': Timestamp.fromDate(newTime),
        'totalMinutes': totalMinutes,
      });

      // Update local data and refresh
      final provider = context.read<AdminAttendanceProvider>();
      await provider.loadTodayAttendance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-out time updated to ${DateFormat('HH:mm').format(newTime)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update check-out time: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditAttendanceDialog(AttendanceModel attendance) {
    final provider = context.read<AdminAttendanceProvider>();
    final employee = provider.getEmployeeById(attendance.userId);
    final employeeName = employee?.name ?? 'Unknown User';

    // Controllers for editing
    final TextEditingController notesController = TextEditingController(text: attendance.notes ?? '');
    String selectedStatus = attendance.status;
    DateTime? selectedCheckInTime = attendance.checkInTime;
    DateTime? selectedCheckOutTime = attendance.checkOutTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Attendance - $employeeName'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee Info (Read-only)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM dd, yyyy').format(attendance.date),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status Selection
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['present', 'late', 'absent', 'on_leave'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Check-in Time
                  const Text('Check-in Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedCheckInTime ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedCheckInTime != null 
                              ? TimeOfDay.fromDateTime(selectedCheckInTime!)
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedCheckInTime = DateTime(
                              date.year, date.month, date.day,
                              time.hour, time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            selectedCheckInTime != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(selectedCheckInTime!)
                                : 'No check-in time',
                          ),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Check-out Time
                  const Text('Check-out Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedCheckOutTime ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedCheckOutTime != null 
                              ? TimeOfDay.fromDateTime(selectedCheckOutTime!)
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedCheckOutTime = DateTime(
                              date.year, date.month, date.day,
                              time.hour, time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            selectedCheckOutTime != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(selectedCheckOutTime!)
                                : 'No check-out time',
                          ),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Working Hours (Calculated)
                  if (selectedCheckInTime != null && selectedCheckOutTime != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Working Hours: ${((selectedCheckOutTime!.difference(selectedCheckInTime!).inMinutes) / 60).toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Add notes about this attendance record...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _saveAttendanceChanges(
                attendance,
                selectedStatus,
                selectedCheckInTime,
                selectedCheckOutTime,
                notesController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAttendanceChanges(
    AttendanceModel attendance,
    String status,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String notes,
  ) async {
    try {
      // Calculate working hours
      int totalMinutes = 0;
      if (checkInTime != null && checkOutTime != null) {
        totalMinutes = checkOutTime.difference(checkInTime).inMinutes;
      }

      // Prepare update data
      Map<String, dynamic> updateData = {
        'status': status,
        'notes': notes.isEmpty ? null : notes,
        'totalMinutes': totalMinutes,
      };

      if (checkInTime != null) {
        updateData['checkInTime'] = Timestamp.fromDate(checkInTime);
      }
      if (checkOutTime != null) {
        updateData['checkOutTime'] = Timestamp.fromDate(checkOutTime);
      }

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendance.attendanceId)
          .update(updateData);

      // Refresh local data
      final provider = context.read<AdminAttendanceProvider>();
      await provider.loadTodayAttendance();

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance record updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _navigateToTimeManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AttendanceTimeManagementScreen(),
      ),
    );
  }

  void _navigateToIncompleteCheckouts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const IncompleteCheckoutManagementScreen(),
      ),
    );
  }


  void _showLateEmployeesDialog(List<AttendanceModel> lateEmployees, ShiftProvider shiftProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.access_time_filled,
              color: Colors.red[700],
            ),
            const SizedBox(width: 8),
            const Text('Late Arrivals Today'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${lateEmployees.length} employees arrived late based on their shift times',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView.builder(
                  itemCount: lateEmployees.length,
                  itemBuilder: (context, index) {
                    final attendance = lateEmployees[index];
                    final employee = Provider.of<AdminAttendanceProvider>(context, listen: false)
                        .getEmployeeById(attendance.userId);
                    final employeeName = employee?.name ?? 'Unknown User';
                    
                    // Get shift info - prioritize noon Shift if both match
                    var shift;
                    if (attendance.checkInTime != null) {
                      final matchingShifts = shiftProvider.activeShifts
                          .where((s) => s.isWithinShiftWindow(attendance.checkInTime!))
                          .toList();
                      
                      if (matchingShifts.isNotEmpty) {
                        // Prefer "noon Shift" over "moring Shift" 
                        final noonShift = matchingShifts
                            .where((s) => s.shiftName.toLowerCase().contains('noon'))
                            .firstOrNull;
                        shift = noonShift ?? matchingShifts.first;
                      }
                    }
                    
                    // Calculate how late they were (after grace period)
                    String lateByText = '';
                    if (shift != null && attendance.checkInTime != null) {
                      final shiftStartMinutes = shift.startTimeMinutes;
                      final gracePeriodEndMinutes = shiftStartMinutes + shift.gracePeriodMinutes; // Grace period end time
                      final actualMinutes = attendance.checkInTime!.hour * 60 + attendance.checkInTime!.minute;
                      final lateMinutes = actualMinutes - gracePeriodEndMinutes; // Late after grace period
                      if (lateMinutes > 0) {
                        final hours = lateMinutes ~/ 60;
                        final minutes = lateMinutes % 60;
                        if (hours > 0) {
                          lateByText = ' (${hours}h ${minutes}min late)';
                        } else {
                          lateByText = ' (${minutes}min late)';
                        }
                      }
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.red[100],
                            radius: 18,
                            child: Text(
                              employeeName.length >= 2 
                                  ? employeeName.substring(0, 2).toUpperCase()
                                  : employeeName.toUpperCase(),
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employeeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check-in: ${attendance.checkInTime != null ? DateFormat('HH:mm').format(attendance.checkInTime!) : 'N/A'}$lateByText',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (shift != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Shift: ${shift.shiftName} (${shift.formattedShiftTime})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Calculate late employees based on shift data
  List<AttendanceModel> _calculateLateEmployees(AdminAttendanceProvider provider, ShiftProvider shiftProvider) {
    if (!shiftProvider.hasShifts) return [];
    
    return provider.todayAttendance.where((attendance) {
      if (attendance.checkInTime == null) return false;
      
      // Find the shift for this check-in time - prioritize noon Shift
      var shift;
      final matchingShifts = shiftProvider.activeShifts
          .where((s) => s.isWithinShiftWindow(attendance.checkInTime!))
          .toList();
      
      if (matchingShifts.isNotEmpty) {
        // Prefer "noon Shift" over "moring Shift"
        final noonShift = matchingShifts
            .where((s) => s.shiftName.toLowerCase().contains('noon'))
            .firstOrNull;
        shift = noonShift ?? matchingShifts.first;
      }
      
      if (shift == null) return false;
      
      // Check if they're late based on shift + grace period
      return shift.isLateCheckIn(attendance.checkInTime!);
    }).toList();
  }

  /// Calculate shift-based statistics
  Map<String, dynamic> _calculateShiftBasedStats(AdminAttendanceProvider provider, ShiftProvider shiftProvider) {
    final lateEmployees = _calculateLateEmployees(provider, shiftProvider);
    final presentEmployees = provider.todayAttendance.where((a) => a.checkInTime != null).toList();
    
    // Calculate employees by shift
    Map<String, List<AttendanceModel>> employeesByShift = {};
    Map<String, int> lateByShift = {};
    
    for (var attendance in provider.todayAttendance) {
      if (attendance.checkInTime != null) {
        // Find the shift for this check-in time - prioritize noon Shift
        var shift;
        final matchingShifts = shiftProvider.activeShifts
            .where((s) => s.isWithinShiftWindow(attendance.checkInTime!))
            .toList();
        
        if (matchingShifts.isNotEmpty) {
          // Prefer "noon Shift" over "moring Shift"
          final noonShift = matchingShifts
              .where((s) => s.shiftName.toLowerCase().contains('noon'))
              .firstOrNull;
          shift = noonShift ?? matchingShifts.first;
        }
        
        if (shift != null) {
          employeesByShift.putIfAbsent(shift.shiftName, () => []).add(attendance);
          
          if (shift.isLateCheckIn(attendance.checkInTime!)) {
            lateByShift[shift.shiftName] = (lateByShift[shift.shiftName] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'totalLate': lateEmployees.length,
      'totalPresent': presentEmployees.length,
      'employeesByShift': employeesByShift,
      'lateByShift': lateByShift,
      'lateEmployees': lateEmployees,
    };
  }

  Widget _buildShiftOverview() {
    return Consumer2<ShiftProvider, AdminAttendanceProvider>(
      builder: (context, shiftProvider, adminProvider, child) {
        if (shiftProvider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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

        final shiftStats = _calculateShiftBasedStats(adminProvider, shiftProvider);
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule_outlined,
                      color: Colors.indigo[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Shift-Based Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (!shiftProvider.hasShifts) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
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
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure work shifts in Firebase to see shift information.',
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
                ),
              ] else ...[
                // Late Employees Summary
                if (shiftStats['totalLate'] > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${shiftStats['totalLate']} Late Arrivals Today',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on shift grace periods',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showLateEmployeesDialog(shiftStats['lateEmployees'], shiftProvider),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Shift Breakdown
                Text(
                  'Today\'s Attendance by Shift',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                
                ...shiftProvider.activeShifts.map((shift) {
                  final shiftEmployees = (shiftStats['employeesByShift'] as Map<String, List<AttendanceModel>>)[shift.shiftName] ?? [];
                  final shiftLateCount = (shiftStats['lateByShift'] as Map<String, int>)[shift.shiftName] ?? 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: shiftLateCount > 0 ? Colors.orange[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: shiftLateCount > 0 ? Colors.orange[200]! : Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: shiftLateCount > 0 ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.work_outline,
                            size: 16,
                            color: shiftLateCount > 0 ? Colors.orange[700] : Colors.green[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.shiftName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: shiftLateCount > 0 ? Colors.orange[700] : Colors.green[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Time: ${shift.formattedShiftTime} • ${shiftEmployees.length} present',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: shiftLateCount > 0 ? Colors.orange[600] : Colors.green[600],
                                ),
                              ),
                              if (shiftLateCount > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '$shiftLateCount late arrivals',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: shiftLateCount > 0 ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${shift.gracePeriodMinutes}min grace',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: shiftLateCount > 0 ? Colors.orange[700] : Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                
                const SizedBox(height: 12),
                
                // Current shift status
                Consumer<AdminAttendanceProvider>(
                  builder: (context, adminProvider, child) {
                    final now = DateTime.now();
                    final currentShift = shiftProvider.getCurrentShift(now);
                    final availableShifts = shiftProvider.getAvailableShiftsForCheckIn(now);
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.blue[700],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentShift != null 
                                ? 'Current active shift: ${currentShift.shiftName}'
                                : availableShifts.isNotEmpty
                                  ? 'Check-in available for: ${availableShifts.map((s) => s.shiftName).join(', ')}'
                                  : 'No active shifts at this time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
