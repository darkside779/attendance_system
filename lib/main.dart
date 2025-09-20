// ignore_for_file: use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_colors.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/system_lock_provider.dart';
import 'providers/incomplete_checkout_provider.dart';
import 'screens/employee/home_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/super_admin/super_admin_home_screen.dart';
import 'screens/system_locked_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => AdminAttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => SystemLockProvider()),
        ChangeNotifierProvider(create: (_) => IncompleteCheckoutProvider()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize providers and check authentication status
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final systemLockProvider =
          Provider.of<SystemLockProvider>(context, listen: false);

      // Check if user is already logged in
      await authProvider.checkAuthenticationState();

      // Initialize and check system lock status
      systemLockProvider.initialize();
      await systemLockProvider.checkSystemLockStatus();

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        // Check if system is locked (Super Admin can still access)
        if (systemLockProvider.isSystemLocked &&
            !authProvider.currentUser!.isSuperAdmin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SystemLockedScreen()),
          );
          return;
        }

        // Navigate based on user role
        final user = authProvider.currentUser!;
        print(
            '🔍 User navigation - Role: ${user.role}, isSuperAdmin: ${user.isSuperAdmin}, isAdmin: ${user.isAdmin}');

        if (user.isSuperAdmin) {
          print('🚀 Navigating to SuperAdminHomeScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) => const SuperAdminHomeScreen()),
          );
        } else if (user.isAdmin) {
          print('🚀 Navigating to AdminDashboard');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        } else {
          print('🚀 Navigating to EmployeeHomeScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const EmployeeHomeScreen()),
          );
        }
      } else {
        // Navigate to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 80,
              color: AppColors.white,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
