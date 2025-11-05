import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vidhatasharnam/config/supabase_config.dart';

class CameraService {
  static Future<bool> requestCameraPermission() async {
    var status = await Permission.camera.status;
    
    // If denied, request permission
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    
    return status.isGranted;
  }
  
  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  static Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      return await availableCameras();
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      return [];
    }
  }

  static Future<CameraDescription?> getFrontCamera() async {
    final cameras = await getAvailableCameras();
    debugPrint('📷 Available cameras: ${cameras.length}');
    
    for (int i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      debugPrint('📷 Camera $i: ${camera.name}, direction: ${camera.lensDirection}');
      
      if (camera.lensDirection == CameraLensDirection.front) {
        debugPrint('✅ Found front camera: ${camera.name}');
        return camera;
      }
    }
    
    // If no front camera found, return the first available camera
    if (cameras.isNotEmpty) {
      debugPrint('⚠️ No front camera found, using first available: ${cameras.first.name}');
      return cameras.first;
    }
    
    debugPrint('❌ No cameras available');
    return null;
  }

  static Future<String?> uploadImageToSupabase({
    required Uint8List fileBytes,
    required String userId,
    required String visitId,
    String extension = 'jpg',
  }) async {
    try {
      // Defensive guard: Ensure Supabase is initialized before accessing client
      if (!SupabaseConfig.isInitialized) {
        debugPrint('⚠️ Supabase not initialized, attempting to initialize...');
        try {
          await SupabaseConfig.initialize();
          debugPrint('✅ Supabase initialized successfully');
        } catch (e) {
          debugPrint('❌ Failed to initialize Supabase: $e');
          throw Exception('Supabase not initialized. Cannot upload image. Error: $e');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'visits/${userId}_${visitId}_$timestamp.$extension';

      debugPrint('☁️ Uploading $fileName to ${SupabaseConfig.visitPhotosBucket}');

      // Access client with defensive guard
      final client = SupabaseConfig.client;
      final response = await client.storage
          .from(SupabaseConfig.visitPhotosBucket)
          .uploadBinary(fileName, fileBytes);

      debugPrint('📤 Upload response: $response');

      if (response.isEmpty) throw Exception('Upload failed - empty response');

      final publicUrl = client.storage
          .from(SupabaseConfig.visitPhotosBucket)
          .getPublicUrl(fileName);

      debugPrint('✅ Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }
}

class CameraScreen extends StatefulWidget {
  final Function(String photoUrl) onPhotoTaken;
  final String userId;
  final String visitId;

  const CameraScreen({
    super.key,
    required this.onPhotoTaken,
    required this.userId,
    required this.visitId,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    } else {
      // On web, we don't need camera initialization
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('🚀 Initializing camera...');
      debugPrint('📱 Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}');
      
      // Request camera permission
      final hasPermission = await CameraService.requestCameraPermission();
      debugPrint('🔐 Camera permission granted: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('❌ Camera permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Get front camera
      debugPrint('🔍 Looking for cameras...');
      final frontCamera = await CameraService.getFrontCamera();
      
      if (frontCamera == null) {
        debugPrint('❌ No camera found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No camera available on this device'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      debugPrint('📷 Found camera: ${frontCamera.name}, direction: ${frontCamera.lensDirection}');

      // Initialize camera controller
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _takePicture() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      Uint8List? imageBytes;

      if (kIsWeb) {
        // ✅ WEB: use file picker
        debugPrint('🌐 Using FilePicker for web');
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null && result.files.single.bytes != null) {
          imageBytes = result.files.single.bytes!;
          debugPrint('📊 Selected image bytes: ${imageBytes.length}');
        } else {
          throw Exception('No image selected');
        }
      } else {
        // ✅ ANDROID/iOS: use Camera
        if (_controller == null || !_controller!.value.isInitialized) {
          throw Exception('Camera not initialized');
        }

        debugPrint('📸 Capturing photo...');
        final XFile image = await _controller!.takePicture();
        imageBytes = await image.readAsBytes();
        debugPrint('📊 Captured image bytes: ${imageBytes.length}');
      }

      if (imageBytes.isEmpty) {
        throw Exception('Captured image is empty');
      }

      // Upload
      final photoUrl = await CameraService.uploadImageToSupabase(
        fileBytes: imageBytes,
        userId: widget.userId,
        visitId: widget.visitId,
      );

      if (photoUrl != null && photoUrl.isNotEmpty) {
        if (mounted) {
          widget.onPhotoTaken(photoUrl);
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to upload photo');
      }
    } catch (e) {
      debugPrint('❌ Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(kIsWeb ? 'Select Photo' : 'Take Photo'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview (only on mobile)
                if (!kIsWeb && _controller != null)
                  Positioned.fill(
                    child: CameraPreview(_controller!),
                  ),
                
                // Web file picker UI
                if (kIsWeb)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library, size: 80, color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Tap the button below to select a photo',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                
                // Loading overlay
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Uploading photo...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Camera/Select controls
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Capture/Select button
                      GestureDetector(
                        onTap: _isLoading ? null : _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLoading ? Colors.grey : Colors.white,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  kIsWeb ? Icons.photo_library : Icons.camera_alt,
                                  size: 35,
                                  color: Colors.black,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Instructions
                if (!kIsWeb)
                  Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Position yourself in the frame and tap the camera button to take a photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
