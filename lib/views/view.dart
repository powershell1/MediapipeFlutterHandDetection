import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:movemind/painter.dart';
import 'package:movemind/service/hand_landmarker.dart';
import 'package:movemind/utils/hand_identifier.dart';
import 'package:movemind/utils/image_converter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:vector_math/vector_math_64.dart' as vectorMath;

import '../service/gesture_detection.dart';

class PoseDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const PoseDetectionScreen({Key? key, required this.cameras})
      : super(key: key);

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

Future<Uint8List> loadJsonAsUint8List(String assetPath) async {
  // Load the JSON file as string
  final jsonString = await rootBundle.loadString(assetPath);

  // Parse the JSON string
  final jsonData = jsonDecode(jsonString);

  // Convert to Uint8List - this assumes jsonData contains a flat array of numbers
  if (jsonData is List) {
    // If JSON contains a flat array of numbers
    final buffer = Uint8List(jsonData.length);
    for (int i = 0; i < jsonData.length; i++) {
      buffer[i] = jsonData[i] as int;
    }
    return buffer;
  } else if (jsonData is Map && jsonData.containsKey('data')) {
    // If JSON has a 'data' field with the array
    final dataList = jsonData['data'] as List;
    final buffer = Uint8List(dataList.length);
    for (int i = 0; i < dataList.length; i++) {
      buffer[i] = dataList[i] as int;
    }
    return buffer;
  }

  throw Exception('JSON format not supported');
}

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
  final GestureType gestureType;
  final double confidence;

  GestureCheckResult(this.gestureType, this.confidence);
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> with SingleTickerProviderStateMixin {
late CameraController _cameraController;
  late bool _isProcessing = false;
  late Map<Handedness, Hand> _detectedHand = {};
  late Interpreter interpreter;
  final handLandmarkService = HandLandmarkerService();
  late int score = 0;
  late bool isCorrect = true;

  late String predictedNumber = 'Nil';
  late double confidence = 0.0;

  late Handedness targetHanded = Handedness.left;

  // Add these properties
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  bool _showAnimation = false;

  GestureCheckResult gestureChecking(Map<HandLandmarks, HandKeyPoint>  landmarks) {
    final int inputSize = 63;
    final int outputSize = 11;

    List<vectorMath.Vector3> normalizedKeyPoints = [];
    for (int i = 0; i < HandLandmarks.values.length; i++) {
      vectorMath.Vector3 position = landmarks[HandLandmarks.values[i]]!.position;
      normalizedKeyPoints.add(position);
    }
    normalizedKeyPoints = GestureDetection.landmarkNormalization(normalizedKeyPoints);
    // Convert to Uint8List
    List<double> inputData = List<double>.filled(inputSize, 0.0);
    for (int i = 0; i < inputSize/3; i++) {
      int index = i * 3;
      vectorMath.Vector3 position = normalizedKeyPoints[i];
      inputData[index] = position.x;
      inputData[index + 1] = position.y;
      inputData[index + 2] = position.z;
    }
    // Convert to Float32List
    Float32List input = Float32List.fromList(inputData);
    // Prepare output buffer
    List<List<double>> output = List.generate(1, (_) => List.generate(outputSize, (_) => 0.0));
    interpreter.run(input, output);
    List<double> outputData = output[0];
    // Find the index of the maximum value
    int maxIndex = outputData.indexOf(outputData.reduce((a, b) => a > b ? a : b));
    // print(maxIndex);
    return GestureCheckResult(GestureType.values[maxIndex], outputData[maxIndex]);
  }

  void onAvailable(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    Map<Handedness, Hand> detectedHand = await handLandmarkService.detectHandLandmarksFromImage(image);
    if (detectedHand.isNotEmpty) {
      Map<Handedness, GestureType> handGesture = {};
      for (Hand hand in detectedHand.values) {
        GestureCheckResult result = gestureChecking(hand.keyPoints);

        confidence = result.confidence;
        if (result.confidence < 0.5) {
          setState(() {
            predictedNumber = 'Nil';
          });
        } else {
          handGesture[hand.handedness] = result.gestureType;
          setState(() {
            predictedNumber = result.gestureType.name;
            _detectedHand = detectedHand;
          });
        }
      }
      // Check if both hands are detected
      Handedness leftHand = Handedness.values[(targetHanded.index + 1) % 2];
      if (detectedHand[targetHanded] != null && detectedHand[leftHand] != null) {
        if (handGesture[targetHanded] == GestureType.six && handGesture[leftHand] == GestureType.pinky) {
          score += 1;
          targetHanded = leftHand;
          showGreenFlash();
        }
      } else {
        // Only one hand is detected
        print('Only one hand detected: ${detectedHand[targetHanded]}');

      }
      // Process hand landmarks
      // print('Hand landmarks detected: $handLandmarks');
      await Future.delayed(const Duration(milliseconds: 50));
    } else {
      setState(() {
        predictedNumber = 'Nil';
      });
      print('No hand landmarks detected');
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // await Future.delayed(const Duration(milliseconds: 250));
    _isProcessing = false;
  }

  void initializeInterpreter() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/models/gestured_detection.tflite');
      // Print shape of input and output tensors
      var inputTensor = interpreter.getInputTensors();
      var outputTensor = interpreter.getOutputTensors();
      print('Input Tensor Shape: ${inputTensor[0].shape}');
      print('Output Tensor Shape: ${outputTensor[0].shape}');
      print('Interpreter initialized successfully');
    } catch (e) {
      print('Error initializing interpreter: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Create opacity animation that starts fully visible and fades out
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        // Delay the fade out until halfway through
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Listen for animation completion to hide the overlay
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showAnimation = false;
        });
        _animationController.reset();
      }
    });

    initializeInterpreter();

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

  // Add this method to trigger the animation
  void showGreenFlash() {
    setState(() {
      _showAnimation = true;
    });
    _animationController.forward(from: 0.0);
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
      appBar: AppBar(
        title: const Text('Pose Detection'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          showGreenFlash();
        },
        child: const Icon(Icons.file_download),
      ),
      body:  _cameraController.value.isInitialized ? Stack(
        children: [
          CameraPreview(_cameraController),
          CustomPaint(
            painter: PosePainter(
              hands: _detectedHand,
            ),
            size: MediaQuery.of(context).size,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Text(
              'Predicted: $predictedNumber',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                backgroundColor: Colors.orangeAccent.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 55,
            left: 20,
            child: Text(
              'Confident: ${(confidence*10000).toInt()/100}%',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                backgroundColor: Colors.blueAccent.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              'Score: $score',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                backgroundColor: Colors.black54,
              ),
            ),
          ),

          // Add this for the green flash animation
          if (_showAnimation)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Positioned.fill(
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      color: Colors.green.withOpacity(0.7),
                    ),
                  ),
                );
              },
            ),
        ],
      ) : CircularProgressIndicator(),
    );
  }

// The rest of your implementation...
}
