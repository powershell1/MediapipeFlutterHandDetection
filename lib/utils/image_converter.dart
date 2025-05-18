import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

class ImageConverter {
  /// Converts a CameraImage directly to a Uint8List of RGB values
  static Uint8List convertCameraImageToUint8List(CameraImage cameraImage, {int? targetWidth, int? targetHeight}) {
    imglib.Image image = convertCameraImageToImage(cameraImage);

    // Resize if needed
    if (targetWidth != null && targetHeight != null) {
      image = imglib.resize(image, width: targetWidth, height: targetHeight);
    }

    return convertImageToUint8List(image);
  }

  static imglib.Image convertCameraImageToImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888ToImage(cameraImage);
    } else {
      throw Exception('Image format not supported: ${cameraImage.format.group}');
    }
  }

  /// Converts an imglib.Image to Uint8List in RGB format
  static Uint8List convertImageToUint8List(imglib.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int length = width * height * 3; // RGB requires 3 bytes per pixel
    final Uint8List result = Uint8List(length);

    int index = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        result[index++] = pixel.r.toInt(); // Red
        result[index++] = pixel.g.toInt(); // Green
        result[index++] = pixel.b.toInt(); // Blue
      }
    }

    return result;
  }

  /// Converts YUV420 CameraImage to imglib Image with optimized conversion
  static imglib.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final imglib.Image img = imglib.Image(width: width, height: height);

    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;

    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    // Pre-compute row indices to avoid redundant calculations
    final List<int> yRowIndices = List.generate(height, (y) => y * yRowStride);
    final List<int> uvRowIndices = List.generate(height ~/ 2, (y) => y * uvRowStride);

    for (int y = 0; y < height; y++) {
      final int uvY = uvRowIndices[y ~/ 2];
      final int yY = yRowIndices[y];

      for (int x = 0; x < width; x++) {
        final int uvX = (x ~/ 2) * uvPixelStride;
        final int uvIndex = uvX + uvY;
        final int yIndex = x + yY;

        final int yValue = yBuffer[yIndex];
        final int uValue = uBuffer[uvIndex];
        final int vValue = vBuffer[uvIndex];

        // Integer math version of YUV to RGB conversion
        final int y1 = 1192 * (yValue - 16);
        int r = (y1 + 1634 * (vValue - 128)) ~/ 1000;
        int g = (y1 - 833 * (vValue - 128) - 400 * (uValue - 128)) ~/ 1000;
        int b = (y1 + 2066 * (uValue - 128)) ~/ 1000;

        // Clipping RGB values
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        img.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return img;
  }

  /// Converts BGRA8888 format to imglib Image
  static imglib.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    // Direct buffer access for best performance
    return imglib.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: imglib.ChannelOrder.bgra,
    );
  }
}