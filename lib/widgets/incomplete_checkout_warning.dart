// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance_model.dart';
import '../providers/incomplete_checkout_provider.dart';
import '../providers/shift_provider.dart';

class IncompleteCheckoutWarning extends StatelessWidget {
  final String userId;
  
  const IncompleteCheckoutWarning({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<IncompleteCheckoutProvider, ShiftProvider>(
      builder: (context, incompleteProvider, shiftProvider, child) {
        return FutureBuilder<AttendanceModel?>(
          future: incompleteProvider.checkUserIncompleteCheckout(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            
            final incompleteCheckout = snapshot.data;
            if (incompleteCheckout == null) {
              return const SizedBox.shrink();
            }
            
            return Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                color: Colors.orange[50],
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Incomplete Checkout',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        incompleteProvider.getUserWarningMessage(incompleteCheckout),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCheckoutDetails(incompleteCheckout),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showCheckoutHelpDialog(context),
                            child: const Text('Need Help?'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _contactAdmin(context),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Contact Admin'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildCheckoutDetails(AttendanceModel incompleteCheckout) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Check-in Time: ${_formatDateTime(incompleteCheckout.checkInTime!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Date: ${_formatDate(incompleteCheckout.date)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showCheckoutHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Checkout Help'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is an incomplete checkout?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'An incomplete checkout means you checked in for work but forgot to check out when your shift ended.',
            ),
            SizedBox(height: 16),
            Text(
              'What should I do?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '1. Contact your admin or supervisor\n'
              '2. Provide your check-in time and actual departure time\n'
              '3. The admin can manually complete your checkout\n'
              '4. Remember to check out at the end of your next shift',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  void _contactAdmin(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Admin'),
        content: const Text(
          'Please contact your administrator or supervisor to resolve this incomplete checkout. '
          'They can manually complete your checkout with the correct time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
