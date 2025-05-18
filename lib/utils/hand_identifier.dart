import 'dart:math';

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
  final double x;
  final double y;
  final double z;
  final HandLandmarks landmark;

  HandKeyPoint({required this.x, required this.y, required this.z, required this.landmark});
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
    HandKeyPoint thumbCmc = hand.keyPoints[HandLandmarks.thumbCmc]!;
    HandKeyPoint thumbTip = hand.keyPoints[HandLandmarks.thumbTip]!;
    HandKeyPoint indexFingerTip = hand.keyPoints[HandLandmarks.indexFingerTip]!;

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

  static List<bool> _extendedFingers(Hand hand) {
    List<bool> extendedFingers = [];
    for (int i = 0; i < 5; i++) {
      HandKeyPoint fingerTip = hand.keyPoints[HandLandmarks.values[i * 4 + 4]]!;
      HandKeyPoint fingerMcp = hand.keyPoints[HandLandmarks.values[i * 4 + 1]]!;
      double fingerDistance = sqrt(
          pow((fingerTip.x - fingerMcp.x), 2) +
              pow((fingerTip.y - fingerMcp.y), 2)
      );
      extendedFingers.add(fingerDistance > 0.3);
    }
    return extendedFingers;
  }

  static Map<String, bool> identify(Hand hand) {
    Map<String, bool> gestures = {
      'ok': false,
      'peace': false,
      'l_shape': false,
    };
    HandKeyPoint wrist = hand.keyPoints[HandLandmarks.wrist]!;
    HandKeyPoint middleFingerMcp = hand.keyPoints[HandLandmarks.middleFingerMcp]!;
    double handSize = sqrt(
        pow((wrist.x - middleFingerMcp.x), 2) + pow((wrist.y - middleFingerMcp.y), 2)
    );
    HandKeyPoint thumbTip = hand.keyPoints[HandLandmarks.thumbTip]!;
    HandKeyPoint indexFingerTip = hand.keyPoints[HandLandmarks.indexFingerTip]!;
    double thumbIndexDistance = sqrt(
        pow((thumbTip.x - indexFingerTip.x), 2) + pow((thumbTip.y - indexFingerTip.y), 2)
    );
    List<bool> extendedFinger = _extendedFingers(hand);
    // Check for "ok" gesture
    bool isOkGesture = thumbIndexDistance < handSize * 0.2 &&
        extendedFinger[2] &&
        extendedFinger[3] &&
        extendedFinger[4];
    gestures['ok'] = isOkGesture;

    // Check for "l_shape" gesture
    double angle = calculateFingerAngle(hand);
    bool isLShape = 50 < angle && angle < 100 &&
        !extendedFinger[2] &&
        !extendedFinger[3] &&
        !extendedFinger[4];
    gestures['l_shape'] = isLShape;

    return gestures;
  }

  static bool isIndexFingerPointing(Hand hand) {
    List<bool> extendedFinger = _extendedFingers(hand);
    double percentOfExtended = extendedFinger.where((e) => e).length / 5;
    print(percentOfExtended);
    return percentOfExtended > 0.5;
    /*
    return extendedFinger[1] &&
        !extendedFinger[0] &&
        !extendedFinger[2] &&
        !extendedFinger[3] &&
        !extendedFinger[4];

     */
  }
}