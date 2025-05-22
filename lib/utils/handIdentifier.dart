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
  String toString() => 'Hand { handedness: $handedness, keyPoints: $keyPoints }';
}

class HandIdentifier {
  static double computeFingerAngle(Hand hand) {
    Vector3 start = hand.keyPoints[HandLandmarks.thumbCmc]!.position;
    Vector3 thumbTip = hand.keyPoints[HandLandmarks.thumbTip]!.position;
    Vector3 indexTip = hand.keyPoints[HandLandmarks.indexFingerTip]!.position;

    Vector3 vec1 = thumbTip - start;
    Vector3 vec2 = indexTip - start;

    double dot = vec1.dot(vec2);
    double mag1 = vec1.length;
    double mag2 = vec2.length;

    if (mag1 < 1e-6 || mag2 < 1e-6) return 0.0;

    double cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosAngle) * 180 / pi;
  }
}
