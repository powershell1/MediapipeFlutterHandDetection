import 'package:flutter/material.dart';
import 'package:movemind/service/handLandmark.dart';

class PosePainter extends CustomPainter {
  final Map<Handedness, Hand> hands;

  PosePainter({required this.hands});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final scaleX = size.width;
    final scaleY = size.height;

    final connections = [
      [HandLandmarks.wrist, HandLandmarks.thumbCmc],
      [HandLandmarks.thumbCmc, HandLandmarks.thumbMcp],
      [HandLandmarks.thumbMcp, HandLandmarks.thumbIp],
      [HandLandmarks.thumbIp, HandLandmarks.thumbTip],
      [HandLandmarks.wrist, HandLandmarks.indexFingerMcp],
      [HandLandmarks.indexFingerMcp, HandLandmarks.indexFingerPip],
      [HandLandmarks.indexFingerPip, HandLandmarks.indexFingerDip],
      [HandLandmarks.indexFingerDip, HandLandmarks.indexFingerTip],
      [HandLandmarks.wrist, HandLandmarks.middleFingerMcp],
      [HandLandmarks.middleFingerMcp, HandLandmarks.middleFingerPip],
      [HandLandmarks.middleFingerPip, HandLandmarks.middleFingerDip],
      [HandLandmarks.middleFingerDip, HandLandmarks.middleFingerTip],
      [HandLandmarks.wrist, HandLandmarks.ringFingerMcp],
      [HandLandmarks.ringFingerMcp, HandLandmarks.ringFingerPip],
      [HandLandmarks.ringFingerPip, HandLandmarks.ringFingerDip],
      [HandLandmarks.ringFingerDip, HandLandmarks.ringFingerTip],
      [HandLandmarks.wrist, HandLandmarks.pinkyMcp],
      [HandLandmarks.pinkyMcp, HandLandmarks.pinkyPip],
      [HandLandmarks.pinkyPip, HandLandmarks.pinkyDip],
      [HandLandmarks.pinkyDip, HandLandmarks.pinkyTip],
      [HandLandmarks.indexFingerMcp, HandLandmarks.middleFingerMcp],
      [HandLandmarks.middleFingerMcp, HandLandmarks.ringFingerMcp],
      [HandLandmarks.ringFingerMcp, HandLandmarks.pinkyMcp],
    ];

    final jointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    hands.forEach((side, hand) {
      for (var conn in connections) {
        final pt1 = hand.keyPoints[conn[0]]!.position;
        final pt2 = hand.keyPoints[conn[1]]!.position;
        canvas.drawLine(
          Offset(pt1.x * scaleX, pt1.y * scaleY),
          Offset(pt2.x * scaleX, pt2.y * scaleY),
          paint,
        );
      }
    });

    hands.forEach((side, hand) {
      for (var kp in hand.keyPoints.values) {
        canvas.drawCircle(
          Offset(kp.position.x * scaleX, kp.position.y * scaleY),
          6,
          jointPaint,
        );
      }
    });
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }
}
