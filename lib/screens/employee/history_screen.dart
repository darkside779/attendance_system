// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../models/shift_model.dart';
import '../../widgets/attendance_card.dart';
import '../../widgets/loading_widget.dart';
import '../../models/attendance_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAttendanceHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await attendanceProvider.loadAttendanceHistory(
        authProvider.currentUser!.userId,
      );
      await attendanceProvider.loadMonthlyStats(
        authProvider.currentUser!.userId,
      );
      await shiftProvider.loadShifts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'This Month'),
            Tab(text: 'History'),
            Tab(text: 'Statistics'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _showDateRangePicker,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildThisMonthTab(),
          _buildHistoryTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildThisMonthTab() {
    return Consumer2<AttendanceProvider, ShiftProvider>(
      builder: (context, attendanceProvider, shiftProvider, child) {
        if (attendanceProvider.isLoading) {
          return const Center(child: LoadingWidget());
        }

        final currentMonth = DateTime.now();
        final monthlyAttendance = attendanceProvider.attendanceHistory
            .where((attendance) => 
                attendance.date.month == currentMonth.month &&
                attendance.date.year == currentMonth.year)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Summary
              _buildMonthlySummary(attendanceProvider, shiftProvider),
              
              const SizedBox(height: 20),
              
              // Calendar View
              _buildCalendarView(monthlyAttendance, shiftProvider),
              
              const SizedBox(height: 20),
              
              // Recent Records
              _buildRecentRecords(monthlyAttendance, shiftProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer2<AttendanceProvider, ShiftProvider>(
      builder: (context, attendanceProvider, shiftProvider, child) {
        if (attendanceProvider.isLoading) {
          return const Center(child: LoadingWidget());
        }

        List<AttendanceModel> filteredHistory = attendanceProvider.attendanceHistory;
        
        // Apply filter with shift-based status
        if (_selectedFilter != 'all') {
          filteredHistory = filteredHistory
              .where((attendance) {
                final shiftBasedStatus = _calculateShiftBasedStatus(attendance, shiftProvider);
                return shiftBasedStatus.status.toLowerCase() == _selectedFilter;
              })
              .toList();
        }

        return Column(
          children: [
            // Filter chips
            _buildFilterChips(),
            
            // Attendance list
            Expanded(
              child: filteredHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final attendance = filteredHistory[index];
                        final shiftBasedStatus = _calculateShiftBasedStatus(attendance, shiftProvider);
                        return AttendanceStatusCard(
                          date: _formatDate(attendance.date),
                          checkInTime: attendance.checkInTime != null 
                              ? _formatTime(attendance.checkInTime!)
                              : '--:--',
                          checkOutTime: attendance.checkOutTime != null 
                              ? _formatTime(attendance.checkOutTime!)
                              : null,
                          totalHours: attendance.getWorkingHours(),
                          status: shiftBasedStatus.status,
                          onTap: () => _showAttendanceDetails(attendance, shiftProvider),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return Consumer2<AttendanceProvider, ShiftProvider>(
      builder: (context, attendanceProvider, shiftProvider, child) {
        if (attendanceProvider.isLoading) {
          return const Center(child: LoadingWidget());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Statistics
              _buildOverallStats(attendanceProvider),
              
              const SizedBox(height: 20),
              
              // Monthly Trends
              _buildMonthlyTrends(attendanceProvider),
              
              const SizedBox(height: 20),
              
              // Performance Metrics
              _buildPerformanceMetrics(attendanceProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlySummary(AttendanceProvider attendanceProvider, ShiftProvider shiftProvider) {
    // Calculate shift-based monthly stats
    final currentMonth = DateTime.now();
    final monthlyAttendance = attendanceProvider.attendanceHistory
        .where((attendance) => 
            attendance.date.month == currentMonth.month &&
            attendance.date.year == currentMonth.year)
        .toList();
    
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    
    for (final attendance in monthlyAttendance) {
      final shiftBasedStatus = _calculateShiftBasedStatus(attendance, shiftProvider);
      switch (shiftBasedStatus.status.toLowerCase()) {
        case 'present':
          presentCount++;
          break;
        case 'late':
          lateCount++;
          break;
        case 'absent':
          absentCount++;
          break;
      }
    }
    
    final stats = {
      'present': presentCount,
      'late': lateCount,
      'absent': absentCount,
    };
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF1E40AF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMonthYearString(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monthly Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: _ModernSummaryItem(
                  title: 'Present',
                  value: '${stats['present'] ?? 0}',
                  color: const Color(0xFF22C55E),
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModernSummaryItem(
                  title: 'Absent',
                  value: '${stats['absent'] ?? 0}',
                  color: const Color(0xFFEF4444),
                  icon: Icons.cancel_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModernSummaryItem(
                  title: 'Late',
                  value: '${stats['late'] ?? 0}',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<AttendanceModel> monthlyAttendance, ShiftProvider shiftProvider) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
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
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Calendar View',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 8),
          
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 42, // 6 weeks max
            itemBuilder: (context, index) {
              final dayOffset = index - (firstWeekday - 1);
              final dayNumber = dayOffset + 1;
              final isValidDay = dayNumber > 0 && dayNumber <= daysInMonth;
              final isToday = isValidDay && dayNumber == now.day;
              
              AttendanceModel? dayAttendance;
              if (isValidDay) {
                try {
                  dayAttendance = monthlyAttendance.where((attendance) => 
                    attendance.date.day == dayNumber
                  ).first;
                } catch (_) {
                  dayAttendance = null;
                }
              }
              
              Color? backgroundColor;
              Color? borderColor;
              Color textColor = const Color(0xFF6B7280);
              
              if (isValidDay) {
                if (dayAttendance != null) {
                  final shiftBasedStatus = _calculateShiftBasedStatus(dayAttendance, shiftProvider);
                  switch (shiftBasedStatus.status.toLowerCase()) {
                    case 'present':
                      backgroundColor = const Color(0xFF22C55E).withOpacity(0.1);
                      borderColor = const Color(0xFF22C55E);
                      textColor = const Color(0xFF22C55E);
                      break;
                    case 'late':
                      backgroundColor = const Color(0xFFF59E0B).withOpacity(0.1);
                      borderColor = const Color(0xFFF59E0B);
                      textColor = const Color(0xFFF59E0B);
                      break;
                    case 'absent':
                      backgroundColor = const Color(0xFFEF4444).withOpacity(0.1);
                      borderColor = const Color(0xFFEF4444);
                      textColor = const Color(0xFFEF4444);
                      break;
                  }
                } else {
                  textColor = const Color(0xFF374151);
                }
                
                if (isToday) {
                  backgroundColor = const Color(0xFF3B82F6).withOpacity(0.1);
                  borderColor = const Color(0xFF3B82F6);
                  textColor = const Color(0xFF3B82F6);
                }
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
                ),
                child: Center(
                  child: isValidDay ? Text(
                    dayNumber.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (dayAttendance != null || isToday) ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ) : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecords(List<AttendanceModel> monthlyAttendance, ShiftProvider shiftProvider) {
    final recentRecords = monthlyAttendance.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (recentRecords.length > 3)
              TextButton(
                onPressed: () {
                  // Navigate to full history
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (recentRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No attendance records yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your attendance history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB5B7C1),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentRecords.map((attendance) {
            final shiftBasedStatus = _calculateShiftBasedStatus(attendance, shiftProvider);
            return AttendanceStatusCard(
              date: _formatDate(attendance.date),
              checkInTime: attendance.checkInTime != null 
                  ? _formatTime(attendance.checkInTime!)
                  : '--:--',
              checkOutTime: attendance.checkOutTime != null 
                  ? _formatTime(attendance.checkOutTime!)
                  : null,
              totalHours: attendance.getWorkingHours(),
              status: shiftBasedStatus.status,
              onTap: () => _showAttendanceDetails(attendance, shiftProvider),
            );
          }),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'present', 'label': 'Present'},
      {'key': 'absent', 'label': 'Absent'},
      {'key': 'late', 'label': 'Late'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key']!;
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: AppColors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Records will appear here once you start checking in',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grey.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats(AttendanceProvider attendanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _StatCard(
              title: 'Attendance Rate',
              value: '87%',
              icon: Icons.trending_up,
              color: AppColors.success,
            ),
            _StatCard(
              title: 'Average Hours',
              value: '8.2h',
              icon: Icons.schedule,
              color: AppColors.info,
            ),
            _StatCard(
              title: 'On Time Rate',
              value: '92%',
              icon: Icons.access_time,
              color: AppColors.primary,
            ),
            _StatCard(
              title: 'Late Days',
              value: '3',
              icon: Icons.warning,
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyTrends(AttendanceProvider attendanceProvider) {
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
            'Monthly Trends',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Placeholder for chart
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.lightGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Attendance Trend Chart\n(Implementation pending)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(AttendanceProvider attendanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        _MetricRow(
          title: 'Average Check-in Time',
          value: '9:15 AM',
          trend: '5 min late',
          isPositive: false,
        ),
        _MetricRow(
          title: 'Average Check-out Time',
          value: '6:30 PM',
          trend: '30 min overtime',
          isPositive: true,
        ),
        _MetricRow(
          title: 'Most Productive Day',
          value: 'Wednesday',
          trend: '9.2 avg hours',
          isPositive: true,
        ),
      ],
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('All Records'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Present Only'),
              leading: Radio<String>(
                value: 'present',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Absent Only'),
              leading: Radio<String>(
                value: 'absent',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Late Only'),
              leading: Radio<String>(
                value: 'late',
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangePicker() async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    
    if (dateRange != null) {
      setState(() {
        _selectedDateRange = dateRange;
      });
      _loadAttendanceHistory();
    }
  }

  void _showAttendanceDetails(AttendanceModel attendance, ShiftProvider shiftProvider) {
    final shiftBasedStatus = _calculateShiftBasedStatus(attendance, shiftProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance Details - ${_formatDate(attendance.date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Status', shiftBasedStatus.status.toUpperCase()),
            if (shiftBasedStatus.lateInfo != null)
              _DetailRow('Late By', shiftBasedStatus.lateInfo!),
            _DetailRow('Check In', attendance.checkInTime != null 
                ? _formatDateTime(attendance.checkInTime!)
                : 'Not checked in'),
            _DetailRow('Check Out', attendance.checkOutTime != null 
                ? _formatDateTime(attendance.checkOutTime!)
                : 'Not checked out'),
            _DetailRow('Working Hours', attendance.getWorkingHours()),
            _DetailRow('Location', attendance.location),
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatTime(dateTime)} - ${_formatDate(dateTime)}';
  }

  String _getMonthYearString(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Helper method to get employee's assigned shift
  ShiftModel? _getEmployeeShift(String userId, ShiftProvider shiftProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser?.assignedShiftId == null) return null;
    
    try {
      return shiftProvider.shifts.firstWhere(
        (shift) => shift.shiftId == currentUser!.assignedShiftId,
      );
    } catch (_) {
      return null;
    }
  }

  // Helper method to calculate shift-based status
  ({String status, String? lateInfo}) _calculateShiftBasedStatus(
    AttendanceModel attendance, 
    ShiftProvider shiftProvider
  ) {
    if (attendance.checkInTime == null) {
      return (status: 'absent', lateInfo: null);
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeShift = _getEmployeeShift(authProvider.currentUser?.userId ?? '', shiftProvider);
    if (employeeShift == null || employeeShift.shiftId.isEmpty) {
      // No shift assigned, use stored status
      return (status: attendance.status, lateInfo: null);
    }

    final checkInTime = attendance.checkInTime!;
    final checkInMinutes = checkInTime.hour * 60 + checkInTime.minute;
    
    // Parse shift start and end times
    final shiftStartParts = employeeShift.startTime.split(':');
    final shiftStartMinutes = int.parse(shiftStartParts[0]) * 60 + int.parse(shiftStartParts[1]);
    
    final shiftEndParts = employeeShift.endTime.split(':');
    final shiftEndMinutes = int.parse(shiftEndParts[0]) * 60 + int.parse(shiftEndParts[1]);
    
    // Check if check-in is outside the shift window (including reasonable buffer)
    // Allow check-in up to 2 hours after shift end for flexibility
    final extendedShiftEndMinutes = shiftEndMinutes + 120; // 2 hours buffer
    
    if (checkInMinutes < shiftStartMinutes || checkInMinutes > extendedShiftEndMinutes) {
      return (status: 'absent', lateInfo: 'Check-in outside shift hours');
    }

    // Check if within normal shift hours
    final graceEndMinutes = shiftStartMinutes + employeeShift.gracePeriodMinutes;

    if (checkInMinutes <= shiftStartMinutes) {
      return (status: 'present', lateInfo: null);
    } else if (checkInMinutes <= graceEndMinutes) {
      return (status: 'present', lateInfo: null);
    } else {
      final lateMinutes = checkInMinutes - graceEndMinutes;
      final hours = lateMinutes ~/ 60;
      final minutes = lateMinutes % 60;
      final lateInfo = hours > 0 ? '${hours}h ${minutes}min late' : '${minutes}min late';
      return (status: 'late', lateInfo: lateInfo);
    }
  }
}

class _ModernSummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _ModernSummaryItem({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositive;

  const _MetricRow({
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: isPositive ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
