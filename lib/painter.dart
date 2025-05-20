import 'package:flutter/material.dart';
import 'package:movemind/utils/hand_identifier.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'views/view.dart'; // Import to use the SkeletonPosition class

class PosePainter extends CustomPainter {
  final Map<Handedness, Hand> hands;

  PosePainter({required this.hands});

  @override
  void paint(Canvas canvas, Size size) {
    // if (keypoints.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Scale factors to map from model coordinates to screen coordinates
    final double scaleX = size.width;
    final double scaleY = size.height;

    final skeletonConnections = [
      [HandLandmarks.wrist, HandLandmarks.thumbCmc], // Thumb base
      [HandLandmarks.thumbCmc, HandLandmarks.thumbMcp],
      [HandLandmarks.thumbMcp, HandLandmarks.thumbIp],
      [HandLandmarks.thumbIp, HandLandmarks.thumbTip],

      [HandLandmarks.wrist, HandLandmarks.indexFingerMcp], // Index finger base
      [HandLandmarks.indexFingerMcp, HandLandmarks.indexFingerPip],
      [HandLandmarks.indexFingerPip, HandLandmarks.indexFingerDip],
      [HandLandmarks.indexFingerDip, HandLandmarks.indexFingerTip],

      [HandLandmarks.wrist, HandLandmarks.middleFingerMcp], // Middle finger base
      [HandLandmarks.middleFingerMcp, HandLandmarks.middleFingerPip],
      [HandLandmarks.middleFingerPip, HandLandmarks.middleFingerDip],
      [HandLandmarks.middleFingerDip, HandLandmarks.middleFingerTip],

      [HandLandmarks.wrist, HandLandmarks.ringFingerMcp], // Ring finger base
      [HandLandmarks.ringFingerMcp, HandLandmarks.ringFingerPip],
      [HandLandmarks.ringFingerPip, HandLandmarks.ringFingerDip],
      [HandLandmarks.ringFingerDip, HandLandmarks.ringFingerTip],

      [HandLandmarks.wrist, HandLandmarks.pinkyMcp], // Pinky finger base
      [HandLandmarks.pinkyMcp, HandLandmarks.pinkyPip],
      [HandLandmarks.pinkyPip, HandLandmarks.pinkyDip],
      [HandLandmarks.pinkyDip, HandLandmarks.pinkyTip],

      [HandLandmarks.indexFingerMcp, HandLandmarks.middleFingerMcp], // Index to middle
      [HandLandmarks.middleFingerMcp, HandLandmarks.ringFingerMcp], // Middle to ring
      [HandLandmarks.ringFingerMcp, HandLandmarks.pinkyMcp], // Ring to pinky
    ];
    final jointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // print(keypoints);
    hands.forEach((handedness, hand) {
      // Draw connections
      for (var connection in skeletonConnections) {
        final p1 = hand.keyPoints[connection[0]]!.position;
        final p2 = hand.keyPoints[connection[1]]!.position;

        // Only draw if both keypoints have good confidence
        canvas.drawLine(
            Offset(p1.x * scaleX, p1.y * scaleY),
            Offset(p2.x * scaleX, p2.y * scaleY),
            paint
        );
      }
    });
    // Draw joints
    hands.forEach((handedness, hand) {
      for (var point in hand.keyPoints.values) {
        vector_math.Vector3 position = point.position;
        canvas.drawCircle(
            Offset(position.x * scaleX, position.y * scaleY),
            6,
            jointPaint
        );
      }
    });
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }
}