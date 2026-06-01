import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LandmarkService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  /// Bir kamera karesinden 225 landmark değeri çıkarır.
  /// pose(99) + sol_el_sıfır(63) + sağ_el_sıfır(63) = 225
  Future<List<double>> extractLandmarks(
      CameraImage image,
      int sensorOrientation,
      ) async {
    final inputImage = _toInputImage(image, sensorOrientation);
    final landmarks = <double>[];

    // ── POSE: 33 nokta × 3 = 99 değer ──────────────────────────────
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final pose = poses.first;
        final double imgWidth = image.width.toDouble();
        final double imgHeight = image.height.toDouble();
        
        // Android'de sensör 90 veya 270 ise boyutlar ters döner
        final bool isPortrait = sensorOrientation == 90 || sensorOrientation == 270;
        final double actualWidth = isPortrait ? imgHeight : imgWidth;
        final double actualHeight = isPortrait ? imgWidth : imgHeight;

        for (final type in PoseLandmarkType.values) {
          final lm = pose.landmarks[type];
          if (lm != null) {
            // Python'da veriler 0.0 ile 1.0 arasındaydı (Normalize edilmişti)
            // Ancak Flutter ML Kit bize piksel veriyor (örn: 450, 720).
            // Modeli bozmamak için pikselleri oranlayarak 0.0 - 1.0 arasına çekiyoruz!
            final double normX = lm.x / actualWidth;
            final double normY = lm.y / actualHeight;
            final double normZ = lm.z / actualWidth; // Z derinliği de X'in skalasındadır
            landmarks.addAll([normX, normY, normZ]);
          } else {
            landmarks.addAll([0.0, 0.0, 0.0]);
          }
        }
      } else {
        landmarks.addAll(List.filled(99, 0.0));
      }
    } catch (e) {
      debugPrint('Pose hatası: $e');
      landmarks.addAll(List.filled(99, 0.0));
    }

    // ── EL LANDMARK'LARI: şimdilik sıfır (sol 63 + sağ 63 = 126) ──
    landmarks.addAll(List.filled(126, 0.0));

    // Her zaman tam 225 eleman
    while (landmarks.length < 225) landmarks.add(0.0);
    return landmarks.sublist(0, 225);
  }

  InputImage _toInputImage(CameraImage image, int sensorOrientation) {
    final rotation = _rotationFromSensor(sensorOrientation);

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _poseDetector.close();
  }
}
