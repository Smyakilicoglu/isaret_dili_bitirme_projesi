import 'dart:async';
import 'dart:ui'; // DÜZELTİLDİ: ImageFilter için bu import zorunludur
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import '../models/translation_item.dart';
import '../services/database_helper.dart';
import '../services/tflite_service.dart';
import '../services/landmark_service.dart';
import '../services/translation_service.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;

  final FlutterTts _flutterTts = FlutterTts();
  final TFLiteService _tfliteService = TFLiteService();
  final LandmarkService _landmarkService = LandmarkService();

  String _subtitle = 'İşaret yapmaya başlayın...';
  bool _isFlashOn = false;
  bool _isProcessing = false;
  final List<List<double>> _frameBuffer = [];
  
  // YENİ: Stabilizasyon değişkenleri
  String _lastPredictedWord = '';
  int _consecutiveCount = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initTTS();
    _tfliteService.loadModel();
  }

  Future<void> _saveTranslation(String text) async {
    final now = DateTime.now();
    final item = TranslationItem(
      text: text,
      date: TranslationItem.getDateLabel(now),
      time: TranslationItem.getTimeLabel(now),
      timestamp: now,
    );
    await DatabaseHelper.instance.addTranslation(item);
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _onNewCameraSelected(_cameras[_selectedCameraIdx]);
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (mounted) setState(() => _isCameraInitialized = false);

    if (_controller != null) {
      await _controller!.stopImageStream().catchError((_) {});
      await _controller!.dispose();
      _controller = null;
    }

    _controller = CameraController(cameraDescription, ResolutionPreset.medium);
    try {
      await _controller!.initialize();
      await _controller!.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _processFrame(image);
        }
      });
    } catch (e) {
      debugPrint("Kamera hatası: $e");
    }
    if (mounted) setState(() => _isCameraInitialized = true);
  }

  Future<void> _processFrame(CameraImage image) async {
    _isProcessing = true;
    try {
      final sensorOrientation = _controller!.description.sensorOrientation;
      final landmarks = await _landmarkService.extractLandmarks(image, sensorOrientation);

      _frameBuffer.add(landmarks);

      if (_frameBuffer.length >= 30) {
        // En son 30 kareyi al (Sliding Window)
        final sequence = List<List<double>>.from(_frameBuffer.sublist(_frameBuffer.length - 30));
        
        // Belleği tamamen silmek yerine sadece en eski 5 kareyi siliyoruz.
        // Bu sayede hareketin tam ortasını yakalama şansımız %100 artıyor!
        _frameBuffer.removeRange(0, 5);

        final result = _tfliteService.predict(sequence);
        
        if (result == 'KİŞİ BEKLENİYOR...') {
          if (mounted) setState(() => _subtitle = result);
        } else {
          // Sonuç formatı: "KELİME|0.999"
          final parts = result.split('|');
          if (parts.length == 2) {
            final word = parts[0];
            final score = double.tryParse(parts[1]) ?? 0.0;

            // Stabilizasyon Filtresi: Skoru %60'ın üzerindeyse (eller olmadığı için skorlar genelde düşüktür) dikkate al.
            if (score > 0.60) {
              if (word == _lastPredictedWord) {
                _consecutiveCount++;
                // Hızı artırmak için 2 yerine 1 ardışık (peş peşe 2 kare) yeterli dedik!
                if (_consecutiveCount >= 1 && mounted) {
                  setState(() {
                    _subtitle = '$word\n(%${(score * 100).toStringAsFixed(1)})';
                  });
                }
              } else {
                _lastPredictedWord = word;
                _consecutiveCount = 0; // Sıfırlandı
              }
            } else {
               // Skor çok düşükse hareketi anlamaya çalışıyor demektir
               if (mounted && _subtitle != 'İşaret yapmaya başlayın...') {
                  setState(() => _subtitle = 'Hareket analiz ediliyor...');
               }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Kare işleme hatası: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _toggleCamera() {
    if (_cameras.isEmpty || _cameras.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    _onNewCameraSelected(_cameras[_selectedCameraIdx]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isCameraInitialized) return;
    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint('Flaş hatası: $e');
    }
  }

  Future<void> _speak() async {
    if (_subtitle == 'İşaret yapmaya başlayın...') return;
    await _flutterTts.speak(_subtitle);
    await _saveTranslation(_subtitle);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçmişe kaydedildi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _resetTranslation() {
    _frameBuffer.clear();
    setState(() => _subtitle = 'İşaret yapmaya başlayın...');
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _flutterTts.stop();
    _tfliteService.dispose();
    _landmarkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // KAMERA ÖNİZLEME - TAM EKRAN
            Positioned.fill(
              child: _isCameraInitialized && _controller != null
                  ? ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              )
                  : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

            // ÜST BAR
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'İşaret Dili Çeviri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildTopButton(
                      icon: Icons.settings,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // SAĞ TARAF BUTONLARI
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.35,
              child: Column(
                children: [
                  _buildSideButton(
                    icon: Icons.cameraswitch,
                    onPressed: _toggleCamera,
                  ),
                  const SizedBox(height: 16),
                  _buildSideButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onPressed: _toggleFlash,
                  ),
                ],
              ),
            ),

            // ALT KISIM - ÇEVİRİ VE BUTONLAR
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: _resetTranslation,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text(
                        'TEMİZLE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  // ALTYAZI KUTUSU (DÜZELTİLDİ: Parantezler doğru hiyerarşiye alındı)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                  TranslationService.t('live_translation', AppSettings.instance.language),
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                    ],
                                  ),
                                  Text(
                                    '${_frameBuffer.length}/30 kare',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                  _subtitle.isEmpty ? TranslationService.t('ready', AppSettings.instance.language) : _subtitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Colors.blueAccent, Colors.lightBlue],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blueAccent.withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.volume_up, color: Colors.white),
                                      onPressed: _speak,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HistoryScreen()),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               Icon(Icons.history,
                                  color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                TranslationService.t('history', AppSettings.instance.language),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                               Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon,
            color: Colors.white,
            size: icon == Icons.settings ? 24 : 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSideButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}