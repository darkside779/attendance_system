// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/loading_widget.dart';

class DebugLocationScreen extends StatefulWidget {
  const DebugLocationScreen({super.key});

  @override
  State<DebugLocationScreen> createState() => _DebugLocationScreenState();
}

class _DebugLocationScreenState extends State<DebugLocationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await settingsProvider.loadSettings();
    if (settingsProvider.companyLocation != null) {
      await locationProvider.initialize(settingsProvider.companyLocation!);
      await locationProvider.getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Debug'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<LocationProvider, SettingsProvider>(
        builder: (context, locationProvider, settingsProvider, child) {
          if (settingsProvider.isLoading || locationProvider.isLoading) {
            return const Center(child: LoadingWidget());
          }

          final companyLocation = settingsProvider.companyLocation;
          final currentPosition = locationProvider.currentPosition;
          final locationCheck = locationProvider.lastLocationCheck;

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    'Permission Status',
                    [
                      _buildInfoRow('Location Permission', _getPermissionText(locationProvider.permissionStatus)),
                      _buildInfoRow('Location Service', locationProvider.isLocationServiceEnabled ? 'Enabled' : 'Disabled'),
                      _buildInfoRow('Can Use Location', locationProvider.canUseLocation ? 'Yes' : 'No'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildCard(
                    'Company Location Settings',
                    companyLocation != null ? [
                      _buildInfoRow('Latitude', companyLocation.latitude.toStringAsFixed(6)),
                      _buildInfoRow('Longitude', companyLocation.longitude.toStringAsFixed(6)),
                      _buildInfoRow('Radius', '${companyLocation.radiusMeters} meters'),
                      _buildInfoRow('Address', companyLocation.address),
                    ] : [
                      const Text('Company location not configured', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildCard(
                    'Current Location',
                    currentPosition != null ? [
                      _buildInfoRow('Latitude', currentPosition.latitude.toStringAsFixed(6)),
                      _buildInfoRow('Longitude', currentPosition.longitude.toStringAsFixed(6)),
                      _buildInfoRow('Accuracy', '${currentPosition.accuracy.toStringAsFixed(1)} meters'),
                      _buildInfoRow('Timestamp', currentPosition.timestamp.toString()),
                      _buildInfoRow('Altitude', '${currentPosition.altitude.toStringAsFixed(1)} meters'),
                      _buildInfoRow('Speed', '${currentPosition.speed.toStringAsFixed(1)} m/s'),
                    ] : [
                      const Text('Current location not available', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildCard(
                    'Location Verification',
                    locationCheck != null ? [
                      _buildInfoRow('Within Range', locationCheck.isWithinRange ? 'YES' : 'NO', 
                          textColor: locationCheck.isWithinRange ? Colors.green : Colors.red),
                      _buildInfoRow('Distance', locationCheck.distance != null ? 
                          '${(locationCheck.distance! / 1000).toStringAsFixed(2)} km' : 'Unknown'),
                      _buildInfoRow('Message', locationCheck.message),
                      if (locationCheck.currentLatitude != null && locationCheck.currentLongitude != null)
                        _buildInfoRow('Detected Coordinates', 
                            '${locationCheck.currentLatitude!.toStringAsFixed(6)}, ${locationCheck.currentLongitude!.toStringAsFixed(6)}'),
                    ] : [
                      const Text('Location verification not performed', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (locationProvider.errorMessage != null)
                    _buildCard(
                      'Errors',
                      [
                        Text(locationProvider.errorMessage!, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Refresh Location'),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                        final permission = await locationProvider.requestLocationPermission();
                        
                        if (mounted) {
                          String message;
                          if (permission.toString().contains('denied')) {
                            message = 'Location permission denied. Please enable location in your browser settings.';
                          } else {
                            message = 'Permission updated. Refreshing location...';
                            await _loadData();
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Request Permission'),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Show instructions for enabling location
                        _showLocationInstructions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('How to Enable Location'),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Manual location override for testing
                        _showManualLocationDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Manual Location (Testing)'),
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

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _getPermissionText(permission) {
    switch (permission.toString()) {
      case 'LocationPermission.always':
        return 'Always';
      case 'LocationPermission.whileInUse':
        return 'While in Use';
      case 'LocationPermission.denied':
        return 'Denied';
      case 'LocationPermission.deniedForever':
        return 'Denied Forever';
      case 'LocationPermission.unableToDetermine':
        return 'Unable to Determine';
      default:
        return permission.toString();
    }
  }

  void _showLocationInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Access'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To use location features, please enable location access:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('📱 Mobile Browsers:'),
              Text('1. Tap the location icon (🌍) in your browser\'s address bar'),
              Text('2. Select "Allow" for location permission'),
              Text('3. If no icon appears, check browser settings > Site permissions'),
              SizedBox(height: 8),
              Text('🖥️ Desktop Browsers:'),
              Text('1. Click the location/lock icon next to the URL'),
              Text('2. Set Location to "Allow"'),
              Text('3. Refresh the page after changing permissions'),
              SizedBox(height: 8),
              Text('⚠️ Important:'),
              Text('• Must use HTTPS (secure connection)'),
              Text('• Location services must be enabled on your device'),
              Text('• Some browsers block location on "installed" web apps'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Got it'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadData(); // Retry after user reads instructions
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    
    // Pre-fill with company location for testing
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (settingsProvider.companyLocation != null) {
      latController.text = settingsProvider.companyLocation!.latitude.toString();
      lngController.text = settingsProvider.companyLocation!.longitude.toString();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Location (Testing)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For testing purposes, manually set your location:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 24.366285',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lngController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., 54.499738',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: This simulates being at the specified coordinates.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              
              if (lat != null && lng != null) {
                Navigator.of(context).pop();
                
                // Simulate location with manual coordinates
                await _simulateLocation(lat, lng);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid coordinates')),
                );
              }
            },
            child: const Text('Set Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateLocation(double lat, double lng) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    try {
      // Calculate distance using simple formula
      final companyLocation = settingsProvider.companyLocation!;
      final distance = _calculateDistance(
        lat, lng, 
        companyLocation.latitude, companyLocation.longitude
      );
      
      final isWithinRange = distance <= companyLocation.radiusMeters;
      final message = isWithinRange 
          ? 'Manual location: Within work area'
          : 'Manual location: ${(distance / 1000).toStringAsFixed(1)} km from work area';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isWithinRange ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error simulating location: $e')),
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
        sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
