import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:movemind/painter.dart';
import 'package:movemind/service/handLandmark.dart';
import 'package:movemind/utils/handIdentifier.dart';
import 'package:movemind/utils/imageConverter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:vector_math/vector_math_64.dart' as vectorMath;
import '../service/gestureDetection.dart';

// ...existing utility code...
enum GestureType {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight_nine,
  jeep,
  pinky,
}

class GestureCheckResult {
  final GestureType type;
  final double confidence;
  GestureCheckResult(this.type, this.confidence);
}

class PoseDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const PoseDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> with SingleTickerProviderStateMixin {
  // ...existing fields...
  late CameraController _cameraController;
  bool _isProcessing = false;
  Map<Handedness, Hand> _detectedHands = {};
  late Interpreter interpreter;
  final handLandmarker = HandLandmarkerService();
  int score = 0;
  String predictedGesture = 'Nil';
  double gestureConfidence = 0.0;
  Handedness targetHand = Handedness.left;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  bool _showFlash = false;

  GestureCheckResult checkGesture(Map<HandLandmarks, HandKeyPoint> landmarks) {
    const int inputSize = 63;
    const int outputSize = 11;
    List<vectorMath.Vector3> keyPoints =
        HandLandmarks.values.map((lm) => landmarks[lm]!.position).toList();
    keyPoints = GestureDetection.landmarkNormalization(keyPoints);
    List<double> inputData = [];
    for (var pt in keyPoints) {
      inputData.addAll([pt.x, pt.y, pt.z]);
    }
    Float32List inputTensor = Float32List.fromList(inputData);
    List<List<double>> outputTensor = List.generate(1, (_) => List.filled(outputSize, 0.0));
    interpreter.run(inputTensor, outputTensor);
    List<double> outputs = outputTensor[0];
    int maxIndex = outputs.indexOf(outputs.reduce((a, b) => a > b ? a : b));
    return GestureCheckResult(GestureType.values[maxIndex], outputs[maxIndex]);
  }

  void processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    Map<Handedness, Hand> hands = await handLandmarker.detectHandFromImage(image);
    if (hands.isNotEmpty) {
      Map<Handedness, GestureType> gestures = {};
      hands.forEach((side, hand) {
        GestureCheckResult result = checkGesture(hand.keyPoints);
        gestureConfidence = result.confidence;
        if (result.confidence >= 0.5) {
          gestures[side] = result.type;
          predictedGesture = result.type.name;
          _detectedHands = hands;
        } else {
          predictedGesture = 'Nil';
        }
      });
      if (hands.containsKey(targetHand) &&
          hands.containsKey(targetHand == Handedness.left ? Handedness.right : Handedness.left)) {
        if (gestures[targetHand] == GestureType.six &&
            gestures[targetHand == Handedness.left ? Handedness.right : Handedness.left] == GestureType.pinky) {
          score += 1;
          targetHand = (targetHand == Handedness.left) ? Handedness.right : Handedness.left;
          triggerFlash();
        }
      } else {
        print('Only one hand detected: ${hands[targetHand]}');
      }
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {});
    } else {
      predictedGesture = 'Nil';
      print('No hands detected');
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {});
    }
    _isProcessing = false;
  }

  void initInterpreter() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/models/gestured_detection.tflite');
      print('Interpreter loaded: ${interpreter.getInputTensors()[0].shape} -> ${interpreter.getOutputTensors()[0].shape}');
    } catch (err) {
      print('Interpreter error: $err');
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _showFlash = false;
        _animationController.reset();
        setState(() {});
      }
    });
    initInterpreter();
    handLandmarker.initialize();
    _cameraController = CameraController(widget.cameras[1], ResolutionPreset.max);
    _cameraController.initialize().then((_) {
      _cameraController.startImageStream(processCameraImage);
      if (!mounted) return;
      setState(() {});
    }).catchError((err) => print('Camera init error: $err'));
  }

  void triggerFlash() {
    _showFlash = true;
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.stopImageStream();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pose Detection')),
      floatingActionButton: FloatingActionButton(onPressed: triggerFlash, child: const Icon(Icons.file_download)),
      body: _cameraController.value.isInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController),
                CustomPaint(
                  painter: PosePainter(hands: _detectedHands),
                  size: MediaQuery.of(context).size,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    'Predicted: $predictedGesture',
                    style: TextStyle(fontSize: 24, color: Colors.white, backgroundColor: Colors.orangeAccent.withOpacity(0.5)),
                  ),
                ),
                Positioned(
                  bottom: 55,
                  left: 20,
                  child: Text(
                    'Confidence: ${(gestureConfidence * 100).toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 24, color: Colors.white, backgroundColor: Colors.blueAccent.withOpacity(0.5)),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Text(
                    'Score: $score',
                    style: TextStyle(fontSize: 24, color: Colors.white, backgroundColor: Colors.black54),
                  ),
                ),
                if (_showFlash)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) => Positioned.fill(
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(color: Colors.green.withOpacity(0.7)),
                      ),
                    ),
                  ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
