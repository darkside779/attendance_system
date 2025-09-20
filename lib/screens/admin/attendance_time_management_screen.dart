// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../models/attendance_model.dart';

class AttendanceTimeManagementScreen extends StatefulWidget {
  const AttendanceTimeManagementScreen({super.key});

  @override
  State<AttendanceTimeManagementScreen> createState() => _AttendanceTimeManagementScreenState();
}

class _AttendanceTimeManagementScreenState extends State<AttendanceTimeManagementScreen> {
  List<UserModel> _employees = [];
  List<AttendanceModel> _attendanceRecords = [];
  UserModel? _selectedEmployee;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
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

  Future<void> _loadAttendanceForDate() async {
    if (_selectedEmployee == null) return;
    
    setState(() => _isLoading = true);
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _selectedEmployee!.userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      _attendanceRecords = snapshot.docs.map((doc) {
        final data = doc.data();
        return AttendanceModel.fromJson({...data, 'attendanceId': doc.id});
      }).toList();
      
      // Remove duplicates - keep only the most recent record if multiple exist
      if (_attendanceRecords.length > 1) {
        _attendanceRecords.sort((a, b) => b.date.compareTo(a.date));
        final mainRecord = _attendanceRecords.first;
        
        // Delete duplicate records from Firebase
        for (int i = 1; i < _attendanceRecords.length; i++) {
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(_attendanceRecords[i].attendanceId)
              .delete();
        }
        
        _attendanceRecords = [mainRecord];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed duplicate records')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load attendance: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Time Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmployeeSelector(),
          const SizedBox(height: 16),
          _buildDateSelector(),
          const SizedBox(height: 16),
          if (_selectedEmployee != null) _buildAttendanceRecords(),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Employee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserModel>(
              value: _selectedEmployee,
              decoration: const InputDecoration(
                labelText: 'Employee',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select Employee'),
              items: _employees.map((employee) => DropdownMenuItem(
                value: employee,
                child: Text('${employee.name} (${employee.position})'),
              )).toList(),
              onChanged: (employee) {
                setState(() => _selectedEmployee = employee);
                _loadAttendanceForDate();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              title: Text(DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRecords() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Attendance Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _createNewAttendanceRecord,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Record'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_attendanceRecords.isEmpty)
              _buildNoRecordsMessage()
            else
              ..._attendanceRecords.map((record) => _buildAttendanceCard(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecordsMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No attendance records found for this date',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewAttendanceRecord,
            icon: const Icon(Icons.add),
            label: const Text('Create New Record'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel record) {
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
                Text('Status: ${record.status.toUpperCase()}', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleRecordAction(value, record),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(
                      children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit Times')],
                    )),
                    const PopupMenuItem(value: 'delete', child: Row(
                      children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTimeInfo('Check-in:', record.checkInTime),
            _buildTimeInfo('Check-out:', record.checkOutTime),
            if (record.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Notes: ${record.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, DateTime? time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(time != null ? DateFormat('HH:mm:ss').format(time) : 'Not recorded'),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _loadAttendanceForDate();
    }
  }

  void _handleRecordAction(String action, AttendanceModel record) {
    if (action == 'edit') {
      _showEditTimeDialog(record);
    } else if (action == 'delete') {
      _showDeleteConfirmDialog(record);
    }
  }

  void _showEditTimeDialog(AttendanceModel record) {
    showDialog(
      context: context,
      builder: (context) => _EditTimeDialog(
        record: record,
        onSave: (checkIn, checkOut, status, notes) => _updateAttendanceRecord(record, checkIn, checkOut, status, notes),
      ),
    );
  }

  void _showDeleteConfirmDialog(AttendanceModel record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance Record'),
        content: const Text('Are you sure you want to delete this attendance record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAttendanceRecord(record);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createNewAttendanceRecord() {
    if (_selectedEmployee == null) return;
    
    showDialog(
      context: context,
      builder: (context) => _EditTimeDialog(
        record: null,
        selectedEmployee: _selectedEmployee!,
        selectedDate: _selectedDate,
        onSave: (checkIn, checkOut, status, notes) => _createAttendanceRecord(checkIn, checkOut, status, notes),
      ),
    );
  }

  Future<void> _updateAttendanceRecord(AttendanceModel record, DateTime? checkIn, DateTime? checkOut, String status, String notes) async {
    try {
      final updateData = <String, dynamic>{'status': status, 'notes': notes};
      if (checkIn != null) updateData['checkInTime'] = Timestamp.fromDate(checkIn);
      if (checkOut != null) updateData['checkOutTime'] = Timestamp.fromDate(checkOut);
      if (checkIn != null && checkOut != null) {
        updateData['totalMinutes'] = checkOut.difference(checkIn).inMinutes;
      }
      
      await FirebaseFirestore.instance.collection('attendance').doc(record.attendanceId).update(updateData);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance updated successfully')));
      _loadAttendanceForDate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _createAttendanceRecord(DateTime? checkIn, DateTime? checkOut, String status, String notes) async {
    if (_selectedEmployee == null) return;
    
    try {
      final attendanceId = FirebaseFirestore.instance.collection('attendance').doc().id;
      final data = {
        'attendanceId': attendanceId,
        'userId': _selectedEmployee!.userId,
        'date': Timestamp.fromDate(_selectedDate),
        'status': status,
        'notes': notes,
        'checkInTime': checkIn != null ? Timestamp.fromDate(checkIn) : null,
        'checkOutTime': checkOut != null ? Timestamp.fromDate(checkOut) : null,
        'totalMinutes': (checkIn != null && checkOut != null) ? checkOut.difference(checkIn).inMinutes : 0,
      };
      
      await FirebaseFirestore.instance.collection('attendance').doc(attendanceId).set(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance record created successfully')));
      _loadAttendanceForDate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create record: $e')));
    }
  }

  Future<void> _deleteAttendanceRecord(AttendanceModel record) async {
    try {
      await FirebaseFirestore.instance.collection('attendance').doc(record.attendanceId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance record deleted')));
      _loadAttendanceForDate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

class _EditTimeDialog extends StatefulWidget {
  final AttendanceModel? record;
  final UserModel? selectedEmployee;
  final DateTime? selectedDate;
  final Function(DateTime?, DateTime?, String, String) onSave;

  const _EditTimeDialog({
    required this.onSave,
    this.record,
    this.selectedEmployee,
    this.selectedDate,
  });

  @override
  State<_EditTimeDialog> createState() => _EditTimeDialogState();
}

class _EditTimeDialogState extends State<_EditTimeDialog> {
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  String _status = 'present';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _checkInTime = widget.record!.checkInTime;
      _checkOutTime = widget.record!.checkOutTime;
      _status = widget.record!.status;
      _notesController.text = widget.record!.notes ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.record != null ? 'Edit Attendance Times' : 'Create Attendance Record'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeSelector('Check-in Time', _checkInTime, (time) => setState(() => _checkInTime = time)),
            const SizedBox(height: 16),
            _buildTimeSelector('Check-out Time', _checkOutTime, (time) => setState(() => _checkOutTime = time)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: ['present', 'late', 'absent'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Admin changes)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_checkInTime, _checkOutTime, _status, _notesController.text);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, DateTime? time, Function(DateTime?) onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: Text(time != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(time) : 'Not set'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _selectDateTime(time, onChanged),
            icon: const Icon(Icons.edit),
          ),
          if (time != null)
            IconButton(
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _selectDateTime(DateTime? currentTime, Function(DateTime?) onChanged) async {
    final date = widget.selectedDate ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime ?? DateTime.now()),
    );
    if (time != null) {
      final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      onChanged(newDateTime);
    }
  }
}
