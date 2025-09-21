// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance_model.dart';
import '../providers/incomplete_checkout_provider.dart';
import '../providers/shift_provider.dart';

class IncompleteCheckoutWarning extends StatefulWidget {
  final String userId;
  
  const IncompleteCheckoutWarning({
    super.key,
    required this.userId,
  });

  @override
  State<IncompleteCheckoutWarning> createState() => _IncompleteCheckoutWarningState();
}

class _IncompleteCheckoutWarningState extends State<IncompleteCheckoutWarning> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<IncompleteCheckoutProvider, ShiftProvider>(
      builder: (context, incompleteProvider, shiftProvider, child) {
        // Don't show if dismissed
        if (_isDismissed) {
          return const SizedBox.shrink();
        }
        
        return FutureBuilder<AttendanceModel?>(
          future: incompleteProvider.checkUserIncompleteCheckout(widget.userId),
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
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.orange.withValues(alpha: 0.3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange[50]!,
                        Colors.orange[100]!,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.orange[300]!,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with close button
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Incomplete Checkout',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() {
                                    _isDismissed = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Warning message
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            incompleteProvider.getUserWarningMessage(incompleteCheckout),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Details section
                        _buildCheckoutDetails(incompleteCheckout),
                        
                        const SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showCheckoutHelpDialog(context),
                                icon: Icon(
                                  Icons.help_outline_rounded,
                                  size: 16,
                                  color: Colors.orange[700],
                                ),
                                label: Text(
                                  'Need Help?',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.orange[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _contactAdmin(context),
                                icon: const Icon(Icons.phone_rounded, size: 16),
                                label: const Text(
                                  'Contact Admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checkout Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.access_time_rounded,
            'Check-in Time',
            _formatDateTime(incompleteCheckout.checkInTime!),
            Colors.blue[600]!,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.calendar_today_rounded,
            'Date',
            _formatDate(incompleteCheckout.date),
            Colors.green[600]!,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
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
