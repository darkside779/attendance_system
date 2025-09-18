import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/admin_attendance_provider.dart';
import '../../services/export_service.dart';
import 'package:intl/intl.dart';

class EmployeeHistoryScreen extends StatefulWidget {
  final UserModel employee;

  const EmployeeHistoryScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EmployeeHistoryScreen> createState() => _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends State<EmployeeHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFilter = 'all';
  bool _isLoading = true;
  List<AttendanceModel> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeDateRange();
    _loadAttendanceHistory();
  }

  void _initializeDateRange() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1); // Start of current month
    _endDate = DateTime(now.year, now.month + 1, 0); // End of current month
  }

  Future<void> _loadAttendanceHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AdminAttendanceProvider>(context, listen: false);
      final history = await provider.getEmployeeAttendanceHistory(
        widget.employee.userId,
        _startDate!,
        _endDate!,
      );

      if (mounted) {
        setState(() {
          _attendanceHistory = _filterAttendance(history);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance history: $e')),
        );
      }
    }
  }

  List<AttendanceModel> _filterAttendance(List<AttendanceModel> history) {
    if (_selectedFilter == 'all') return history;

    return history.where((attendance) {
      switch (_selectedFilter) {
        case 'present':
          return attendance.status.toLowerCase() == 'present';
        case 'late':
          return attendance.status.toLowerCase() == 'late';
        case 'absent':
          return attendance.status.toLowerCase() == 'absent';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.employee.name} - Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportHistory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendanceHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildStatsSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _attendanceHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'From: ${DateFormat('MMM dd, yyyy').format(_startDate!)}',
                  ),
                  onPressed: () => _selectDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'To: ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                  ),
                  onPressed: () => _selectDate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All'),
                      _buildFilterChip('present', 'Present'),
                      _buildFilterChip('late', 'Late'),
                      _buildFilterChip('absent', 'Absent'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = value;
              _attendanceHistory = _filterAttendance(_attendanceHistory);
            });
          }
        },
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalDays = _attendanceHistory.length;
    final presentDays = _attendanceHistory.where((a) => a.status.toLowerCase() == 'present').length;
    final lateDays = _attendanceHistory.where((a) => a.status.toLowerCase() == 'late').length;
    final absentDays = _attendanceHistory.where((a) => a.status.toLowerCase() == 'absent').length;
    final totalHours = _attendanceHistory.fold(0.0, (sum, a) => sum + (a.totalMinutes / 60.0));

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Days', totalDays.toString(), Colors.blue)),
              Expanded(child: _buildStatCard('Present', presentDays.toString(), Colors.green)),
              Expanded(child: _buildStatCard('Late', lateDays.toString(), Colors.orange)),
              Expanded(child: _buildStatCard('Absent', absentDays.toString(), Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: _buildStatCard(
              'Total Hours',
              '${totalHours.toStringAsFixed(1)}h',
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
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
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceHistory.length,
      itemBuilder: (context, index) {
        final attendance = _attendanceHistory[index];
        return _buildAttendanceCard(attendance);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance) {
    Color statusColor;
    IconData statusIcon;

    switch (attendance.status.toLowerCase()) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(attendance.date),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
              ],
            ),
            if (attendance.checkInTime != null || attendance.checkOutTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (attendance.checkInTime != null) ...[
                    Icon(Icons.login, color: Colors.green[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'In: ${DateFormat('HH:mm').format(attendance.checkInTime!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (attendance.checkOutTime != null) ...[
                    Icon(Icons.logout, color: Colors.red[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Out: ${DateFormat('HH:mm').format(attendance.checkOutTime!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (attendance.totalMinutes > 0) ...[
                    Icon(Icons.timer, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${(attendance.totalMinutes / 60).toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ],
            if (attendance.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      attendance.location,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your date range or filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate! : _endDate!,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate!.isAfter(_endDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate!.isBefore(_startDate!)) {
            _startDate = _endDate;
          }
        }
      });
      _loadAttendanceHistory();
    }
  }

  Future<void> _exportHistory() async {
    try {
      final exportService = ExportService();
      final dateRange = '${DateFormat('yyyy-MM-dd').format(_startDate!)}_to_${DateFormat('yyyy-MM-dd').format(_endDate!)}';
      final fileName = '${widget.employee.name.replaceAll(' ', '_')}_attendance_$dateRange';

      final reportData = _attendanceHistory.map((attendance) => {
        'employee_name': widget.employee.name,
        'email': widget.employee.email,
        'position': widget.employee.position,
        'date': attendance.date.toIso8601String(),
        'status': attendance.status,
        'check_in_time': attendance.checkInTime?.toIso8601String() ?? '',
        'check_out_time': attendance.checkOutTime?.toIso8601String() ?? '',
        'total_hours': (attendance.totalMinutes / 60.0).toStringAsFixed(2),
      }).toList();

      await exportService.exportToCSV(
        reportData: reportData,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance history exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
