import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;

  final List<String> labels = [
  'abla', 'acele', 'acikmak', 'afiyet_olsun', 'agabey', 'agac', 'agir', 'aglamak', 'aile', 'akilli', 
  'akilsiz', 'akraba', 'alisveris', 'anahtar', 'anne', 'arkadas', 'ataturk', 'ayakkabi', 'ayna', 'ayni', 
  'baba', 'bahce', 'bakmak', 'bal', 'bardak', 'bayrak', 'bayram', 'bebek', 'bekar', 'beklemek', 'ben', 
  'benzin', 'beraber', 'bilgi_vermek', 'biz', 'calismak', 'carsamba', 'catal', 'cay', 'caydanlik', 
  'cekic', 'cirkin', 'cocuk', 'corba', 'cuma', 'cumartesi', 'cuzdan', 'dakika', 'dede', 'degistirmek', 
  'devirmek', 'devlet', 'doktor', 'dolu', 'dugun', 'dun', 'dusman', 'duvar', 'eczane', 'eldiven', 
  'emek', 'emekli', 'erkek', 'et', 'ev', 'evet', 'evli', 'ezberlemek', 'fil', 'fotograf', 'futbol', 
  'gecmis', 'gecmis_olsun', 'getirmek', 'gol', 'gomlek', 'gormek', 'gostermek', 'gulmek', 'hafif', 
  'hakli', 'hali', 'hasta', 'hastane', 'hata', 'havlu', 'hayir', 'hayirli_olsun', 'hayvan', 'hediye', 
  'helal', 'hep', 'hic', 'hoscakal', 'icmek', 'igne', 'ilac', 'ilgilenmemek', 'isik', 'itmek', 'iyi', 
  'kacmak', 'kahvalti', 'kalem', 'kalorifer', 'kapi', 'kardes', 'kavsak', 'kaza', 'kemer', 'keske', 
  'kim', 'kimlik', 'kira', 'kitap', 'kiyma', 'kiz', 'koku', 'kolonya', 'komur', 'kopek', 'kopru', 
  'kotu', 'kucak', 'leke', 'maas', 'makas', 'masa', 'masallah', 'melek', 'memnun_olmak', 'mendil', 
  'merdiven', 'misafir', 'mudur', 'musluk', 'nasil', 'neden', 'nerede', 'nine', 'ocak', 'oda', 'odun', 
  'ogretmen', 'okul', 'olimpiyat', 'olmaz', 'olur', 'onlar', 'orman', 'oruc', 'ozur_dilemek', 'pamuk', 
  'pantolon', 'para', 'pastirma', 'patates', 'pazar', 'pazartesi', 'pencere', 'persembe', 'piknik', 
  'polis', 'psikoloji', 'rica_etmek', 'saat', 'sabun', 'salca', 'sali', 'sampiyon', 'sapka', 'savas', 
  'seker', 'selam', 'semsiye', 'sen', 'senet', 'serbest', 'ses', 'sevmek', 'seytan', 'sinir', 'siz', 
  'soylemek', 'soz', 'sut', 'tamam', 'tarak', 'tarih', 'tatil', 'tatli', 'tavan', 'tehlike', 'telefon', 
  'terazi', 'terzi', 'tesekkur', 'tornavida', 'turkiye', 'turuncu', 'tuvalet', 'un', 'uzak', 'uzgun', 
  'var', 'vergi', 'yakin', 'yalniz', 'yanlis', 'yapmak', 'yarabandi', 'yardim', 'yarin', 'yasak', 
  'yastik', 'yatak', 'yavas', 'yemek', 'yemek_pisirmek', 'yildiz', 'yok', 'yol', 'yorgun', 'yumurta', 
  'zaman', 'zor'
  ];

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      options.addDelegate(XNNPackDelegate());
      _interpreter = await Interpreter.fromAsset(
        'assets/sign_model.tflite',
        options: options,
      );
      print('Model yüklendi ✓');
    } catch (e) {
      print('Model yüklenemedi: $e');
    }
  }


  String predict(List<List<double>> sequence) {
    if (_interpreter == null) return 'Model yüklenmedi';

    // Modelimiz artık tam olarak [1, 30, 225] boyutunda bir giriş bekliyor.
    // Gelen sequence 30 kare (frame) olmalı, her kare 225 değer içermeli.
    if (sequence.length != 30 || sequence[0].length != 225) {
      return 'Veri boyutu hatalı';
    }

    // Eğer karelerin çoğunda kişi algılanmadıysa (pose koordinatları sıfırsa)
    // boşuna tahmin yapıp "KUCAK" sonucunu vermesin.
    bool hasPerson = false;
    for (int i = 0; i < sequence.length; i++) {
      if (sequence[i][0] != 0.0 || sequence[i][1] != 0.0) {
        hasPerson = true;
        break;
      }
    }
    
    if (!hasPerson) {
      return 'KİŞİ BEKLENİYOR...';
    }

    final input = [sequence]; // shape: [1, 30, 225]
    final output = List.generate(1, (_) => List.filled(226, 0.0)); // 226 sınıf

    _interpreter!.run(input, output);

    int maxIdx = 0;
    double maxVal = output[0][0];
    for (int i = 1; i < 226; i++) {
      if (output[0][i] > maxVal) {
        maxVal = output[0][i];
        maxIdx = i;
      }
    }
    
    // Gerçek kelimeyi listeden çekiyoruz
    String predictedWord = labels[maxIdx].replaceAll('_', ' ').toUpperCase();
    
    // YENİ: Stabilizasyon için skoru ve kelimeyi özel formatta döndürüyoruz
    return '$predictedWord|${maxVal.toStringAsFixed(3)}';
  }

  void dispose() {
    _interpreter?.close();
  }
}
