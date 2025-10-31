import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/data/datasources/camera/camera_service.dart';
import 'package:vidhatasharnam/presentation/visits/visit_view_model.dart';

class NewVisitScreen extends StatelessWidget {
  const NewVisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VisitViewModel>(
      create: (_) => VisitViewModel()
        ..initializeDateTime()
        ..getCurrentLocation().catchError((e) {
          // Show guidance to enable permissions if permanently denied
          if (e is PermissionDeniedException) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
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
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get location. Please check your GPS and permissions.'),
              ),
            );
          }
        }),
      child: const _NewVisitView(),
    );
  }
}

class _NewVisitView extends StatelessWidget {
  const _NewVisitView();

  Future<void> _takePicture(BuildContext context) async {
    final vm = context.read<VisitViewModel>();
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            userId: FirebaseAuth.instance.currentUser!.uid,
            visitId: DateTime.now().millisecondsSinceEpoch.toString(),
            onPhotoTaken: (photoUrl) {
              vm.setPhotoUrl(photoUrl);
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

  Future<void> _submitForm(BuildContext context, GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;
    final vm = context.read<VisitViewModel>();
    try {
      await vm.submitVisit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit visit. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VisitViewModel>();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: vm.photoUrl != null
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
                                  onPressed: vm.clearPhoto,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: () => _takePicture(context),
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
              TextFormField(
                controller: vm.associateNameController,
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
              TextFormField(
                controller: vm.customerNameController,
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
              TextFormField(
                controller: vm.upperlineNameController,
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
              TextFormField(
                controller: vm.teamleaderNameController,
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
              TextFormField(
                controller: vm.reraNumberController,
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
              TextFormField(
                controller: vm.schemeNameController,
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
              TextFormField(
                controller: vm.locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Location (Auto-detected)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  suffixIcon: vm.isLoadingLocation
                      ? Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: vm.getCurrentLocation,
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
              TextFormField(
                controller: vm.dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: vm.timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: vm.isSubmitting ? null : () => _submitForm(context, formKey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: vm.isSubmitting
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
  }
}