import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:movemind/service/hand_landmarker.dart';
import 'package:movemind/views/number_detection.dart';
import 'package:movemind/views/view.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get available cameras
  final cameras = await availableCameras();
  
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoveNet Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PoseDetectionScreen(cameras: cameras),
    );
  }
}