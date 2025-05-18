import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../utils/image_converter.dart';

class HandLandmarkerService {
  static const MethodChannel _channel = MethodChannel('com.powershell1.movemind/handlandmarker');
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _channel.invokeMethod('initializeHandLandmarker');
        _isInitialized = true;
      } catch (e) {
        print('Failed to initialize hand landmarker: $e');
        rethrow;
      }
    }
  }

  void testMessge(String message) {
    _channel.invokeMethod('testMessage', {'message': message});
  }

  Future<List<dynamic>> detectHandLandmarks(CameraImage image) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Convert CameraImage to RGB format
      final imageBytes = ImageConverter.convertCameraImageToUint8List(image);
      final result = await _channel.invokeMethod('detectHandLandmarks', {
        'imageBytes': imageBytes,
        'width': image.width,
        'height': image.height,
      });

      return jsonDecode(result);
    } catch (e) {
      print('Hand landmark detection failed: $e');
      return [];
    }
  }
}