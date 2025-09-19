import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_lock_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/system_locked_screen.dart';

/// Widget that monitors system lock status and redirects users when system is locked
class SystemLockGuard extends StatelessWidget {
  final Widget child;
  
  const SystemLockGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<SystemLockProvider, AuthProvider>(
      builder: (context, systemLockProvider, authProvider, _) {
        // If system is locked and user is not super admin, show lock screen
        if (systemLockProvider.isSystemLocked && 
            authProvider.currentUser != null &&
            !authProvider.currentUser!.isSuperAdmin) {
          
          print('🔒 SystemLockGuard: System is locked, redirecting non-super-admin user');
          
          // Use WidgetsBinding to ensure navigation happens after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const SystemLockedScreen()),
              (route) => false, // Remove all previous routes
            );
          });
          
          // Show loading while redirecting
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // System is unlocked or user is super admin, show normal content
        return child;
      },
    );
  }
}
