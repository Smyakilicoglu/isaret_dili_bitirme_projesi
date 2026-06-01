import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/result_box.dart';
import '../services/database_helper.dart';
import '../models/translation_item.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  String resultText = "Hazır — işaret yapın";
  bool _isProcessing = false;
  final FlutterTts _flutterTts = FlutterTts();
  static const String apiUrl = 'http://192.168.1.100:5000/predict';

  @override
  void initState() {
    super.initState();
    _initCamera();
    _flutterTts.setLanguage("tr-TR");
    _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
    _startStreaming();
  }

  void _startStreaming() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;
      try {
        await _sendFrame(image);
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _sendFrame(CameraImage image) async {
    try {
      final Uint8List bytes = image.planes[0].bytes;
      final String base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'frame': base64Image}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['prediction'];

        if (mounted && prediction != 'Bekleniyor...' && !prediction.contains('/30')) {
          setState(() => resultText = prediction);
        } else if (mounted && prediction.contains('/30')) {
          setState(() => resultText = prediction);
        }
      }
    } catch (e) {
      print("Hata: $e");
    }
  }

  Future<void> _seslendir() async {
    if (resultText == "Hazır — işaret yapın" || resultText.contains('/30')) {
      return;
    }
    // Seslendir
    await _flutterTts.speak(resultText);

    // Geçmişe kaydet
    final now = DateTime.now();
    await DatabaseHelper.instance.addTranslation(
      TranslationItem(
        text: resultText,
        date: TranslationItem.getDateLabel(now),
        time: TranslationItem.getTimeLabel(now),
        timestamp: now,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçmişe kaydedildi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _reset() async {
    try {
      await http.post(Uri.parse('http://192.168.1.100:5000/reset'));
    } catch (e) {}
    setState(() => resultText = "Hazır — işaret yapın");
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canlı Çeviri")),
      body: Column(
        children: [
          Expanded(
            child: _cameraController != null &&
                _cameraController!.value.isInitialized
                ? CameraPreview(_cameraController!)
                : const Center(child: CircularProgressIndicator()),
          ),
          ResultBox(text: resultText),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: _reset,
                child: const Text("Sıfırla"),
              ),
              ElevatedButton(
                onPressed: _seslendir,
                child: const Text("Seslendir"),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}