// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../widgets/custom_button.dart';

class AttendanceCard extends StatelessWidget {
  final String title;
  final String status;
  final String workingHours;
  final bool canCheckIn;
  final bool canCheckOut;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;

  const AttendanceCard({
    super.key,
    required this.title,
    required this.status,
    required this.workingHours,
    this.canCheckIn = false,
    this.canCheckOut = false,
    this.onCheckIn,
    this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Icon(
                Icons.access_time,
                color: AppColors.white.withOpacity(0.8),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status
          Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Working Hours
          Text(
            'Working Hours',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            workingHours,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              if (canCheckIn)
                Expanded(
                  child: CustomButton(
                    text: 'Check In',
                    onPressed: onCheckIn,
                    backgroundColor: AppColors.white,
                    textColor: AppColors.primary,
                    height: 40,
                    icon: Icons.login,
                  ),
                ),
              if (canCheckIn && canCheckOut)
                const SizedBox(width: 12),
              if (canCheckOut)
                Expanded(
                  child: CustomButton(
                    text: 'Check Out',
                    onPressed: onCheckOut,
                    backgroundColor: AppColors.white.withOpacity(0.2),
                    textColor: AppColors.white,
                    height: 40,
                    icon: Icons.logout,
                  ),
                ),
              if (!canCheckIn && !canCheckOut)
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'All done for today!',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AttendanceStatusCard extends StatelessWidget {
  final String date;
  final String checkInTime;
  final String? checkOutTime;
  final String totalHours;
  final String status;
  final VoidCallback? onTap;

  const AttendanceStatusCard({
    super.key,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    required this.totalHours,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBackgroundColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'present':
        statusColor = const Color(0xFF22C55E);
        statusBackgroundColor = const Color(0xFF22C55E).withOpacity(0.1);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'late':
        statusColor = const Color(0xFFF59E0B);
        statusBackgroundColor = const Color(0xFFF59E0B).withOpacity(0.1);
        statusIcon = Icons.access_time_rounded;
        break;
      case 'absent':
        statusColor = const Color(0xFFEF4444);
        statusBackgroundColor = const Color(0xFFEF4444).withOpacity(0.1);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusBackgroundColor = const Color(0xFF6B7280).withOpacity(0.1);
        statusIcon = Icons.help_outline_rounded;
    }

    final bool isComplete = checkOutTime != null && checkOutTime != '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header Row with Date and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toLowerCase() == 'present' ? 'Present' : status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Time Details Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Check In
                      Expanded(
                        child: _ModernTimeDetail(
                          label: 'Check In',
                          time: checkInTime,
                          icon: Icons.login_rounded,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      
                      // Divider
                      Container(
                        height: 50,
                        width: 1,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      
                      // Check Out
                      Expanded(
                        child: _ModernTimeDetail(
                          label: 'Check Out',
                          time: checkOutTime ?? '--:--',
                          icon: Icons.logout_rounded,
                          color: isComplete ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                        ),
                      ),
                      
                      // Divider
                      Container(
                        height: 50,
                        width: 1,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      
                      // Total Hours
                      Expanded(
                        child: _ModernTimeDetail(
                          label: 'Total',
                          time: totalHours,
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernTimeDetail extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _ModernTimeDetail({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
