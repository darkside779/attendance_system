// ignore_for_file: avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

class EmployeeAnalyticsScreen extends StatefulWidget {
  const EmployeeAnalyticsScreen({super.key});

  @override
  State<EmployeeAnalyticsScreen> createState() => _EmployeeAnalyticsScreenState();
}

class _EmployeeAnalyticsScreenState extends State<EmployeeAnalyticsScreen> {
  List<UserModel> _employees = [];
  UserModel? _selectedEmployee;
  List<AttendanceModel> _attendanceRecords = [];
  bool _isLoading = false;
  
  // Analytics data
  int _totalDays = 0;
  int _presentDays = 0;
  int _lateDays = 0;
  int _absentDays = 0;
  double _totalWorkingHours = 0.0;
  double _averageWorkingHours = 0.0;
  
  // Date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    // Load shifts for status calculation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShiftProvider>(context, listen: false).loadShifts();
    });
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      _employees = snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel.fromJson({...data, 'userId': doc.id});
      }).where((user) => 
        user.role.toLowerCase() != 'superadmin' && 
        user.role.toLowerCase() != 'admin'
      ).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load employees: $e');
    }
  }

  Future<void> _loadEmployeeAnalytics() async {
    if (_selectedEmployee == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Simplest possible query - only filter by userId (no orderBy, no index needed)
      final query = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _selectedEmployee!.userId)
          .get();

      // Do all filtering and sorting in memory
      _attendanceRecords = query.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel.fromJson({...data, 'attendanceId': doc.id});
      }).where((record) {
        return record.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               record.date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();
      
      // Sort in memory instead of in query
      _attendanceRecords.sort((a, b) => b.date.compareTo(a.date));
      
      _calculateAnalytics();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load attendance data: $e');
    }
  }

  void _calculateAnalytics() {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    
    _totalDays = _attendanceRecords.length;
    
    // Calculate shift-based status for each record
    _presentDays = 0;
    _lateDays = 0;
    _absentDays = 0;
    
    for (final record in _attendanceRecords) {
      final realTimeStatus = _calculateShiftBasedStatus(record, shiftProvider);
      switch (realTimeStatus.toLowerCase()) {
        case 'present':
          _presentDays++;
          break;
        case 'late':
          _lateDays++;
          break;
        case 'absent':
          _absentDays++;
          break;
      }
    }
    
    _totalWorkingHours = _attendanceRecords
        .where((r) => r.totalMinutes > 0)
        .fold(0.0, (sum, r) => sum + (r.totalMinutes / 60.0));
    
    _averageWorkingHours = _totalDays > 0 ? _totalWorkingHours / _totalDays : 0.0;
  }
  
  // Get employee's shift for a specific date
  ShiftModel? _getEmployeeShift(AttendanceModel attendance, ShiftProvider shiftProvider) {
    if (_selectedEmployee?.assignedShiftId == null || _selectedEmployee!.assignedShiftId!.isEmpty) {
      return null;
    }
    
    return shiftProvider.shifts.firstWhere(
      (shift) => shift.shiftId == _selectedEmployee!.assignedShiftId,
      orElse: () => ShiftModel(
        shiftId: '',
        shiftName: 'Default',
        startTime: '09:00',
        endTime: '17:00',
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        isActive: true,
        gracePeriodMinutes: 15,
      ),
    );
  }
  
  // Calculate real-time status based on shift
  String _calculateShiftBasedStatus(AttendanceModel attendance, ShiftProvider shiftProvider) {
    // If no check-in, it's absent
    if (attendance.checkInTime == null) {
      return 'absent';
    }
    
    // Get employee's shift
    final shift = _getEmployeeShift(attendance, shiftProvider);
    if (shift == null) {
      return attendance.status; // Fallback to stored status if no shift
    }
    
    // Parse shift start time
    final shiftTimeParts = shift.startTime.split(':');
    final shiftHour = int.parse(shiftTimeParts[0]);
    final shiftMinute = int.parse(shiftTimeParts[1]);
    
    // Create shift start datetime for the attendance date
    final shiftStart = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
      shiftHour,
      shiftMinute,
    );
    
    // Calculate grace period end time
    final gracePeriodEnd = shiftStart.add(Duration(minutes: shift.gracePeriodMinutes));
    
    // Compare check-in time with grace period
    if (attendance.checkInTime!.isBefore(gracePeriodEnd) || attendance.checkInTime!.isAtSameMomentAs(gracePeriodEnd)) {
      return 'present';
    } else {
      return 'late';
    }
  }
  
  // Calculate how many minutes late the employee was
  String _calculateLateTime(AttendanceModel attendance, ShiftProvider shiftProvider) {
    if (attendance.checkInTime == null) return '';
    
    final shift = _getEmployeeShift(attendance, shiftProvider);
    if (shift == null) return '';
    
    // Parse shift start time
    final shiftTimeParts = shift.startTime.split(':');
    final shiftHour = int.parse(shiftTimeParts[0]);
    final shiftMinute = int.parse(shiftTimeParts[1]);
    
    // Create shift start datetime for the attendance date
    final shiftStart = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
      shiftHour,
      shiftMinute,
    );
    
    // Calculate grace period end time
    final gracePeriodEnd = shiftStart.add(Duration(minutes: shift.gracePeriodMinutes));
    
    // If checked in after grace period, calculate late minutes
    if (attendance.checkInTime!.isAfter(gracePeriodEnd)) {
      final lateMinutes = attendance.checkInTime!.difference(gracePeriodEnd).inMinutes;
      if (lateMinutes < 60) {
        return '${lateMinutes}min late';
      } else {
        final hours = (lateMinutes / 60).floor();
        final minutes = lateMinutes % 60;
        if (minutes > 0) {
          return '${hours}h ${minutes}min late';
        } else {
          return '${hours}h late';
        }
      }
    }
    
    return '';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          appBar: AppBar(
            title: const Text(
              'Employee Analytics',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Employee Selection & Date Range
              _buildControlsSection(),
              
              // Analytics Cards
              if (_selectedEmployee != null && !_isLoading)
                Expanded(child: _buildAnalyticsSection()),
              
              // Loading
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading analytics...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // No employee selected
              if (_selectedEmployee == null && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Select an employee to view analytics',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose from the dropdown above to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          
          // Employee Selection
          DropdownButtonFormField<UserModel>(
            initialValue: _selectedEmployee,
            decoration: InputDecoration(
              labelText: 'Select Employee',
              labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary, width: 2.5),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            selectedItemBuilder: (context) {
              return _employees.map((employee) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${employee.name} • ${employee.position}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            items: _employees.map((employee) => DropdownMenuItem(
              value: employee,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            employee.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.position,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
            onChanged: (employee) {
              setState(() {
                _selectedEmployee = employee;
                _attendanceRecords.clear();
              });
              if (employee != null) {
                _loadEmployeeAnalytics();
              }
            },
            hint: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Choose an employee to analyze',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            dropdownColor: Colors.white,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            iconSize: 24,
          ),
          
          const SizedBox(height: 20),
          
          // Date Range
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, 
                             color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'From Date',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, 
                             color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'To Date',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Info Card
          _buildEmployeeInfoCard(),
          const SizedBox(height: 20),
          
          // Quick Stats
          _buildQuickStatsGrid(),
          const SizedBox(height: 20),
          
          // Detailed Analytics
          _buildDetailedAnalytics(),
          const SizedBox(height: 20),
          
          // Recent Activity
          _buildRecentActivitySection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: Text(
                _selectedEmployee!.name.isNotEmpty 
                    ? _selectedEmployee!.name.substring(0, 1).toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedEmployee!.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedEmployee!.position,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedEmployee!.role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.date_range,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_endDate.difference(_startDate).inDays + 1} days',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Total Days',
          value: '$_totalDays',
          icon: Icons.calendar_month_outlined,
          color: AppColors.primary,
          gradient: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
        ),
        _buildStatCard(
          title: 'Present Days',
          value: '$_presentDays',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          gradient: [Colors.green, Colors.green.withValues(alpha: 0.7)],
        ),
        _buildStatCard(
          title: 'Late Days',
          value: '$_lateDays',
          icon: Icons.access_time_outlined,
          color: Colors.orange,
          gradient: [Colors.orange, Colors.orange.withValues(alpha: 0.7)],
        ),
        _buildStatCard(
          title: 'Absent Days',
          value: '$_absentDays',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          gradient: [Colors.red, Colors.red.withValues(alpha: 0.7)],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    List<Color>? gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient != null 
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradient != null 
                    ? Colors.white.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                size: 28, 
                color: gradient != null ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: gradient != null ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: gradient != null 
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAnalytics() {
    final attendanceRate = _totalDays > 0 ? ((_presentDays + _lateDays) / _totalDays * 100) : 0.0;
    final punctualityRate = (_presentDays + _lateDays) > 0 ? (_presentDays / (_presentDays + _lateDays) * 100) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Detailed Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Analytics metrics
          _buildAnalyticsRow('Total Working Hours', '${_totalWorkingHours.toStringAsFixed(1)}.', Icons.schedule_outlined, AppColors.primary),
          _buildAnalyticsRow('Average Daily Hours', '${_averageWorkingHours.toStringAsFixed(1)}.', Icons.access_time_outlined, Colors.blue),
          _buildAnalyticsRow('Attendance Rate', '${attendanceRate.toStringAsFixed(1)}%', Icons.trending_up_outlined, Colors.green),
          _buildAnalyticsRow('Punctuality Rate', '${punctualityRate.toStringAsFixed(1)}%', Icons.schedule_outlined, Colors.orange),
          
          const SizedBox(height: 24),
          
          // Section divider
          Container(
            height: 1,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Attendance Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress bars
          _buildProgressBar('Present', _presentDays, _totalDays, Colors.green),
          _buildProgressBar('Late', _lateDays, _totalDays, Colors.orange),
          _buildProgressBar('Absent', _absentDays, _totalDays, Colors.red),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? value / total : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '$value/$total (${(percentage * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final recentRecords = _attendanceRecords.take(5).toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (recentRecords.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity will appear here once data is available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...recentRecords.map((record) => _buildActivityTile(record)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(AttendanceModel record) {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final realTimeStatus = _calculateShiftBasedStatus(record, shiftProvider);
    final lateTime = _calculateLateTime(record, shiftProvider);
    
    Color statusColor;
    IconData statusIcon;
    
    switch (realTimeStatus.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Text(
        DateFormat('EEEE, MMM dd, yyyy').format(record.date),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              if (record.checkInTime != null) ...[
                Text(
                  'In: ${DateFormat('h:mm a').format(record.checkInTime!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (record.checkInTime != null && record.checkOutTime != null)
                Text(' • ', style: TextStyle(color: Colors.grey[400])),
              if (record.checkOutTime != null) ...[
                Text(
                  'Out: ${DateFormat('h:mm a').format(record.checkOutTime!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          if (record.totalMinutes > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Hours: ${(record.totalMinutes / 60).toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          // Show late time if employee was late
          if (lateTime.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lateTime,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          realTimeStatus.toUpperCase(),
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() => _startDate = date);
      if (_selectedEmployee != null) {
        _loadEmployeeAnalytics();
      }
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() => _endDate = date);
      if (_selectedEmployee != null) {
        _loadEmployeeAnalytics();
      }
    }
  }
}
