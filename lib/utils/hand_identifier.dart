import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

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
  String toString() {
    return 'Hand{handedness: $handedness, key points: $keyPoints}';
  }
}


class HandIdentifier {
  static double calculateFingerAngle(Hand hand) {
    Vector3 thumbCmc = hand.keyPoints[HandLandmarks.thumbCmc]!.position;
    Vector3 thumbTip = hand.keyPoints[HandLandmarks.thumbTip]!.position;
    Vector3 indexFingerTip = hand.keyPoints[HandLandmarks.indexFingerTip]!.position;

    // Create vectors from thumbCmc to the tips
    double v1x = thumbTip.x - thumbCmc.x;
    double v1y = thumbTip.y - thumbCmc.y;

    double v2x = indexFingerTip.x - thumbCmc.x;
    double v2y = indexFingerTip.y - thumbCmc.y;

    // Calculate dot product
    double dotProduct = v1x * v2x + v1y * v2y;

    // Calculate magnitudes
    double v1Magnitude = sqrt(v1x * v1x + v1y * v1y);
    double v2Magnitude = sqrt(v2x * v2x + v2y * v2y);

    // Avoid division by zero and ensure value is within acos domain
    if (v1Magnitude < 1e-6 || v2Magnitude < 1e-6) {
      return 0.0;
    }

    double cosValue = dotProduct / (v1Magnitude * v2Magnitude);
    cosValue = max(-1.0, min(1.0, cosValue));

    // Calculate angle in degrees
    return acos(cosValue) * 180 / pi;
  }
}