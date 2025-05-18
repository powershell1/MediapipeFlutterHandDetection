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

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  late CameraController _cameraController;
  late bool _isProcessing = false;
  late Map<Handedness, Hand> _detectedHand = {};
  final handLandmarkService = HandLandmarkerService();
  late int score = 4;
  late bool isCorrect = true;

  late Handedness targetHanded = Handedness.left;

  late CameraImage testImage;

  void onAvailable(CameraImage image) async {
    testImage = image;
    if (_isProcessing) return;
    _isProcessing = true;
    List<dynamic> handLandmarks =
        await handLandmarkService.detectHandLandmarks(image);
    if (handLandmarks.isNotEmpty) {
      setState(() {
        _detectedHand.clear();
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
        bool ok = false, lShape = false;
        if (_detectedHand[Handedness.left] != null) {
          Map<String, bool> mapped = HandIdentifier.identify(_detectedHand[Handedness.left]!);
          if (targetHanded == Handedness.left) {
            ok = mapped['ok'] == true;
          } else {
            lShape = mapped['l_shape'] == true;
          }
        }
        if (_detectedHand[Handedness.right] != null) {
          Map<String, bool> mapped = HandIdentifier.identify(_detectedHand[Handedness.right]!);
          if (targetHanded == Handedness.right) {
            ok = mapped['ok'] == true;
          } else {
            lShape = mapped['l_shape'] == true;
          }
        }
        if (ok && lShape) {
          score++;
          if (targetHanded == Handedness.left) {
            targetHanded = Handedness.right;
          } else {
            targetHanded = Handedness.left;
          }
        }
      });
      // Process hand landmarks
      // print('Hand landmarks detected: $handLandmarks');
      await Future.delayed(const Duration(milliseconds: 50));
    } else {
      print('No hand landmarks detected');
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // await Future.delayed(const Duration(milliseconds: 250));
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
        title: const Text('Pose Detection'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            // Get the image data
            imglib.Image imageBytes = ImageConverter.convertCameraImageToImage(testImage);

            // Import these at the top of your file
            // import 'dart:io';
            // import 'package:path_provider/path_provider.dart';

            // Get application documents directory
            final directory = await getApplicationDocumentsDirectory();

            // Create a unique filename using timestamp
            String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
            final file = File('${directory.path}/image_$timestamp.png');

            // Write the file
            await file.writeAsBytes(imglib.encodePng(imageBytes));

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Image saved to ${file.path}')),
              );
            }
          } catch (e) {
            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save image: $e')),
              );
            }
          }
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
              'Score: $score',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 20,
            child: Text(
              isCorrect ? 'Correct!' : 'Try Again!',
              style: TextStyle(
                fontSize: 24,
                color: isCorrect ? Colors.green : Colors.red,
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
