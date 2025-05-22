import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import 'handLandmark.dart';

class VectorOperation {
  static const double TARGET_SCALE = 0.2;

  static double vectorNorm(Vector3 v) => v.length;

  static List<Vector3> cloneVectors(List<Vector3> vectors) =>
      vectors.map((v) => Vector3.copy(v)).toList();

  static Vector3 crossProduct(Vector3 a, Vector3 b) => a.cross(b);

  static Vector3 safeNormalize(Vector3 v) {
    double len = vectorNorm(v);
    return (len > 0) ? v / len : v;
  }

  static List<Vector3> landmarkNormalization(List<Vector3> landmarks) {
    // Get key landmark positions
    final Vector3 wrist = landmarks[HandLandmarks.wrist.index];
    final Vector3 middleMcp = landmarks[HandLandmarks.middleFingerMcp.index];
    final Vector3 pinkyMcp = landmarks[HandLandmarks.pinkyMcp.index];

    // Define the coordinate system based on hand anatomy
    Vector3 yAxis = middleMcp - wrist;
    final double referenceLength = yAxis.length;
    final double scaleFactor = referenceLength > 0 ? TARGET_SCALE / referenceLength : 1.0;

    // Normalize axes to create orthogonal coordinate system
    yAxis = safeNormalize(yAxis);

    Vector3 tempVector = pinkyMcp - wrist;
    Vector3 zAxis = crossProduct(yAxis, tempVector);
    zAxis = safeNormalize(zAxis);

    Vector3 xAxis = crossProduct(yAxis, zAxis);
    xAxis = safeNormalize(xAxis);

    // Ensure z-axis is perfectly orthogonal
    zAxis = crossProduct(xAxis, yAxis);
    zAxis = safeNormalize(zAxis);

    // Create transformation matrix from hand coordinate system
    final Matrix3 transformMatrix = Matrix3(
        xAxis.x, yAxis.x, zAxis.x,
        xAxis.y, yAxis.y, zAxis.y,
        xAxis.z, yAxis.z, zAxis.z
    );

    // Apply normalization to all landmarks
    return landmarks.map((landmark) {
      // Translate landmark to origin at wrist
      Vector3 centered = landmark - wrist;

      // Apply rotation to align with canonical axes
      Vector3 rotated = transformMatrix * centered;

      // Scale to target size
      return rotated * scaleFactor;
    }).toList();
  }
}