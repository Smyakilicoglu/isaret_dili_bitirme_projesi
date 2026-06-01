# 2. Aşama: Model Eğitimi (Colab İçin)
# Bu kodu birinci aşama bittikten sonra yeni bir Colab hücresinde çalıştırın.

import os
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, Masking
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split

BASE_DIR = "/content/drive/MyDrive/AUTSL_Dataset"
LANDMARKS_DIR = os.path.join(BASE_DIR, "landmarks")
TRAIN_LABELS_PATH = os.path.join(BASE_DIR, "train", "train_labels.csv")

# Etiketleri Yükleme Fonksiyonu
def load_labels(csv_path):
    try:
        labels_df = pd.read_csv(csv_path, header=None, names=["video_id", "class_id"])
        # Baştaki veya sondaki boşlukları temizle
        labels_df['video_id'] = labels_df['video_id'].str.strip()
        return dict(zip(labels_df['video_id'], labels_df['class_id']))
    except Exception as e:
        print(f"Etiketler okunurken hata ({csv_path}): {e}")
        return {}

print("Train etiketleri yükleniyor...")
train_label_map = load_labels(os.path.join(BASE_DIR, "train", "train_labels.csv"))

print("Val etiketleri yükleniyor...")
# Olası dosya yolları (hem ana klasör, hem iç klasör, hem zip versiyonu)
val_possible_paths = [
    os.path.join(BASE_DIR, "val", "validation_labels", "ground_truth.csv"), # Sizin ekran görüntünüzdeki DOĞRU YOL!
    os.path.join(BASE_DIR, "val", "validation_labels ground_truth.csv"),
    os.path.join(BASE_DIR, "val", "validation_labels.csv"),
    os.path.join(BASE_DIR, "val", "validation_labels.zip"),
    os.path.join(BASE_DIR, "val", "val", "validation_labels ground_truth.csv"),
    os.path.join(BASE_DIR, "val", "val", "validation_labels.csv")
]

val_csv_path = None
for p in val_possible_paths:
    if os.path.exists(p):
        val_csv_path = p
        break

if val_csv_path:
    print(f"Val etiketi bulundu: {val_csv_path}")
    val_label_map = load_labels(val_csv_path)
else:
    print("HATA: Val etiket dosyası hiçbir konumda bulunamadı!")
    val_label_map = {}

num_classes = 226 # AuTSL'de 226 işaret var

# Maksimum kare sayısı (Padding için)
MAX_FRAMES = 30 # Flutter tarafı ile eşleşmesi için 30'a ayarlandı
FEATURE_DIM = 225 # 99 (pose) + 63 (lh) + 63 (rh)

def load_data(split_name, label_map):
    data_dir = os.path.join(LANDMARKS_DIR, split_name)
    X, y = [], []
    
    if not os.path.exists(data_dir):
        print(f"{split_name} klasörü bulunamadı: {data_dir}")
        return np.array(X), np.array(y)
        
    files = os.listdir(data_dir)
    print(f"{split_name} klasöründe {len(files)} adet .npy dosyası bulundu. İşleniyor...")
    
    for i, file in enumerate(files):
        video_id = file.replace("_color.npy", "").strip()
        
        if video_id in label_map:
            filepath = os.path.join(data_dir, file)
            sequence = np.load(filepath)
            
            # Padding veya Truncating
            if len(sequence) > MAX_FRAMES:
                sequence = sequence[:MAX_FRAMES]
            else:
                pad_len = MAX_FRAMES - len(sequence)
                sequence = np.pad(sequence, ((0, pad_len), (0, 0)), mode='constant')
                
            X.append(sequence)
            y.append(label_map[video_id])
            
        if (i+1) % 1000 == 0:
            print(f"{split_name}: {i+1} / {len(files)} dosya yüklendi.")
            
    return np.array(X), np.array(y)

print("Eğitim verileri yükleniyor...")
X_train, y_train = load_data("train", train_label_map)
y_train = to_categorical(y_train, num_classes=num_classes)

print("Doğrulama (Val) verileri yükleniyor...")
X_val, y_val = load_data("val", val_label_map)

# Eğer val klasörü boşsa veya val_labels.csv yoksa, mecburen train'den birazını ayırıyoruz
if len(X_val) == 0:
    print("UYARI: Val verisi bulunamadı! Train verisinden %10 ayrılıyor...")
    X_train, X_val, y_train, y_val = train_test_split(X_train, y_train, test_size=0.1, random_state=42)
else:
    y_val = to_categorical(y_val, num_classes=num_classes)

print(f"Eğitim verisi (Train) boyutu: {X_train.shape}")
print(f"Doğrulama verisi (Val) boyutu: {X_val.shape}")

# Modeli Oluştur (Hafif bir LSTM)
model = Sequential()
# MASKING KATMANI KALDIRILDI: Çünkü Flutter'daki TFLite eklentisi (FlexOps) bu katmanı desteklemiyor!
# unroll=True EKLENDİ: LSTM'in dinamik liste (TensorListReserve) oluşturmasını tamamen engeller,
# modeli statik hale getirip %100 Flutter uyumlu (sadece temel TFLite işlemleri) yapar!
model.add(LSTM(64, return_sequences=True, activation='relu', input_shape=(MAX_FRAMES, FEATURE_DIM), unroll=True))
model.add(LSTM(128, return_sequences=False, activation='relu', unroll=True))
model.add(Dense(64, activation='relu'))
model.add(Dropout(0.5))
model.add(Dense(num_classes, activation='softmax'))

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['categorical_accuracy'])
model.summary()

# Eğitimi Başlat
print("Eğitim başlıyor...")
history = model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=50, batch_size=32)

# Modeli Kaydet
model.save(os.path.join(BASE_DIR, 'sign_model.h5'))

# TFLite'a Çevir
print("TFLite formatına çevriliyor...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
# Mobil optimizasyonları
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS, tf.lite.OpsSet.SELECT_TF_OPS]
converter._experimental_lower_tensor_list_ops = False

tflite_model = converter.convert()

tflite_path = os.path.join(BASE_DIR, 'sign_model.tflite')
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)

print(f"Model başarıyla TFLite olarak kaydedildi: {tflite_path}")
