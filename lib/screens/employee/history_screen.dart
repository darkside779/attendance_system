// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
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
    
    if (authProvider.currentUser != null) {
      await attendanceProvider.loadAttendanceHistory(
        authProvider.currentUser!.userId,
      );
      await attendanceProvider.loadMonthlyStats(
        authProvider.currentUser!.userId,
      );
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
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
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
              _buildMonthlySummary(attendanceProvider),
              
              const SizedBox(height: 20),
              
              // Calendar View
              _buildCalendarView(monthlyAttendance),
              
              const SizedBox(height: 20),
              
              // Recent Records
              _buildRecentRecords(monthlyAttendance),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
        if (attendanceProvider.isLoading) {
          return const Center(child: LoadingWidget());
        }

        List<AttendanceModel> filteredHistory = attendanceProvider.attendanceHistory;
        
        // Apply filter
        if (_selectedFilter != 'all') {
          filteredHistory = filteredHistory
              .where((attendance) => attendance.status.toLowerCase() == _selectedFilter)
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
                        return AttendanceStatusCard(
                          date: _formatDate(attendance.date),
                          checkInTime: attendance.checkInTime != null 
                              ? _formatTime(attendance.checkInTime!)
                              : '--:--',
                          checkOutTime: attendance.checkOutTime != null 
                              ? _formatTime(attendance.checkOutTime!)
                              : null,
                          totalHours: attendance.getWorkingHours(),
                          status: attendance.status,
                          onTap: () => _showAttendanceDetails(attendance),
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
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
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

  Widget _buildMonthlySummary(AttendanceProvider attendanceProvider) {
    final stats = attendanceProvider.monthlyStats;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getMonthYearString(DateTime.now()),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  title: 'Present',
                  value: '${stats['present'] ?? 0}',
                  color: AppColors.white,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  title: 'Absent',
                  value: '${stats['absent'] ?? 0}',
                  color: AppColors.white,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  title: 'Late',
                  value: '${stats['late'] ?? 0}',
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<AttendanceModel> monthlyAttendance) {
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
            'Calendar View',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Simplified calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 35, // 5 weeks
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final hasAttendance = monthlyAttendance.any(
                (attendance) => attendance.date.day == dayNumber,
              );
              
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: hasAttendance ? AppColors.success.withOpacity(0.2) : null,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: hasAttendance ? AppColors.success : AppColors.lightGrey,
                  ),
                ),
                child: Center(
                  child: Text(
                    dayNumber <= 31 ? dayNumber.toString() : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasAttendance ? AppColors.success : AppColors.textSecondary,
                      fontWeight: hasAttendance ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecords(List<AttendanceModel> monthlyAttendance) {
    final recentRecords = monthlyAttendance.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Records',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        ...recentRecords.map((attendance) => AttendanceStatusCard(
          date: _formatDate(attendance.date),
          checkInTime: attendance.checkInTime != null 
              ? _formatTime(attendance.checkInTime!)
              : '--:--',
          checkOutTime: attendance.checkOutTime != null 
              ? _formatTime(attendance.checkOutTime!)
              : null,
          totalHours: attendance.getWorkingHours(),
          status: attendance.status,
          onTap: () => _showAttendanceDetails(attendance),
        )),
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

  void _showAttendanceDetails(AttendanceModel attendance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance Details - ${_formatDate(attendance.date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Status', attendance.status),
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
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
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
