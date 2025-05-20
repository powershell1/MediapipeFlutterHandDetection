import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math_64.dart';
import '../utils/hand_identifier.dart';
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

  Future<Map<Handedness, Hand>> detectHandLandmarksFromImage(CameraImage image) async {
    Map<Handedness, Hand> detectedHand = {};
    List<dynamic> handLandmarks =
        await detectHandLandmarks(image);
    if (handLandmarks.isNotEmpty) {
      for (var hand in handLandmarks) {
        int index = 0;
        Map<HandLandmarks, HandKeyPoint> detectedKeyPoints = {};
        hand['landmarks'].forEach((position) {
          final x = 1 - (position['y'] as double);
          final y = 1 - (position['x'] as double);
          final z = position['z'] as double;
          final landmark = HandLandmarks.values[index];
          // final index = position['index'] as int;
          detectedKeyPoints[landmark] = HandKeyPoint(
            position: Vector3(x, y, z),
            landmark: landmark,
          );
          index++;
        });
        Handedness handedness =
        Handedness.values[hand['handedness'] == 'Left' ? 0 : 1];
        Hand handConstructed = Hand(
          handedness: handedness,
          keyPoints: detectedKeyPoints,
        );
        detectedHand[handedness] = handConstructed;
      }
    }
    return detectedHand;
  }
}