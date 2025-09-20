// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import '../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';

class AttendanceTimeManagementScreen extends StatefulWidget {
  const AttendanceTimeManagementScreen({super.key});

  @override
  State<AttendanceTimeManagementScreen> createState() => _AttendanceTimeManagementScreenState();
}

class _AttendanceTimeManagementScreenState extends State<AttendanceTimeManagementScreen> {
  List<UserModel> _employees = [];
  List<AttendanceModel> _attendanceRecords = [];
  UserModel? _selectedEmployee;
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

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
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceRecords() async {
    if (_selectedEmployee == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Temporary fix: Remove orderBy to avoid index requirement
      final query = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _selectedEmployee!.userId)
          .limit(30) // Last 30 records
          .get();

      _attendanceRecords = query.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel.fromJson({...data, 'attendanceId': doc.id});
      }).toList();
      
      // Sort by date descending (client-side sorting as workaround)
      _attendanceRecords.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance records: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editAttendanceRecord(AttendanceModel record) async {
    DateTime? checkInTime = record.checkInTime;
    DateTime? checkOutTime = record.checkOutTime;
    String status = record.status;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditAttendanceDialog(
        record: record,
        initialCheckIn: checkInTime,
        initialCheckOut: checkOutTime,
        initialStatus: status,
      ),
    );

    if (result != null) {
      await _updateAttendanceRecord(record.attendanceId, result);
    }
  }

  Future<void> _updateAttendanceRecord(String attendanceId, Map<String, dynamic> updates) async {
    try {
      setState(() => _isLoading = true);
      
      // Calculate total minutes if both times are provided
      if (updates['checkInTime'] != null && updates['checkOutTime'] != null) {
        final checkIn = updates['checkInTime'] as DateTime;
        final checkOut = updates['checkOutTime'] as DateTime;
        
        // Handle cross-midnight scenarios
        int totalMinutes;
        
        // Check if checkout time suggests next day (before 6 AM)
        final checkOutHour = checkOut.hour;
        final checkInHour = checkIn.hour;
        
        if ((checkOutHour >= 0 && checkOutHour < 6) && checkInHour > 12) {
          // Checkout is early morning (0-6 AM) and checkin is afternoon/evening
          // This suggests cross-midnight scenario
          final nextDayCheckOut = DateTime(
            checkOut.year,
            checkOut.month,
            checkOut.day + 1,
            checkOut.hour,
            checkOut.minute,
            checkOut.second,
          );
          totalMinutes = nextDayCheckOut.difference(checkIn).inMinutes;
        } else {
          totalMinutes = checkOut.difference(checkIn).inMinutes;
        }
        
        // Ensure totalMinutes is not negative and reasonable (max 24 hours)
        if (totalMinutes < 0 || totalMinutes > 1440) {
          totalMinutes = 0;
        }
        
        updates['totalMinutes'] = totalMinutes;
      } else {
        // If either time is missing, set totalMinutes to 0
        updates['totalMinutes'] = 0;
      }
      
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendanceId)
          .update(updates);
          
      setState(() {
        _successMessage = 'Attendance record updated successfully';
        _isLoading = false;
      });
      
      // Reload records to show changes
      await _loadAttendanceRecords();
      
      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update record: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAttendanceRecord(String attendanceId, String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance Record'),
        content: Text('Are you sure you want to delete the attendance record for $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceId)
            .delete();
            
        setState(() {
          _successMessage = 'Attendance record deleted successfully';
          _isLoading = false;
        });
        
        await _loadAttendanceRecords();
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMessage = null);
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to delete record: $e';
          _isLoading = false;
        });
      }
    }
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
      print('  ❌ No check-in time - returning absent');
      return 'absent';
    }
    
    // Get employee's shift
    final shift = _getEmployeeShift(attendance, shiftProvider);
    if (shift == null) {
      print('  ⚠️  No shift found - using stored status: ${attendance.status}');
      return attendance.status; // Fallback to stored status if no shift
    }
    
    print('  ✅ Shift found: ${shift.shiftName} (${shift.startTime} - ${shift.endTime}, Grace: ${shift.gracePeriodMinutes}min)');
    
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
    print('  📅 Shift Start: $shiftStart');
    print('  ⏰ Grace Period End: $gracePeriodEnd');
    print('  🕐 Check-in Time: ${attendance.checkInTime}');
    
    // Define acceptable check-in window (1 hour before to 4 hours after shift start)
    final earlyWindow = shiftStart.subtract(const Duration(hours: 1));
    final lateWindow = shiftStart.add(const Duration(hours: 4));
    
    if (attendance.checkInTime!.isBefore(earlyWindow) || attendance.checkInTime!.isAfter(lateWindow)) {
      // Check-in is way outside shift window - mark as late (worked wrong hours)
      final hoursDifference = attendance.checkInTime!.difference(shiftStart).inHours.abs();
      print('  ⚠️  LATE: Check-in outside shift window (${hoursDifference}h from shift start)');
      return 'late';
    } else if (attendance.checkInTime!.isBefore(gracePeriodEnd) || attendance.checkInTime!.isAtSameMomentAs(gracePeriodEnd)) {
      print('  ✅ PRESENT: Check-in within grace period');
      return 'present';
    } else {
      final lateMinutes = attendance.checkInTime!.difference(gracePeriodEnd).inMinutes;
      print('  ⚠️  LATE: Check-in ${lateMinutes} minutes after grace period');
      return 'late';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, child) {
        return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text(
          'Time Management',
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
          // Controls Section
          _buildControlsSection(),
          
          // Success/Error messages
          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Loading indicator
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
                      'Loading attendance records...',
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

          // Attendance Records List
          if (_selectedEmployee != null && !_isLoading)
            Expanded(
              child: _attendanceRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No attendance records found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Attendance records will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _attendanceRecords.length,
                      itemBuilder: (context, index) {
                        final record = _attendanceRecords[index];
                        return _buildAttendanceCard(record);
                      },
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
                      Icons.schedule_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select an employee to manage time',
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employee Selection',
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
                _errorMessage = null;
                _successMessage = null;
              });
              if (employee != null) {
                _loadAttendanceRecords();
              }
            },
            hint: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Choose an employee to manage their time',
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
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel record) {
    final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(record.date);
    final checkInStr = record.checkInTime != null 
        ? DateFormat('h:mm a').format(record.checkInTime!) 
        : 'Not recorded';
    final checkOutStr = record.checkOutTime != null 
        ? DateFormat('h:mm a').format(record.checkOutTime!) 
        : 'Not recorded';
    
    final workingHours = record.totalMinutes > 0 
        ? '${(record.totalMinutes / 60).toStringAsFixed(1)}h' 
        : '0h';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildStatusChip(record),
              ],
            ),
            const SizedBox(height: 20),
            
            // Time information grid
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo('Check-in', checkInStr, Icons.login_outlined),
                ),
                Expanded(
                  child: _buildTimeInfo('Check-out', checkOutStr, Icons.logout_outlined),
                ),
                Expanded(
                  child: _buildTimeInfo('Hours', workingHours, Icons.access_time_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _editAttendanceRecord(record),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _deleteAttendanceRecord(record.attendanceId, dateStr),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AttendanceModel record) {
    // Calculate real-time status based on shift
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final realTimeStatus = _calculateShiftBasedStatus(record, shiftProvider);
    
    // Debug: Print shift calculation info
    print('🔍 Status Debug for ${record.date}:');
    print('  - Employee: ${_selectedEmployee?.name}');
    print('  - Assigned Shift ID: ${_selectedEmployee?.assignedShiftId}');
    print('  - Check-in: ${record.checkInTime}');
    print('  - Calculated Status: $realTimeStatus');
    print('  - Stored Status: ${record.status}');
    
    Color color;
    IconData icon;
    switch (realTimeStatus.toLowerCase()) {
      case 'present':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'late':
        color = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'absent':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            realTimeStatus.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditAttendanceDialog extends StatefulWidget {
  final AttendanceModel record;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;
  final String initialStatus;

  const _EditAttendanceDialog({
    required this.record,
    this.initialCheckIn,
    this.initialCheckOut,
    required this.initialStatus,
  });

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  String _status = 'present';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkInTime = widget.initialCheckIn;
    _checkOutTime = widget.initialCheckOut;
    _status = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy').format(widget.record.date);
    
    return AlertDialog(
      title: Text('Edit Attendance - $dateStr'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Check-in time
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Check-in Time'),
              subtitle: Text(_checkInTime != null 
                  ? DateFormat('HH:mm').format(_checkInTime!) 
                  : 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () => _selectTime(true),
              ),
            ),
            
            // Check-out time
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Check-out Time'),
              subtitle: Text(_checkOutTime != null 
                  ? DateFormat('HH:mm').format(_checkOutTime!) 
                  : 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () => _selectTime(false),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status dropdown
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['present', 'late', 'absent'].map((s) => 
                DropdownMenuItem(value: s, child: Text(s.toUpperCase()))
              ).toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            
            const SizedBox(height: 16),
            
            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Reason for time adjustment...',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final initialTime = isCheckIn ? _checkInTime : _checkOutTime;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime ?? DateTime.now()),
    );

    if (selectedTime != null) {
      final selectedDateTime = DateTime(
        widget.record.date.year,
        widget.record.date.month,
        widget.record.date.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      setState(() {
        if (isCheckIn) {
          _checkInTime = selectedDateTime;
        } else {
          _checkOutTime = selectedDateTime;
        }
      });
    }
  }

  void _saveChanges() {
    final updates = <String, dynamic>{
      'status': _status,
      'checkInTime': _checkInTime,
      'checkOutTime': _checkOutTime,
    };

    if (_notesController.text.isNotEmpty) {
      updates['notes'] = _notesController.text;
    }

    Navigator.pop(context, updates);
  }
}
