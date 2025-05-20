import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

import '../utils/hand_identifier.dart';

class GestureDetection {
  static const double TARGET_SCALE = 0.2;

  static double norm(Vector3 v) {
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  }

  static List<Vector3> columnStack(List<Vector3> vectors) {
    List<Vector3> result = [];
    for (int i = 0; i < vectors.length; i++) {
      Vector3 v = vectors[i];
      result.add(Vector3(v.x, v.y, v.z));
    }
    return result;
  }

  static Vector3 cross(Vector3 a, Vector3 b) {
    return Vector3(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
    );
  }

  static Vector3 normalize(Vector3 v) {
    double normD = norm(v);
    if (normD > 0) {
      v.x /= normD;
      v.y /= normD;
      v.z /= normD;
    }
    return v;
  }

  static List<Vector3> landmarkNormalization(
      List<Vector3> landmarks) {
    List<double> xs = List<double>.filled(landmarks.length, 0.0);
    List<double> ys = List<double>.filled(landmarks.length, 0.0);
    List<double> zs = List<double>.filled(landmarks.length, 0.0);

    for (int i = 0; i < landmarks.length; i++) {
      Vector3 keypoint = landmarks[i];
      xs[i] = keypoint.x;
      ys[i] = -keypoint.y;
      zs[i] = -keypoint.z;
    }

    Vector3 wrist = landmarks[HandLandmarks.wrist.index];
    Vector3 middleMcp = landmarks[HandLandmarks.middleFingerMcp.index];
    Vector3 pinkyMcp = landmarks[HandLandmarks.pinkyMcp.index];


    Vector3 yAxis = middleMcp - wrist;

    double referenceLength = norm(yAxis);
    double scaleFactor = referenceLength > 0 ? TARGET_SCALE / referenceLength : 1.0;

    yAxis = normalize(yAxis);

    Vector3 tempVector = pinkyMcp - wrist;

    Vector3 zAxis = cross(yAxis, tempVector);
    zAxis = normalize(zAxis);

    Vector3 xAxis = cross(yAxis, zAxis);
    xAxis = normalize(xAxis);

    zAxis = cross(xAxis, yAxis);
    zAxis = normalize(zAxis);

    List<Vector3> handAxes = columnStack([xAxis, yAxis, zAxis]);

    List<Vector3> normalizedLandmarks = [];
    for (int i = 0; i < landmarks.length; i++) {
      Vector3 landmarkPosition = landmarks[i] - wrist;
      // First create a Matrix3 from your hand axes vectors
      Matrix3 handAxesMatrix = Matrix3(
          handAxes[0].x, handAxes[0].y, handAxes[0].z,  // First column (x-axis)
          handAxes[1].x, handAxes[1].y, handAxes[1].z,  // Second column (y-axis)
          handAxes[2].x, handAxes[2].y, handAxes[2].z   // Third column (z-axis)
      );

      // Transpose the matrix
      Matrix3 transposedHandAxes = handAxesMatrix.transposed();

      transposedHandAxes.transform(landmarkPosition);
      landmarkPosition *= scaleFactor;
      normalizedLandmarks.add(landmarkPosition);
    }

    return normalizedLandmarks;
  }
}