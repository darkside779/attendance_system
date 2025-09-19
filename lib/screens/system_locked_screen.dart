import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/system_lock_provider.dart';
import '../providers/auth_provider.dart';
import '../services/system_lock_service.dart';

class SystemLockedScreen extends StatefulWidget {
  const SystemLockedScreen({super.key});

  @override
  State<SystemLockedScreen> createState() => _SystemLockedScreenState();
}

class _SystemLockedScreenState extends State<SystemLockedScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for system unlock
    Provider.of<SystemLockProvider>(context, listen: false).initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.error,
      body: Consumer2<SystemLockProvider, AuthProvider>(
        builder: (context, systemLockProvider, authProvider, child) {
          // If system is unlocked, navigate back
          if (!systemLockProvider.isSystemLocked) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/');
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 60,
                      color: AppColors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  const Text(
                    'System Locked',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Main message
                  const Text(
                    'The attendance system is currently locked by the super administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Lock information
                  if (systemLockProvider.lockInfo != null)
                    _buildLockInfoCard(systemLockProvider.lockInfo!),
                  
                  const SizedBox(height: 32),
                  
                  // Status message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please wait for the system to be unlocked',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Contact your administrator if this persists',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: AppColors.white),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: AppColors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockInfoCard(SystemLockInfo lockInfo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (lockInfo.lockReason != null && lockInfo.lockReason!.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.info, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Reason:',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lockInfo.lockReason!,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          if (lockInfo.lockedAt != null) ...[
            Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Locked at: ${_formatDateTime(lockInfo.lockedAt!)}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
