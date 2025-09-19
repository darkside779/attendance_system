// ignore_for_file: use_build_context_synchronously

import 'package:attendance_system/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';
import '../../models/shift_model.dart';
import 'employee_history_screen.dart';
import '../../models/attendance_model.dart';
import '../../widgets/loading_widget.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadEmployees() {
    final provider = Provider.of<AdminAttendanceProvider>(context, listen: false);
    provider.loadEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            onPressed: () => _showAddEmployeeDialog(),
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: Consumer2<AdminAttendanceProvider, ShiftProvider>(
        builder: (context, provider, shiftProvider, child) {
          if (provider.isLoading) {
            return const LoadingWidget();
          }

          return Column(
            children: [
              _buildFiltersAndSearch(),
              Expanded(
                child: _buildEmployeeList(provider, shiftProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                _buildFilterChip('present', 'Present'),
                _buildFilterChip('late', 'Late'),
                _buildFilterChip('absent', 'Absent'),
                _buildFilterChip('checked_in', 'Checked In'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmployeeList(AdminAttendanceProvider provider, ShiftProvider shiftProvider) {
    final filteredEmployees = _getFilteredEmployees(provider, shiftProvider);

    if (filteredEmployees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No employees found',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEmployees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final employee = filteredEmployees[index];
        final attendance = provider.todayAttendance.where((a) => a.userId == employee.userId).firstOrNull;
        
        return _buildEmployeeCard(employee, attendance, provider, shiftProvider);
      },
    );
  }

  // Helper method to get employee's assigned shift
  ShiftModel? _getEmployeeShift(UserModel employee, ShiftProvider shiftProvider) {
    if (employee.assignedShiftId == null) return null;
    return shiftProvider.shifts.firstWhere(
      (shift) => shift.shiftId == employee.assignedShiftId,
      orElse: () => ShiftModel(
        shiftId: '',
        shiftName: '',
        startTime: '',
        endTime: '',
        workingDays: [],
        gracePeriodMinutes: 0,
        isActive: false,
      ),
    );
  }

  // Helper method to calculate shift-based status
  ({String status, String? lateInfo}) _calculateShiftBasedStatus(
    UserModel employee, 
    AttendanceModel? attendance, 
    ShiftProvider shiftProvider
  ) {
    if (attendance == null || attendance.checkInTime == null) {
      return (status: 'absent', lateInfo: null);
    }

    final employeeShift = _getEmployeeShift(employee, shiftProvider);
    if (employeeShift == null || employeeShift.shiftId.isEmpty) {
      // No shift assigned, use default logic
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

  List<UserModel> _getFilteredEmployees(AdminAttendanceProvider provider, ShiftProvider shiftProvider) {
    // Filter out admin users - only show employees
    List<UserModel> employees = provider.employees
        .where((employee) => employee.role.toLowerCase() == 'employee')
        .toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      employees = employees.where((employee) {
        return employee.name.toLowerCase().contains(_searchQuery) ||
               employee.email.toLowerCase().contains(_searchQuery) ||
               employee.position.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply status filter based on shift-based attendance calculation
    switch (_selectedFilter) {
      case 'present':
        employees = employees.where((employee) {
          final attendance = provider.todayAttendance.where((a) => a.userId == employee.userId).firstOrNull;
          final shiftBasedStatus = _calculateShiftBasedStatus(employee, attendance, shiftProvider);
          return shiftBasedStatus.status.toLowerCase() == 'present';
        }).toList();
        break;
      case 'late':
        employees = employees.where((employee) {
          final attendance = provider.todayAttendance.where((a) => a.userId == employee.userId).firstOrNull;
          final shiftBasedStatus = _calculateShiftBasedStatus(employee, attendance, shiftProvider);
          return shiftBasedStatus.status.toLowerCase() == 'late';
        }).toList();
        break;
      case 'absent':
        employees = employees.where((employee) {
          final attendance = provider.todayAttendance.where((a) => a.userId == employee.userId).firstOrNull;
          final shiftBasedStatus = _calculateShiftBasedStatus(employee, attendance, shiftProvider);
          return shiftBasedStatus.status.toLowerCase() == 'absent';
        }).toList();
        break;
      case 'checked_in':
        employees = employees.where((employee) {
          final attendance = provider.todayAttendance.where((a) => a.userId == employee.userId).firstOrNull;
          return attendance != null && attendance.checkInTime != null && attendance.checkOutTime == null;
        }).toList();
        break;
    }

    return employees;
  }


  Widget _buildEmployeeCard(UserModel employee, AttendanceModel? attendance, AdminAttendanceProvider provider, ShiftProvider shiftProvider) {
    // Calculate shift-based status
    final shiftBasedStatus = _calculateShiftBasedStatus(employee, attendance, shiftProvider);
    final statusColor = _getStatusColor(shiftBasedStatus.status);
    final employeeShift = _getEmployeeShift(employee, shiftProvider);
    
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(employee.position),
            const SizedBox(height: 4),
            Text(
              employee.email,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        shiftBasedStatus.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (shiftBasedStatus.lateInfo != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shiftBasedStatus.lateInfo!,
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (attendance?.hasCheckedIn == true) ...[
                      Text(
                        'In: ${_formatTime(attendance!.checkInTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (attendance?.hasCheckedOut == true) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Out: ${_formatTime(attendance!.checkOutTime!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (employeeShift != null && employeeShift.shiftId.isNotEmpty) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          employeeShift.shiftName,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleEmployeeAction(action, employee, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'history',
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('View History'),
                ],
              ),
            ),
            if (shiftBasedStatus.status.toLowerCase() != 'absent')
              const PopupMenuItem(
                value: 'mark_absent',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Mark Absent'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'assign_shift',
              child: Row(
                children: [
                  Icon(Icons.schedule),
                  SizedBox(width: 8),
                  Text('Assign Shift'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Employee'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.success;
      case 'late':
        return AppColors.warning;
      case 'absent':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _handleEmployeeAction(String action, UserModel employee, AdminAttendanceProvider provider) {
    switch (action) {
      case 'details':
        _showEmployeeDetails(employee);
        break;
      case 'history':
        _showEmployeeHistory(employee);
        break;
      case 'mark_absent':
        _confirmMarkAbsent(employee, provider);
        break;
      case 'assign_shift':
        _showShiftAssignmentDialog(employee, provider);
        break;
      case 'edit':
        _showEditEmployeeDialog(employee);
        break;
    }
  }

  void _showEmployeeDetails(UserModel employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${employee.name} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', employee.name),
            _buildDetailRow('Email', employee.email),
            _buildDetailRow('Position', employee.position),
            _buildDetailRow('Role', employee.role.toUpperCase()),
            _buildDetailRow('Status', employee.isActive ? 'Active' : 'Inactive'),
            _buildDetailRow('Created', employee.createdAt.toString().split('.')[0]),
            if (employee.assignedShiftId != null)
              _buildDetailRow('Assigned Shift', _getShiftName(employee.assignedShiftId!)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEmployeeHistory(UserModel employee) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmployeeHistoryScreen(employee: employee),
      ),
    );
  }

  void _confirmMarkAbsent(UserModel employee, AdminAttendanceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Employee Absent'),
        content: Text('Are you sure you want to mark ${employee.name} as absent for today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.markUserAbsent(employee.userId, DateTime.now());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                        ? '${employee.name} marked as absent'
                        : 'Failed to mark employee absent'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Mark Absent'),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddEmployeeDialog(),
    );
  }

  void _showShiftAssignmentDialog(UserModel employee, AdminAttendanceProvider provider) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Assign Shift to ${employee.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Shift: ${employee.assignedShiftId != null ? _getShiftName(employee.assignedShiftId!) : "No shift assigned"}'),
                const SizedBox(height: 16),
                const Text('Available Shifts:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (settingsProvider.currentSettings?.shifts.isNotEmpty == true) ...[
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: settingsProvider.currentSettings!.shifts.length,
                      itemBuilder: (context, index) {
                        final shift = settingsProvider.currentSettings!.shifts[index];
                        final isAssigned = employee.assignedShiftId == shift.shiftId;
                        
                        return Card(
                          child: ListTile(
                            title: Text(shift.shiftName),
                            subtitle: Text('${shift.startTime} - ${shift.endTime}\nDays: ${shift.workingDays.join(", ")}'),
                            isThreeLine: true,
                            trailing: isAssigned 
                                ? const Icon(Icons.check_circle, color: AppColors.success)
                                : ElevatedButton(
                                    onPressed: () => _assignShiftToEmployee(employee, shift.shiftId, provider),
                                    child: const Text('Assign'),
                                  ),
                            leading: shift.isActive 
                                ? const Icon(Icons.schedule, color: AppColors.primary)
                                : const Icon(Icons.schedule_outlined, color: AppColors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  if (employee.assignedShiftId != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _removeShiftFromEmployee(employee, provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Remove Current Shift'),
                    ),
                  ],
                ] else ...[
                  const Text('No shifts available. Please create shifts in Settings.'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignShiftToEmployee(UserModel employee, String shiftId, AdminAttendanceProvider provider) async {
    try {
      final updatedEmployee = employee.copyWith(assignedShiftId: shiftId);
      final success = await provider.updateEmployee(updatedEmployee);
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift assigned to ${employee.name} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        provider.loadEmployees(); // Refresh the employee list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to assign shift. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning shift: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeShiftFromEmployee(UserModel employee, AdminAttendanceProvider provider) async {
    try {
      final updatedEmployee = employee.copyWith(assignedShiftId: null);
      final success = await provider.updateEmployee(updatedEmployee);
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift removed from ${employee.name} successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        provider.loadEmployees(); // Refresh the employee list
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove shift. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing shift: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getShiftName(String shiftId) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final shift = settingsProvider.getShiftById(shiftId);
    return shift?.shiftName ?? 'Unknown Shift';
  }

  void _showEditEmployeeDialog(UserModel employee) {
    // Implement edit employee functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit employee functionality coming soon')),
    );
  }
}

class _AddEmployeeDialog extends StatefulWidget {
  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _positionController = TextEditingController();
  String _selectedRole = 'employee';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Employee'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: 'Position/Job Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee position';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Employee'),
        ),
      ],
    );
  }

  Future<void> _addEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AdminAttendanceProvider>(context, listen: false);
      
      // Generate unique user ID
      final userId = 'emp_${DateTime.now().millisecondsSinceEpoch}';
      
      final newEmployee = UserModel(
        userId: userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        position: _positionController.text.trim(),
        role: _selectedRole,
        createdAt: DateTime.now(),
      );

      final success = await provider.addEmployee(newEmployee);
      
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Employee ${newEmployee.name} added successfully!'
                : 'Failed to add employee. Please try again.'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding employee: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _EditEmployeeDialog extends StatefulWidget {
  final UserModel employee;
  
  const _EditEmployeeDialog({required this.employee});

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _positionController;
  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email);
    _positionController = TextEditingController(text: widget.employee.position);
    _selectedRole = widget.employee.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.employee.name}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(
                  labelText: 'Position/Job Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter employee position';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _confirmDelete(),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AdminAttendanceProvider>(context, listen: false);
      
      final updatedEmployee = widget.employee.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        position: _positionController.text.trim(),
        role: _selectedRole,
      );

      final success = await provider.updateEmployee(updatedEmployee);
      
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Employee updated successfully!'
                : 'Failed to update employee. Please try again.'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating employee: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${widget.employee.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              Navigator.pop(context); // Close edit dialog
              
              final provider = Provider.of<AdminAttendanceProvider>(context, listen: false);
              final success = await provider.deleteEmployee(widget.employee.userId);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                        ? '${widget.employee.name} deleted successfully'
                        : 'Failed to delete employee'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
