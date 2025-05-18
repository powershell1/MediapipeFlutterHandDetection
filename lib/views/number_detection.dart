import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:movemind/painter.dart';
import 'package:movemind/service/hand_landmarker.dart';
import 'package:movemind/utils/hand_identifier.dart';
import 'package:movemind/utils/image_converter.dart';
import 'package:image/image.dart' as imglib;

class NumberDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const NumberDetectionScreen({Key? key, required this.cameras})
      : super(key: key);

  @override
  State<NumberDetectionScreen> createState() => _PoseNumberDetectionScreen();
}

class _PoseNumberDetectionScreen extends State<NumberDetectionScreen> {
  late CameraController _cameraController;
  late bool _isProcessing = false;
  final handLandmarkService = HandLandmarkerService();
  late int numberPrediction = 0;

  late Handedness targetHanded = Handedness.left;

  void onAvailable(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    List<dynamic> handLandmarks =
    await handLandmarkService.detectHandLandmarks(image);
    if (handLandmarks.isNotEmpty) {
      Map<Handedness, Hand> _detectedHand = {};
      handLandmarks.forEach((hand) {
        int index = 0;
        Map<HandLandmarks, HandKeyPoint> _detectedKeypoints = {};
        hand['landmarks'].forEach((position) {
          final x = 1 - (position['y'] as double);
          final y = 1 - (position['x'] as double);
          final z = position['z'] as double;
          final landmark = HandLandmarks.values[index];
          // final index = position['index'] as int;
          _detectedKeypoints[landmark] = HandKeyPoint(
            x: x,
            y: y,
            z: z,
            landmark: landmark,
          );
          index++;
        });
        Handedness handedness =
        Handedness.values[hand['handedness'] == 'Left' ? 0 : 1];
        Hand handConstructed = Hand(
          handedness: handedness,
          keyPoints: _detectedKeypoints,
        );
        _detectedHand[handedness] = handConstructed;
      });
      if (_detectedHand[Handedness.left] == null) {
        print('No left hand detected');
        await Future.delayed(const Duration(milliseconds: 250));
      } else {
        final isPointing = HandIdentifier.isIndexFingerPointing(_detectedHand[Handedness.left]!);
        print(isPointing);
      }
      await Future.delayed(const Duration(milliseconds: 50));
    } else {
      print('No hand landmarks detected');
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _isProcessing = false;
  }

  @override
  void initState() {
    super.initState();
    handLandmarkService.initialize();
    _cameraController = CameraController(
      widget.cameras[1],
      ResolutionPreset.max,
    );
    _cameraController.initialize().then((_) {
      _cameraController.startImageStream(onAvailable);
      if (!mounted) return;
      setState(() {});
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
  }

  @override
  void dispose() {
    _cameraController.stopImageStream();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Number Detection'),
      ),
      body:  _cameraController.value.isInitialized ? Stack(
        children: [
          CameraPreview(_cameraController),
          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              'Predicted: $numberPrediction',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ],
      ) : CircularProgressIndicator(),
    );
  }

// The rest of your implementation...
}
