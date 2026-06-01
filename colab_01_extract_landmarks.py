import os
import cv2
import numpy as np
import urllib.request
import mediapipe as mp
from google.colab import drive

# Google Drive'ı bağla
drive.mount('/content/drive')

# Veri seti yolları
BASE_DIR = "/content/drive/MyDrive/AUTSL_Dataset"
TRAIN_DIR = os.path.join(BASE_DIR, "train")
VAL_DIR = os.path.join(BASE_DIR, "val")
TEST_DIR = os.path.join(BASE_DIR, "test")
LANDMARKS_DIR = os.path.join(BASE_DIR, "landmarks")

# Klasörleri oluştur
os.makedirs(os.path.join(LANDMARKS_DIR, "train"), exist_ok=True)
os.makedirs(os.path.join(LANDMARKS_DIR, "val"), exist_ok=True)
os.makedirs(os.path.join(LANDMARKS_DIR, "test"), exist_ok=True)

# --- MediaPipe Tasks API Modellerini İndir ---
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

pose_model_path = 'pose_landmarker_full.task'
if not os.path.exists(pose_model_path):
    print("Pose modeli indiriliyor...")
    urllib.request.urlretrieve('https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task', pose_model_path)

hand_model_path = 'hand_landmarker.task'
if not os.path.exists(hand_model_path):
    print("Hand (El) modeli indiriliyor...")
    urllib.request.urlretrieve('https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task', hand_model_path)

# --- MediaPipe Ayarları ---
BaseOptions = python.BaseOptions
VisionRunningMode = vision.RunningMode

pose_options = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=pose_model_path),
    running_mode=VisionRunningMode.VIDEO,
    output_segmentation_masks=False
)

hand_options = vision.HandLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=hand_model_path),
    running_mode=VisionRunningMode.VIDEO,
    num_hands=2 # İki eli de bul
)

def extract_keypoints(pose_result, hand_result):
    # Pose: 33 eklem * 3 değer (x, y, z) = 99
    pose = np.zeros(33 * 3)
    if pose_result and pose_result.pose_landmarks:
        pose = np.array([[lm.x, lm.y, lm.z] for lm in pose_result.pose_landmarks[0]]).flatten()

    # Eller: 21 eklem * 3 değer = 63 (Sol ve Sağ ayrı ayrı)
    lh = np.zeros(21 * 3)
    rh = np.zeros(21 * 3)
    
    if hand_result and hand_result.hand_landmarks:
        for idx, handedness in enumerate(hand_result.handedness):
            label = handedness[0].category_name # "Left" veya "Right"
            landmarks = np.array([[lm.x, lm.y, lm.z] for lm in hand_result.hand_landmarks[idx]]).flatten()
            if label == "Left":
                lh = landmarks
            elif label == "Right":
                rh = landmarks
                
    # Toplam: 99 + 63 + 63 = 225 değer (Tam istediğimiz format)
    combined = np.concatenate([pose, lh, rh])
    
    if combined.shape[0] != 225:
        combined = np.pad(combined, (0, max(0, 225 - combined.shape[0])), 'constant')[:225]
        
    return combined

def process_video(video_path, save_path):
    if os.path.exists(save_path):
        return # Zaten işlenmiş
        
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Hata: Video açılamadı: {video_path}")
        return

    frames_data = []
    
    # Her video için yepyeni bir landmarker açıyoruz
    with vision.PoseLandmarker.create_from_options(pose_options) as pose_landmarker, \
         vision.HandLandmarker.create_from_options(hand_options) as hand_landmarker:
        
        current_frame_index = 0
        fixed_time_increment_ms = 33 # Her kare arası 33ms (Yaklaşık 30 FPS)
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            timestamp_ms = current_frame_index * fixed_time_increment_ms
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            
            # Vücut ve Elleri ayrı ayrı bul
            pose_result = pose_landmarker.detect_for_video(mp_image, timestamp_ms)
            hand_result = hand_landmarker.detect_for_video(mp_image, timestamp_ms)
            
            # Sonuçları 225'lik diziye dönüştür
            keypoints = extract_keypoints(pose_result, hand_result)
            frames_data.append(keypoints)
            
            current_frame_index += 1
            
    cap.release()
    
    if len(frames_data) > 0:
        np.save(save_path, np.array(frames_data))

def process_directory(directory, split_name):
    # İç içe klasörleri çöz (val/val veya test/test)
    inner_dir = os.path.join(directory, split_name)
    video_dir = inner_dir if os.path.isdir(inner_dir) else directory

    print(f"\n{split_name} dizini işleniyor... (Okunan: {video_dir})")
    videos = [f for f in os.listdir(video_dir) if f.endswith("_color.mp4")]
    
    if len(videos) == 0:
        print(f"UYARI: {video_dir} içinde hiç video bulunamadı!")
        return

    for i, video in enumerate(videos):
        video_path = os.path.join(video_dir, video)
        save_path = os.path.join(LANDMARKS_DIR, split_name, video.replace(".mp4", ".npy"))
        
        process_video(video_path, save_path)
        
        if (i+1) % 100 == 0:
            print(f"{i+1} / {len(videos)} video tamamlandı.")

# İşlemi Başlat
print("DİKKAT: Yeni Tasks API kullanılıyor. Eller başarıyla entegre edildi!")
# process_directory(TRAIN_DIR, "train") # Tamamlandığı için kapatıldı
process_directory(VAL_DIR, "val")
# process_directory(TEST_DIR, "test") # Sunum aciliyeti nedeniyle şimdilik atlandı
print("\nTüm videolar başarıyla işlendi ve .npy olarak kaydedildi!")
