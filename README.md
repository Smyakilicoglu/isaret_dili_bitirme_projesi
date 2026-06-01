<p align="center">
  <img src="https://github.com/user-attachments/assets/d1a7402a-7795-4b53-9696-4b534fdc11ea" width="228" height="262" alt="image">
</p>

<img width="1419" height="850" alt="image" src="https://github.com/user-attachments/assets/f14a1337-e9b8-4fe4-b0d9-d02a56ca2bd0" />

## 1. Proje Genel Hatlarıyla Ne Yapıyor?
Bu proje, işitme engelli bireylerin iletişim bariyerlerini kaldırmak amacıyla geliştirilmiş **gerçek zamanlı (real-time)** bir yapay zeka mobil uygulamasıdır. 
Sistem, telefonun kamerasından gelen görüntüleri saniyede 30 kare (FPS) hızında analiz eder, ekrandaki kişinin vücut iskeletini (pose) çıkartır ve bu hareket dizilimini yapay zeka modeline besleyerek o an yapılan işaret dilindeki kelimeyi anında ekrana yansıtır. Sistemin en büyük avantajı **internetsiz (offline)** çalışabilmesidir; tüm yapay zeka hesaplamaları telefonun kendi işlemcisi üzerinde gerçekleşir.
---
## 2. Süreç Boyunca Hangi Dilleri Neden Kullandık?
### 🐍 Python (Yapay Zeka ve Veri İşleme)
*   **Neden Kullandık?** Yapay zeka ve derin öğrenme ekosisteminin (TensorFlow, Keras) endüstri standardı olduğu için. 
*   **Ne Yaptık?** Google Colab üzerinde devasa video veri setini (AUTSL) işlemek, insan iskeletlerini çıkarmak ve yapay zeka modelini eğitmek için kullandık.
### 🎯 Dart & Flutter (Mobil Uygulama)
*   **Neden Kullandık?** Tek bir kod yazarak hem iOS hem de Android'de yerel (native) hızında çalışan bir uygulama üretebildiği için. Ayrıca Flutter'ın kamerayı donanım seviyesinde kontrol etme yeteneği gerçek zamanlı görüntü işleme için kusursuzdu.
*   **Ne Yaptık?** Kamerayı yönetecek, yapay zekayı telefonun içine gömecek ve kullanıcı arayüzünü oluşturacak tüm ön yüz mimarisini geliştirdik.
---
## 3. Kullanılan Kütüphaneler ve Mühendislik Amacımız
> [!TIP]
> **Jüriyi Etkileyecek Cümle:** *"Biz yapay zekaya video veya fotoğraf verip telefonu yormadık. İnsanı matematiksel koordinatlara çevirip donanım dostu bir sistem tasarladık."*
### Google MediaPipe (Python Tarafında)
*   **Amacımız:** Yapay zekaya doğrudan ağır ".mp4" videolarını beslemek, telefonun işlemcisini saniyeler içinde eritirdi. Biz MediaPipe kullanarak videolardaki insanı 3 boyutlu bir uzayda **(X, Y, Z)** koordinat noktalarına (landmark) indirdik. Yani yapay zekamız pikselleri değil, saniyede 30 karelik "eklem açılarını" öğrendi.
### Keras & TensorFlow (LSTM Ağı)
*   **Neden LSTM Kullandık?** İşaret dili tek bir fotoğrafla anlaşılamaz, bu bir **zaman serisidir (time-series)**. LSTM (Long Short-Term Memory) ağları, geçmişi hatırlayabilen özel bir yapay zeka türüdür. Hareketin 1. saniyesindeki el konumu ile 30. saniyesindeki konumu arasındaki ilişkiyi kurması için LSTM mimarisini tercih ettik.
### Google ML Kit Pose Detection (Flutter Tarafında)
*   **Amacımız:** Uygulama kamerası açıldığında kullanıcının omuz, dirsek ve bilek gibi noktalarını gerçek zamanlı bulmak. ML Kit, Google'ın mobil cihazlar için özel optimize ettiği ve internet gerektirmeyen (on-device) en hızlı iskelet tanıma motorudur.
### tflite_flutter (TensorFlow Lite)
*   **Amacımız:** Python'da devasa sunucularda (Colab) eğittiğimiz ve 226 kelimeyi tanıyan zeki modelimizi, telefonda çalışabilecek minik bir `.tflite` (240 KB) dosyasına dönüştürdük. Bu kütüphane sayesinde modelimiz telefonun cebine sığdı.
---
## 4. Karşılaşılan Zorluklar ve Çözümler (Jüriyi Büyüleyecek Kısım)
Sunumda bu üç teknik engeli nasıl aştığınızı anlatmanız sizi jürinin gözünde bir "Problem Çözücü Mühendis" yapacaktır:
> [!IMPORTANT]
> **Zorluk 1: Dinamik Tensor (FlexOps) Desteklenmeme Sorunu**
> **Sorun:** Python'da kurduğumuz LSTM yapay zekası dinamik diziler kullanıyordu (Masking). Ancak Flutter'ın TFLite motoru Android cihazlarda "TensorListReserve" gibi dinamik işlemleri (FlexOps) desteklemiyordu. Bu yüzden uygulama modeli reddedip çöküyordu.
> **Mühendislik Çözümümüz:** Modelin mimarisini değiştirdik! LSTM katmanlarına `unroll=True` parametresini ekleyerek 30 karelik hareket dizilimini **Statik bir Grafa (Static Graph)** dönüştürdük. Böylece özel C++ derlemelerine gerek kalmadan modeli %100 mobil uyumlu hale getirdik.

> [!WARNING]
> **Zorluk 2: Koordinat Skalası (Normalization) Uyuşmazlığı**
> **Sorun:** Python'daki MediaPipe iskelet koordinatlarını `0.0 ile 1.0` arasında oransal (normalize) olarak veriyordu. Ancak Flutter'daki ML Kit, kameradan `1280x720` gibi devasa Piksel koordinatları gönderiyordu. Yapay zeka hiç görmediği büyüklükte sayılar alınca rastgele ve hatalı kelimeler fırlatmaya başladı.
> **Mühendislik Çözümümüz:** Telefondan gelen ham piksel verilerini doğrudan yapay zekaya vermek yerine, araya bir "Normalizasyon Filtresi" yazdık. `X / Ekran Genişliği` formülüyle tüm pikselleri `0.0 - 1.0` aralığına sıkıştırıp yapay zekayı kandırdık ve isabet oranını düzelttik.

> [!TIP]
> **Zorluk 3: Kayan Pencere (Sliding Window) ve Stabilizasyon**
> **Sorun:** Kamera saniyede 30 kare çekiyor. Eğer hareketi 15. karede yapmaya başlarsak, sistem cümlenin yarısını kesip anlamıyordu. Ayrıca kollarımızı aşağı indirme hareketimizi "Kaçmak" kelimesi sanıyordu.
> **Mühendislik Çözümümüz:** Hafızayı tamamen silmek yerine **"Sliding Window (Kayan Pencere)"** algoritması kurduk. Bellekteki en eski 5 kareyi silip yenilerini ekleyerek sürekli akan bir pencere yarattık. Üzerine bir de **"Güvenlik Eşiği (Threshold)"** ekleyerek, modelin %60'ın altında emin olduğu hareketleri filtreleyip (Hareket analiz ediliyor diyerek) rastgele kelime üretimini engelledik.

# 🧠 Google Colab (Yapay Zeka) Kodlarının Adım Adım Açıklaması
Bu rapor, jüriye yapay zeka modelini nasıl eğittiğinizi ve yazdığınız Python kodlarındaki mühendislik mantığını açıklamanız için hazırlanmıştır. Projemiz Colab üzerinde iki ana aşamadan (iki ayrı kod dosyasından) oluşmaktadır.
---
## BÖLÜM 1: Veri İşleme ve İskelet Çıkarma (`colab_01_extract_landmarks.py`)
Amacımız: Ağır ".mp4" videolarını yapay zekaya doğrudan verip sistemi çökertmek yerine, videolardaki kişinin sadece "iskeletini" (koordinatlarını) çıkarıp yapay zekaya matematiği öğretmektir.
### 1. Drive Bağlantısı ve MediaPipe Kurulumu
```python
drive.mount('/content/drive')
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
```
**Ne Yaptık?** Google Drive'daki veri setimize bağlandık ve Google'ın geliştirdiği en gelişmiş insan iskeleti çıkarma kütüphanesi olan **MediaPipe Tasks API**'yi projemize dahil ettik.
### 2. İskelet (Landmark) Koordinatlarını Çıkarma
```python
def extract_keypoints(pose_result, hand_result):
    # Pose: 33 eklem * 3 değer (x, y, z) = 99
    # Eller: 21 eklem * 3 değer = 63 (Sol ve Sağ ayrı ayrı)
    combined = np.concatenate([pose, lh, rh]) # Toplam 225 değer
```
**Ne Yaptık?** Her bir video karesi (frame) için kişinin 33 vücut noktasını (omuz, dirsek vb.) ve her iki elindeki 21'er eklem noktasını çıkardık. Her nokta 3 boyutlu (X, Y, Z) olduğu için toplamda tam olarak **225 sayılık** dev bir koordinat dizisi elde ettik.
### 3. Numpy Dizisi Olarak Kaydetme
```python
np.save(save_path, np.array(frames_data))
```
**Ne Yaptık?** Çıkardığımız bu koordinatları bilgisayarın çok hızlı okuyabileceği `.npy` (NumPy) dosyaları olarak kaydettik. Bu sayede yapay zekayı eğitirken saatlerce video işlemek yerine, mili-saniyeler içinde sadece sayıları (matrisleri) okuyarak muazzam bir zaman tasarrufu sağladık.
---
## BÖLÜM 2: Yapay Zeka Modelinin Eğitimi (`colab_02_train_model.py`)
Amacımız: Kaydettiğimiz o 225 noktalı hareket dizilimlerini (X) alıp, o hareketin hangi kelimeye (Y) ait olduğunu makineye öğretmek (Deep Learning).
### 1. Verilerin Pad Edilmesi (Sabit 30 Kare)
```python
if len(data) > 30:
    data = data[:30] # Uzunsa kırp
else:
    data = np.pad(data, ((0, 30 - len(data)), (0,0)), 'constant') # Kısaysa sıfır ekle
```
**Ne Yaptık?** İşaret dilinde bazı hareketler kısa (10 kare), bazıları uzundur (40 kare). Yapay zeka ağları sabit boyutlu veri bekler. Bu kodla tüm hareketleri mükemmel bir standart olan **30 kareye (1 saniyeye)** sabitledik. Eksik olanlara boşluk (0) ekledik, uzunları kırptık.
### 2. Sinir Ağının (LSTM) Kurulması
```python
model = Sequential()
model.add(LSTM(64, return_sequences=True, activation='relu', unroll=True, input_shape=(30, 225)))
model.add(LSTM(128, return_sequences=False, activation='relu', unroll=True))
model.add(Dense(64, activation='relu'))
model.add(Dense(NUM_CLASSES, activation='softmax')) # 226 Kelime
```
**Ne Yaptık?** 
*   **LSTM Kullanımı:** Hareketi fotoğraflar gibi tek tek değil, bir "zaman serisi" olarak hatırlaması için LSTM (Uzun Kısa-Vadeli Hafıza) ağı kurduk.
*   **Mühendislik Harikası (unroll=True):** Bu parametre en kritik karardı. Flutter'daki mobil yapay zeka (TFLite), değişken zamanlı döngüleri (FlexOps) desteklemiyordu. `unroll=True` diyerek o döngüyü düzleştirdik ve statik (sabit) bir grafiğe çevirerek modelin mobil telefonda sıfır hatayla çalışmasını garantiledik.
*   **Softmax:** En sonda 226 kelime içinden en yüksek ihtimali olanı seçmesi için `softmax` fonksiyonunu kullandık.
### 3. Modelin Eğitimi ve TFLite Dönüşümü
```python
model.compile(optimizer='Adam', loss='categorical_crossentropy', metrics=['categorical_accuracy'])
model.fit(X_train, y_train, epochs=70, batch_size=32, validation_data=(X_val, y_val))
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
```
**Ne Yaptık?** Modeli çok popüler olan `Adam` optimizasyon algoritmasıyla eğittik. Eğitim bittikten sonra, koca devasa modeli bilgisayardan telefona sokabilmek için onu `TFLite` formatına (Google'ın mobil yapay zeka formatı) dönüştürdük ve sadece 240 KB'lık bir ağırlık (beyin) dosyası elde ettik.
