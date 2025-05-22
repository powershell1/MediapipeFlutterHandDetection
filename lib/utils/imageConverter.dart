import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

class ImageConverter {
  static Uint8List convertCameraImageToUint8List(CameraImage cameraImage, {int? targetWidth, int? targetHeight}) {
    imglib.Image img = convertCameraImageToImage(cameraImage);

    if (targetWidth != null && targetHeight != null) {
      img = imglib.resize(img, width: targetWidth, height: targetHeight);
    }

    return convertImageToUint8List(img);
  }

  static imglib.Image convertCameraImageToImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888(cameraImage);
    } else {
      throw Exception('Unsupported image format: ${cameraImage.format.group}');
    }
  }

  static Uint8List convertImageToUint8List(imglib.Image image) {
    final int length = image.width * image.height * 3;
    final Uint8List rgbBytes = Uint8List(length);
    int index = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        rgbBytes[index++] = pixel.r.toInt();
        rgbBytes[index++] = pixel.g.toInt();
        rgbBytes[index++] = pixel.b.toInt();
      }
    }
    return rgbBytes;
  }

  static imglib.Image _convertYUV420(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    imglib.Image img = imglib.Image(width: width, height: height);

    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;
    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;
    final List<int> yIndices = List.generate(height, (y) => y * yRowStride);
    final List<int> uvIndices = List.generate(height ~/ 2, (y) => y * uvRowStride);

    for (int y = 0; y < height; y++) {
      int yOffset = yIndices[y];
      int uvOffset = uvIndices[y ~/ 2];
      for (int x = 0; x < width; x++) {
        int yIndex = yOffset + x;
        int uvIndex = uvOffset + (x ~/ 2) * uvPixelStride;
        int yVal = yBuffer[yIndex];
        int uVal = uBuffer[uvIndex];
        int vVal = vBuffer[uvIndex];

        int y1 = 1192 * (yVal - 16);
        int r = (y1 + 1634 * (vVal - 128)) ~/ 1000;
        int g = (y1 - 833 * (vVal - 128) - 400 * (uVal - 128)) ~/ 1000;
        int b = (y1 + 2066 * (uVal - 128)) ~/ 1000;
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        img.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return img;
  }

  static imglib.Image _convertBGRA8888(CameraImage cameraImage) {
    return imglib.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: imglib.ChannelOrder.bgra,
    );
  }
}
