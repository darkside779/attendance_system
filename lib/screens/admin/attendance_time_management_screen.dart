import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
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
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      _employees = snapshot.docs.map((doc) {
        final data = doc.data();
        return UserModel.fromJson({...data, 'userId': doc.id});
      }).where((user) => user.role.toLowerCase() != 'superadmin').toList();
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
      final query = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _selectedEmployee!.userId)
          .orderBy('date', descending: true)
          .limit(30) // Last 30 records
          .get();

      _attendanceRecords = query.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel.fromJson({...data, 'attendanceId': doc.id});
      }).toList();
      
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
        updates['totalMinutes'] = checkOut.difference(checkIn).inMinutes;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Management'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Success/Error messages
          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
            ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          
          // Employee Selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<UserModel>(
              initialValue: _selectedEmployee,
              decoration: const InputDecoration(
                labelText: 'Select Employee',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _employees.map((employee) => DropdownMenuItem(
                value: employee,
                child: Text('${employee.name} (${employee.position})'),
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
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),

          // Attendance Records List
          if (_selectedEmployee != null && !_isLoading)
            Expanded(
              child: _attendanceRecords.isEmpty
                  ? const Center(
                      child: Text(
                        'No attendance records found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel record) {
    final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(record.date);
    final checkInStr = record.checkInTime != null 
        ? DateFormat('HH:mm').format(record.checkInTime!) 
        : 'Not recorded';
    final checkOutStr = record.checkOutTime != null 
        ? DateFormat('HH:mm').format(record.checkOutTime!) 
        : 'Not recorded';
    
    final workingHours = record.totalMinutes > 0 
        ? '${(record.totalMinutes / 60).toStringAsFixed(1)}h' 
        : '0h';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(record.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo('Check-in', checkInStr, Icons.login),
                ),
                Expanded(
                  child: _buildTimeInfo('Check-out', checkOutStr, Icons.logout),
                ),
                Expanded(
                  child: _buildTimeInfo('Hours', workingHours, Icons.access_time),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editAttendanceRecord(record),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteAttendanceRecord(record.attendanceId, dateStr),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          time,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'present':
        color = Colors.green;
        break;
      case 'late':
        color = Colors.orange;
        break;
      case 'absent':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
