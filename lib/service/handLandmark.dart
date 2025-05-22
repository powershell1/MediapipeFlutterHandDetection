import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math_64.dart';
import '../utils/imageConverter.dart';

enum Handedness {
  left,
  right,
}

enum HandLandmarks {
  wrist,
  thumbCmc,
  thumbMcp,
  thumbIp,
  thumbTip,
  indexFingerMcp,
  indexFingerPip,
  indexFingerDip,
  indexFingerTip,
  middleFingerMcp,
  middleFingerPip,
  middleFingerDip,
  middleFingerTip,
  ringFingerMcp,
  ringFingerPip,
  ringFingerDip,
  ringFingerTip,
  pinkyMcp,
  pinkyPip,
  pinkyDip,
  pinkyTip
}

class HandKeyPoint {
  final Vector3 position;
  final HandLandmarks landmark;
  HandKeyPoint({required this.position, required this.landmark});
}

class Hand {
  final Handedness handedness;
  final Map<HandLandmarks, HandKeyPoint> keyPoints;
  Hand({required this.handedness, required this.keyPoints});

  @override
  String toString() => 'Hand { handedness: $handedness, keyPoints: $keyPoints }';
}

class HandLandmarkerService {
  static const MethodChannel _channel = MethodChannel('com.powershell1.movemind/handlandmarker');
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_initialized) {
      try {
        await _channel.invokeMethod('initializeHandLandmarker');
        _initialized = true;
      } catch (e) {
        print('Initialization failed: $e');
        rethrow;
      }
    }
  }

  void sendTestMessage(String message) {
    _channel.invokeMethod('testMessage', {'message': message});
  }

  Future<List<dynamic>> retrieveLandmarks(CameraImage image) async {
    if (!_initialized) await initialize();
    try {
      final imageBytes = ImageConverter.convertCameraImageToUint8List(image);
      final result = await _channel.invokeMethod('detectHandLandmarks', {
        'imageBytes': imageBytes,
        'width': image.width,
        'height': image.height,
      });
      return jsonDecode(result);
    } catch (e) {
      print('Detection failed: $e');
      return [];
    }
  }

  Future<Map<Handedness, Hand>> detectHandFromImage(CameraImage image) async {
    Map<Handedness, Hand> handsDetected = {};
    List<dynamic> landmarksData = await retrieveLandmarks(image);
    if (landmarksData.isNotEmpty) {
      for (var handData in landmarksData) {
        int idx = 0;
        Map<HandLandmarks, HandKeyPoint> keyPoints = {};
        handData['landmarks'].forEach((pt) {
          final x = 1 - (pt['y'] as double);
          final y = 1 - (pt['x'] as double);
          final z = pt['z'] as double;
          final landmark = HandLandmarks.values[idx];
          keyPoints[landmark] = HandKeyPoint(position: Vector3(x, y, z), landmark: landmark);
          idx++;
        });
        Handedness handSide = (handData['handedness'] == 'Left') ? Handedness.left : Handedness.right;
        handsDetected[handSide] = Hand(handedness: handSide, keyPoints: keyPoints);
      }
    }
    return handsDetected;
  }
}
