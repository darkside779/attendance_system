// ignore_for_file: deprecated_member_use, unused_import, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/settings_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _radiusController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final settings = settingsProvider.currentSettings;
    
    if (settings != null) {
      _companyNameController.text = settings.companyName;
      _addressController.text = settings.allowedLocation.address;
      _radiusController.text = settings.allowedLocation.radiusMeters.toString();
      _latitudeController.text = settings.allowedLocation.latitude.toString();
      _longitudeController.text = settings.allowedLocation.longitude.toString();
    } else {
      // Set default values
      _companyNameController.text = 'My Company';
      _radiusController.text = '100';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return const LoadingWidget();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompanyInfoSection(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildShiftsSection(settingsProvider),
                  const SizedBox(height: 32),
                  _buildSaveButton(settingsProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter company name';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Work Location Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isLoadingLocation ? 'Getting...' : 'Use Current Location'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Address
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Work Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter work address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Coordinates
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Invalid number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Radius
          TextFormField(
            controller: _radiusController,
            decoration: const InputDecoration(
              labelText: 'Geofence Radius (meters)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.radio_button_unchecked),
              suffixText: 'm',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter radius';
              }
              final radius = double.tryParse(value);
              if (radius == null || radius <= 0) {
                return 'Please enter a valid radius';
              }
              if (radius < 10) {
                return 'Radius must be at least 10 meters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Help text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Employees must be within this radius of the work location to check in/out. Recommended: 50-200 meters.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(SettingsProvider settingsProvider) {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: 'Save Settings',
        onPressed: settingsProvider.isLoading ? null : () => _saveSettings(settingsProvider),
        isLoading: settingsProvider.isLoading,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final hasPermission = await locationProvider.requestLocationPermission();
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to get current location'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final success = await locationProvider.getCurrentLocation();
      if (success && locationProvider.currentPosition != null) {
        final position = locationProvider.currentPosition!;
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        
        // Try to get address
        final address = await locationProvider.getCurrentAddress();
        if (address != null) {
          _addressController.text = address;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current location set successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get current location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _saveSettings(SettingsProvider settingsProvider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final location = LocationModel(
        latitude: double.parse(_latitudeController.text),
        longitude: double.parse(_longitudeController.text),
        radiusMeters: double.parse(_radiusController.text),
        address: _addressController.text.trim(),
      );

      final settings = SettingsModel(
        companyId: 'default', // Using default for now
        companyName: _companyNameController.text.trim(),
        allowedLocation: location,
        shifts: [], // Will be added later
        updatedAt: DateTime.now(),
      );

      final success = await settingsProvider.saveSettings(settings);
      
      if (success && mounted) {
        // Update location provider with new settings
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        await locationProvider.initialize(location);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildShiftsSection(SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Work Shifts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddShiftDialog(settingsProvider),
                icon: const Icon(Icons.add),
                label: const Text('Add Shift'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Display existing shifts
          if (settingsProvider.currentSettings?.shifts.isNotEmpty == true) ...
            settingsProvider.currentSettings!.shifts.map((shift) => 
              _buildShiftCard(shift, settingsProvider)
            ),
          
          if (settingsProvider.currentSettings?.shifts.isEmpty != false)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'No shifts configured. Add a shift to get started.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(ShiftModel shift, SettingsProvider settingsProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shift.shiftName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showEditShiftDialog(shift, settingsProvider),
                    icon: const Icon(Icons.edit, size: 20),
                  ),
                  IconButton(
                    onPressed: () => _deleteShift(shift, settingsProvider),
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Time: ${shift.startTime} - ${shift.endTime}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Days: ${shift.workingDays.join(", ")}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Grace Period: ${shift.gracePeriodMinutes} minutes',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (!shift.isActive)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'INACTIVE',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddShiftDialog(SettingsProvider settingsProvider) {
    _showShiftDialog(null, settingsProvider);
  }

  void _showEditShiftDialog(ShiftModel shift, SettingsProvider settingsProvider) {
    _showShiftDialog(shift, settingsProvider);
  }

  void _showShiftDialog(ShiftModel? existingShift, SettingsProvider settingsProvider) {
    final nameController = TextEditingController(text: existingShift?.shiftName ?? '');
    final startTimeController = TextEditingController(text: existingShift?.startTime ?? '09:00');
    final endTimeController = TextEditingController(text: existingShift?.endTime ?? '17:00');
    final gracePeriodController = TextEditingController(text: (existingShift?.gracePeriodMinutes ?? 15).toString());
    
    List<String> selectedDays = existingShift?.workingDays.toList() ?? ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    bool isActive = existingShift?.isActive ?? true;
    
    final weekDays = [
      {'key': 'monday', 'label': 'Monday'},
      {'key': 'tuesday', 'label': 'Tuesday'},
      {'key': 'wednesday', 'label': 'Wednesday'},
      {'key': 'thursday', 'label': 'Thursday'},
      {'key': 'friday', 'label': 'Friday'},
      {'key': 'saturday', 'label': 'Saturday'},
      {'key': 'sunday', 'label': 'Sunday'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingShift != null ? 'Edit Shift' : 'Add New Shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Shift Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: startTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Start Time (HH:MM)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: endTimeController,
                        decoration: const InputDecoration(
                          labelText: 'End Time (HH:MM)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: gracePeriodController,
                  decoration: const InputDecoration(
                    labelText: 'Grace Period (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Working Days:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...weekDays.map((day) => CheckboxListTile(
                  title: Text(day['label']!),
                  value: selectedDays.contains(day['key']),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedDays.add(day['key']!);
                      } else {
                        selectedDays.remove(day['key']);
                      }
                    });
                  },
                )),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter shift name')),
                  );
                  return;
                }

                final shift = ShiftModel(
                  shiftId: existingShift?.shiftId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  shiftName: nameController.text.trim(),
                  startTime: startTimeController.text.trim(),
                  endTime: endTimeController.text.trim(),
                  workingDays: selectedDays,
                  gracePeriodMinutes: int.tryParse(gracePeriodController.text) ?? 15,
                  isActive: isActive,
                );

                final success = await settingsProvider.updateShift(shift);
                if (success && mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existingShift != null ? 'Shift updated successfully!' : 'Shift added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(existingShift != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteShift(ShiftModel shift, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to delete "${shift.shiftName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await settingsProvider.removeShift(shift.shiftId);
              if (success && mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shift deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
