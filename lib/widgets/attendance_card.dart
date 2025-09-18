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
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'present':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        break;
      case 'absent':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Time Details
              Row(
                children: [
                  Expanded(
                    child: _TimeDetail(
                      label: 'Check In',
                      time: checkInTime,
                      icon: Icons.login,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: AppColors.lightGrey,
                  ),
                  Expanded(
                    child: _TimeDetail(
                      label: 'Check Out',
                      time: checkOutTime ?? '--:--',
                      icon: Icons.logout,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: AppColors.lightGrey,
                  ),
                  Expanded(
                    child: _TimeDetail(
                      label: 'Total',
                      time: totalHours,
                      icon: Icons.schedule,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeDetail extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;

  const _TimeDetail({
    required this.label,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
