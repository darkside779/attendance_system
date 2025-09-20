// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../providers/incomplete_checkout_provider.dart';
import '../../providers/shift_provider.dart';

class IncompleteCheckoutManagementScreen extends StatefulWidget {
  const IncompleteCheckoutManagementScreen({super.key});

  @override
  State<IncompleteCheckoutManagementScreen> createState() => _IncompleteCheckoutManagementScreenState();
}

class _IncompleteCheckoutManagementScreenState extends State<IncompleteCheckoutManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await context.read<IncompleteCheckoutProvider>().loadIncompleteCheckouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incomplete Checkouts'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<IncompleteCheckoutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(provider.errorMessage!);
          }

          if (!provider.hasIncompleteCheckouts) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildSummaryCard(provider),
              Expanded(
                child: _buildIncompleteCheckoutsList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(IncompleteCheckoutProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Attention Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider.getAdminNotificationMessage(),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(
                    'Total Incomplete',
                    provider.incompleteCheckoutsCount.toString(),
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    'Users Affected',
                    provider.usersWithIncompleteCheckouts.length.toString(),
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncompleteCheckoutsList(IncompleteCheckoutProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.incompleteCheckouts.length,
      itemBuilder: (context, index) {
        final checkout = provider.incompleteCheckouts[index];
        final user = provider.usersWithIncompleteCheckouts
            .firstWhere((u) => u.userId == checkout.userId);
        return _buildIncompleteCheckoutCard(checkout, user, provider);
      },
    );
  }

  Widget _buildIncompleteCheckoutCard(
    AttendanceModel checkout,
    UserModel user,
    IncompleteCheckoutProvider provider,
  ) {
    final daysDifference = DateTime.now().difference(checkout.checkInTime!).inDays;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.position,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getDaysColor(daysDifference).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getDaysColor(daysDifference).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    daysDifference == 1 ? '1 day ago' : '$daysDifference days ago',
                    style: TextStyle(
                      color: _getDaysColor(daysDifference),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(checkout.date)),
                  const SizedBox(height: 4),
                  _buildDetailRow('Check-in Time', DateFormat('HH:mm').format(checkout.checkInTime!)),
                  const SizedBox(height: 4),
                  _buildDetailRow('Status', 'Not Checked Out', isError: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAutoCompleteDialog(checkout, provider),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Auto Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showManualCompleteDialog(checkout, provider),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Manual Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
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

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isError ? Colors.red[600] : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getDaysColor(int days) {
    if (days >= 3) return Colors.red;
    if (days >= 2) return Colors.orange;
    return Colors.amber;
  }

  void _showAutoCompleteDialog(AttendanceModel checkout, IncompleteCheckoutProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Consumer<ShiftProvider>(
        builder: (context, shiftProvider, child) {
          // Find appropriate shift for this user
          final shift = shiftProvider.shifts.isNotEmpty ? shiftProvider.shifts.first : null;
          
          if (shift == null) {
            return AlertDialog(
              title: const Text('No Shift Found'),
              content: const Text('Cannot auto-complete without shift information.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          final suggestedTime = provider.getSuggestedCheckoutTime(checkout, shift);

          return AlertDialog(
            title: const Text('Auto Complete Checkout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will automatically complete the checkout with:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Checkout Time: ${DateFormat('HH:mm').format(suggestedTime)}'),
                      Text('Reason: Auto-completed by admin'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Note: This uses the shift end time as checkout time.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Store the parent context before closing dialog
                  final parentContext = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final success = await provider.autoCompleteCheckout(
                    attendance: checkout,
                    shift: shift,
                    reason: 'Auto-completed by admin',
                  );
                  
                  // Use parent context and check if it's still mounted
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(success 
                            ? 'Checkout completed successfully!' 
                            : 'Failed to complete checkout'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Complete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManualCompleteDialog(AttendanceModel checkout, IncompleteCheckoutProvider provider) {
    DateTime selectedDate = checkout.date;
    TimeOfDay selectedTime = const TimeOfDay(hour: 17, minute: 0);
    final reasonController = TextEditingController(text: 'Manually completed by admin');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manual Complete Checkout'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter the actual checkout time:'),
                const SizedBox(height: 16),
                
                // Date Picker
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: checkout.date,
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                
                // Time Picker
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Reason TextField
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final checkoutDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                // Store the parent context before closing dialog
                final parentContext = Navigator.of(context).context;
                Navigator.of(context).pop();
                
                final success = await provider.manualCompleteCheckout(
                  attendance: checkout,
                  checkoutTime: checkoutDateTime,
                  reason: reasonController.text,
                );
                
                // Use parent context and check if it's still mounted
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(success 
                          ? 'Checkout completed successfully!' 
                          : 'Failed to complete checkout'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
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
            style: TextStyle(color: Colors.red[600]),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
          const SizedBox(height: 16),
          Text(
            'All Good!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No incomplete checkouts found.\nAll employees have completed their attendance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
