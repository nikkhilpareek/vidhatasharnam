import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhatasharnam/data/datasources/camera/camera_service.dart';

import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/presentation/user/user_view_model.dart';
import 'package:vidhatasharnam/presentation/visits/new_visit_view_model.dart';
import 'package:provider/provider.dart';
import 'package:vidhatasharnam/core/exceptions/app_exception.dart';


class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key});

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _associateNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _upperlineNameController = TextEditingController();
  final TextEditingController _teamleaderNameController = TextEditingController();
  final TextEditingController _reraNumberController = TextEditingController();
  final TextEditingController _schemeNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDateTime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewVisitViewModel>().getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _associateNameController.dispose();
    _customerNameController.dispose();
    _upperlineNameController.dispose();
    _teamleaderNameController.dispose();
    _reraNumberController.dispose();
    _schemeNameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _initializeDateTime() {
    final now = DateTime.now();
    _dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _timeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _getCurrentLocation(NewVisitViewModel viewModel) async {
    await viewModel.getCurrentLocation();
    
    // Handle permission dialog if needed
    if (viewModel.errorMessage != null && viewModel.errorMessage!.contains('permanently denied')) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Location permission is required for accurate location detection. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _takePicture(NewVisitViewModel viewModel) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Generate a temporary visit ID for the photo
    final tempVisitId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            userId: currentUser.uid,
            visitId: tempVisitId,
            onPhotoTaken: (photoUrl) {
              viewModel.setPhotoUrl(photoUrl);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo captured successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error opening camera',
        error: e,
        stackTrace: stackTrace,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open camera')),
      );
    }
  }

  Future<void> _submitForm(NewVisitViewModel viewModel, UserViewModel userViewModel) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Service-level check: Verify user is still active before creating visit
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw const UnauthorizedException('Not authenticated. Please log in again.');
      }

      // Check via UserViewModel first (real-time check)
      if (!userViewModel.isActive) {
        AppLogger.warning('[NewVisitScreen] Visit creation blocked: User is inactive');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been disabled by admin. Please contact support.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Prepare datetime from date & time controllers
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(_timeController.text.split(":")[0]),
        int.parse(_timeController.text.split(":")[1]),
      );

      // Save visit to Firestore via ViewModel
      AppLogger.info('[NewVisitScreen] Creating visit for user: $uid');
      final success = await viewModel.submitVisit(
        associateName: _associateNameController.text.trim(),
        customerName: _customerNameController.text.trim(),
        upperlineName: _upperlineNameController.text.trim(),
        teamleaderName: _teamleaderNameController.text.trim(),
        reraNumber: _reraNumberController.text.trim(),
        schemeName: _schemeNameController.text.trim(),
        dateTime: selectedDateTime,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage ?? 'Failed to submit visit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error submitting visit data',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit visit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer2<NewVisitViewModel, UserViewModel>(
      builder: (context, viewModel, userViewModel, _) {
        // Update location controller when ViewModel location changes
        if (viewModel.location.isNotEmpty && _locationController.text != viewModel.location) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (viewModel.location.isNotEmpty) {
              _locationController.text = viewModel.location;
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('New Visit'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Camera preview or photo
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: viewModel.photoUrl != null
                      ? Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, size: 50, color: Colors.green),
                                    SizedBox(height: 8),
                                    Text(
                                      'Photo captured successfully',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  radius: 15,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 15, color: Colors.white),
                                    onPressed: () {
                                      viewModel.clearPhotoUrl();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : InkWell(
                          onTap: () => _takePicture(viewModel),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to take photo', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              
              // Associate Name
              TextFormField(
                controller: _associateNameController,
                decoration: const InputDecoration(
                  labelText: 'Associate Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter associate name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Customer Name
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Upperline Name
              TextFormField(
                controller: _upperlineNameController,
                decoration: const InputDecoration(
                  labelText: 'Upperline Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter upperline name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Teamleader Name
              TextFormField(
                controller: _teamleaderNameController,
                decoration: const InputDecoration(
                  labelText: 'Teamleader Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter teamleader name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // RERA Number
              TextFormField(
                controller: _reraNumberController,
                decoration: const InputDecoration(
                  labelText: 'RERA Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter RERA number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Scheme Name
              TextFormField(
                controller: _schemeNameController,
                decoration: const InputDecoration(
                  labelText: 'Scheme Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter scheme name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
                  // Location (Auto-detected)
                  TextFormField(
                    controller: _locationController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Location (Auto-detected)',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      suffixIcon: viewModel.isLoadingLocation 
                        ? Container(
                            width: 20,
                            height: 20,
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: () => _getCurrentLocation(viewModel),
                            tooltip: 'Refresh location',
                          ),
                      helperText: 'Location is automatically detected from your current position',
                      helperMaxLines: 2,
                    ),
                    maxLines: 2,
                    minLines: 1,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.contains('Automatically detecting') || value == 'Detecting precise location...') {
                        return 'Please wait for automatic location detection to complete';
                      }
                      return null;
                    },
                  ),
              const SizedBox(height: 16),
              
              // Date
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              
              // Time
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 24),
              
                  // Submit Button
                  ElevatedButton(
                    onPressed: viewModel.isSubmitting ? null : () => _submitForm(viewModel, userViewModel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: viewModel.isSubmitting 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Submitting...'),
                            ],
                          )
                        : const Text('Submit Visit'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}