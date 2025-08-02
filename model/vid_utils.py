#---------------- IMPORTS -----------------------

from PIL import Image
import os
import mahotas
import cv2
import numpy as np
import mediapipe as mp
import shutil
import tempfile

from tensorflow.keras.models import Model
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.applications.efficientnet import preprocess_input
from tensorflow.keras.preprocessing import image
from skimage.io import imread
from skimage.color import rgb2gray
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences

from flask import jsonify
import cy_sf_par  


#----------- FEATURE EXTRACTION ------------------------


base_model = EfficientNetB0(include_top=False, input_shape=(224, 224, 3), pooling='avg')
eff_model = Model(inputs=base_model.input, outputs=base_model.output)
FEATURE_SIZE = base_model.output_shape[-1]  

ZERN_ORDER = 8
ZERN_RADIUS = 200  
ZERN_FEATURE_SIZE = len(mahotas.features.zernike_moments(np.ones((400, 400), dtype=bool), radius=ZERN_RADIUS, degree=ZERN_ORDER))

def extract_eff_features(img_path):
    try:
        img = Image.open(img_path).convert('RGB').resize((224, 224))
        x = image.img_to_array(img)
        x = np.expand_dims(x, axis=0)
        x = preprocess_input(x)
        features = eff_model.predict(x, verbose=0)
        return features.flatten()
    except Exception as e:
        print(f"Error processing {img_path}: {e}")
        return np.zeros(FEATURE_SIZE)

def extract_zernike_features(img_path):
    try:
        img = imread(img_path)
        img_gray = rgb2gray(img)

        if img_gray.shape != (400, 400):
            print(f"Warning: {img_path} is not 400x400, found {img_gray.shape}")

        
        binarized = img_gray > img_gray.mean()

        features = mahotas.features.zernike_moments(binarized, radius=ZERN_RADIUS, degree=ZERN_ORDER)
        return np.array(features[:ZERN_FEATURE_SIZE])
    except Exception as e:
        print(f"Zernike error processing {img_path}: {e}")
        return np.zeros(ZERN_FEATURE_SIZE)




#----------------- FRAME PROCESSING ----------------------


def process_frame_combined(frame_dir):

    left_eff = np.zeros(FEATURE_SIZE)
    right_eff = np.zeros(FEATURE_SIZE)

    left_zern = [np.zeros(ZERN_FEATURE_SIZE)] * 6
    right_zern = [np.zeros(ZERN_FEATURE_SIZE)] * 6


    left_hand_dir = os.path.join(frame_dir, 'left_hand')
    if os.path.exists(left_hand_dir):

        left_img = next((f for f in os.listdir(left_hand_dir) if f.endswith('.png') and not f.startswith('point')), None)
        if left_img:
            left_eff = extract_eff_features(os.path.join(left_hand_dir, left_img))

        results_dir = os.path.join(left_hand_dir, 'results')
        if os.path.exists(results_dir):
            diagram_files = sorted([f for f in os.listdir(results_dir) if f.startswith('results-') and f.endswith('.png')])[:6]
            left_zern = [extract_zernike_features(os.path.join(results_dir, f)) for f in diagram_files]
            # Padding if fewer than 6
            left_zern += [np.zeros(ZERN_FEATURE_SIZE)] * (6 - len(left_zern))

    # --- Process Right Hand ---
    right_hand_dir = os.path.join(frame_dir, 'right_hand')
    if os.path.exists(right_hand_dir):
        # EfficientNet
        right_img = next((f for f in os.listdir(right_hand_dir) if f.endswith('.png') and not f.startswith('point')), None)
        if right_img:
            right_eff = extract_eff_features(os.path.join(right_hand_dir, right_img))

        # Zernike Diagrams
        results_dir = os.path.join(right_hand_dir, 'results')
        if os.path.exists(results_dir):
            diagram_files = sorted([f for f in os.listdir(results_dir) if f.startswith('results-') and f.endswith('.png')])[:6]
            right_zern = [extract_zernike_features(os.path.join(results_dir, f)) for f in diagram_files]
            # Padding if fewer than 6
            right_zern += [np.zeros(ZERN_FEATURE_SIZE)] * (6 - len(right_zern))

    # --- Combine Features ---
    # EfficientNet features: shape (2 * FEATURE_SIZE,)
    combined_eff = np.concatenate([left_eff, right_eff], axis=0)

    # Zernike features: shape (12, ZERN_FEATURE_SIZE)
    combined_zern = np.array(left_zern + right_zern)

    return combined_eff, combined_zern


def process_frame_combined_eff(frame_dir):
    # Initialize EfficientNet features
    left_eff = np.zeros(FEATURE_SIZE)
    right_eff = np.zeros(FEATURE_SIZE)

    # --- Process Left Hand ---
    left_hand_dir = os.path.join(frame_dir, 'left_hand')
    if os.path.exists(left_hand_dir):
        left_img = next((f for f in os.listdir(left_hand_dir) if f.endswith('.png') and not f.startswith('point')), None)
        if left_img:
            left_eff = extract_eff_features(os.path.join(left_hand_dir, left_img))

    # --- Process Right Hand ---
    right_hand_dir = os.path.join(frame_dir, 'right_hand')
    if os.path.exists(right_hand_dir):
        right_img = next((f for f in os.listdir(right_hand_dir) if f.endswith('.png') and not f.startswith('point')), None)
        if right_img:
            right_eff = extract_eff_features(os.path.join(right_hand_dir, right_img))

    combined_eff = np.concatenate([left_eff, right_eff], axis=0)
    return combined_eff




# ---------------- Hand landmark extraction ------------------------




def get_hand_landmarks(frame):
    results = hands.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    if results.multi_hand_landmarks:
        return results.multi_hand_landmarks[0].landmark
    return None

def distance_landmarks(l1, l2):
    return np.linalg.norm(np.array([[lm.x, lm.y] for lm in l1]) - np.array([[lm.x, lm.y] for lm in l2]))

def extract_with_landmarks(segment):
    important_frames = []
    prev_landmarks = None
    for frame in segment:
        landmarks = get_hand_landmarks(frame)
        if landmarks and (prev_landmarks is None or distance_landmarks(landmarks, prev_landmarks) > 0.05):
            important_frames.append(frame)
            prev_landmarks = landmarks
    return important_frames[:10]




#----------------- HAND SEGMENTATION  ----------------------

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=True, max_num_hands=2)

def segment_hands_from_frame(frame):
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = hands.process(img_rgb)

    left_mask = np.zeros((frame.shape[0], frame.shape[1]), dtype=np.uint8)
    right_mask = np.zeros((frame.shape[0], frame.shape[1]), dtype=np.uint8)

    if results.multi_hand_landmarks and results.multi_handedness:
        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            label = handedness.classification[0].label
            points = []
            for lm in hand_landmarks.landmark:
                x = int(lm.x * frame.shape[1])
                y = int(lm.y * frame.shape[0])
                points.append([x, y])

            points = np.array(points, np.int32).reshape((-1, 1, 2))
            if label == 'Left':
                cv2.polylines(left_mask, [points], isClosed=True, color=255, thickness=1)
            elif label == 'Right':
                cv2.polylines(right_mask, [points], isClosed=True, color=255, thickness=1)

    left_mask_resized = cv2.resize(left_mask, (0, 0), fx=2.0, fy=2.0, interpolation=cv2.INTER_NEAREST)
    right_mask_resized = cv2.resize(right_mask, (0, 0), fx=2.0, fy=2.0, interpolation=cv2.INTER_NEAREST)

    return left_mask_resized, right_mask_resized

def segment_hands_from_frame_eff(frame, output_dir):
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = hands.process(img_rgb)

    if results.multi_hand_landmarks and results.multi_handedness:
        for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
            label = handedness.classification[0].label
            points = []
            for lm in hand_landmarks.landmark:
                x = int(lm.x * frame.shape[1])
                y = int(lm.y * frame.shape[0])
                points.append([x, y])

            points = np.array(points, np.int32).reshape((-1, 1, 2))
            mask = np.zeros((frame.shape[0], frame.shape[1]), dtype=np.uint8)
            cv2.polylines(mask, [points], isClosed=True, color=255, thickness=1)
            mask_resized = cv2.resize(mask, (0, 0), fx=2.0, fy=2.0, interpolation=cv2.INTER_NEAREST)

            hand_dir = os.path.join(output_dir, f'{label.lower()}_hand')
            os.makedirs(hand_dir, exist_ok=True)
            cv2.imwrite(os.path.join(hand_dir, f'{label.lower()}_hand.png'), mask_resized)



#----------------- DIAGRAM GENERATION ----------------------



def segment_and_generate_diagrams(frame, output_dir):
    left_img, right_img = segment_hands_from_frame(frame)
    sf = cy_sf_par.SizeFunction()

    if np.any(left_img):
        left_dir = os.path.join(output_dir, 'left_hand')
        os.makedirs(os.path.join(left_dir, 'results'), exist_ok=True)
        left_path = os.path.join(left_dir, 'left_hand.png')
        cv2.imwrite(left_path, left_img)
        sf.mainn(imagefile=left_path, ang=200, result_path=os.path.join(left_dir, 'results'))

    if np.any(right_img):
        right_dir = os.path.join(output_dir, 'right_hand')
        os.makedirs(os.path.join(right_dir, 'results'), exist_ok=True)
        right_path = os.path.join(right_dir, 'right_hand.png')
        cv2.imwrite(right_path, right_img)
        sf.mainn(imagefile=right_path, ang=200, result_path=os.path.join(right_dir, 'results'))
        
        
        
        
        
        
        
#----------------- PREDICTION  ----------------------



max_seq_len = 10

label_map_letters = {
    'ا': 0, 'ب': 1, 'ت': 2, 'ث': 3, 'ج': 4, 'ح': 5, 'خ': 6, 'د': 7, 'ذ': 8, 'ر': 9,
    'ز': 10, 'س': 11, 'ش': 12, 'ص': 13, 'ض': 14, 'ط': 15, 'ظ': 16, 'ع': 17, 'غ': 18, 'ف': 19,
    'ق': 20, 'ك': 21, 'ل': 22, 'م': 23, 'ن': 24, 'ه': 25, 'و': 26, 'ي': 27, 'ة': 28, 'أ': 29,
    'ؤ': 30, 'ئ': 31, 'ئـ': 32, 'ء': 33, 'إ': 34, 'آ': 35, 'ى': 36, 'لا': 37, 'ال': 38
}
label_map_numbers = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    '10': 10, '20': 11, '30': 12, '40': 13, '50': 14, '60': 15, '70': 16, '80': 17, '90': 18, '100': 19,
    '200': 20, '300': 21, '400': 22, '500': 23, '600': 24, '700': 25, '800': 26, '900': 27,
    '1000': 28, '1000000': 29, '10000000': 30
}
label_map_words = {
    'يأكل': 0, 'يسمع': 1, 'يسكت': 2, 'يصعد': 3, 'يفتح': 4, 'يمشي': 5, 'يحب': 6, 'يفكر': 7, 'يساعد': 8, 'يقف': 9,
    'يدخل': 10, 'أسرة': 11, 'أب': 12, 'أم': 13, 'ناس': 14, 'جميل': 15, 'طويل': 16, 'نحيف': 17, 'خائف': 18, 'سعيد': 19,
    'حزين': 20, 'شجاع': 21, 'كريم': 22, 'كذاب': 23, 'صبر': 24, 'ذكي': 25, 'بين': 26, 'تحت': 27, 'خلف': 28, 'فوق': 29,
    'يسار': 30, 'يمين': 31, 'أهلا وسهلاً': 32, 'السلام عليكم': 33, 'شكراً': 34, 'صديق': 35, 'بيت': 36, 'مطبخ': 37,
    'سكين': 38, 'كأس': 39, 'كرسي': 40, 'تلفزيون': 41, 'مفتاح': 42, 'الله تعالى': 43, 'الحمد لله': 44, 'مهندس': 45,
    'معلم': 46, 'طباخ': 47, 'طبيب': 48, 'محام': 49
}


reverse_label_map_letters = {v: k for k, v in label_map_letters.items()}
reverse_label_map_numbers = {v: k for k, v in label_map_numbers.items()}
reverse_label_map_words = {v: k for k, v in label_map_words.items()}



def predict_sequence(model, eff_seq, zern_seq, model_type):
    eff_seq = pad_sequences([eff_seq], maxlen=max_seq_len, dtype='float32', padding='post', truncating='post')
    zern_seq = pad_sequences([zern_seq], maxlen=max_seq_len, dtype='float32', padding='post', truncating='post')
    prediction = model.predict([eff_seq, zern_seq], verbose=0)[0]
    label_index = int(np.argmax(prediction))
    confidence = float(np.max(prediction))

    if model_type == 1:
        label = reverse_label_map_letters.get(label_index, "unknown")
    elif model_type == 2:
        label = reverse_label_map_numbers.get(label_index, "unknown")
    elif model_type == 3:
        label = reverse_label_map_words.get(label_index, "unknown")
    else:
        label = "unknown"

    return label, confidence


def predict_sequence_eff(model, eff_seq, model_type):
    eff_seq = pad_sequences([eff_seq], maxlen=max_seq_len, dtype='float32', padding='post', truncating='post')
    prediction = model.predict(eff_seq, verbose=0)[0]
    label_index = int(np.argmax(prediction))
    confidence = float(np.max(prediction))

    if model_type == 1:
        label = reverse_label_map_letters.get(label_index, "unknown")
    elif model_type == 2:
        label = reverse_label_map_numbers.get(label_index, "unknown")
    elif model_type == 3:
        label = reverse_label_map_words.get(label_index, "unknown")
    else:
        label = "unknown"

    return label, confidence






#----------------- OPTICAL FLOW ----------------------



def detect_gesture_starts_optical_flow(folder_path, threshold_motion):
    frame_files = sorted([f for f in os.listdir(folder_path) if f.endswith(('.png', '.jpg', '.jpeg'))])
    frame_paths = [os.path.join(folder_path, f) for f in frame_files]

    gesture_starts = [0] 
    prev_gray = None
    motion_scores = []

    for path in frame_paths:
        frame = cv2.imread(path)
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        if prev_gray is not None:
            flow = cv2.calcOpticalFlowFarneback(prev_gray, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0)
            magnitude, _ = cv2.cartToPolar(flow[..., 0], flow[..., 1])
            motion_score = np.mean(magnitude)
            motion_scores.append(motion_score)
        else:
            motion_scores.append(0)
        prev_gray = gray

    is_moving = [score > threshold_motion for score in motion_scores]
    start_detected = True

    for i, moving in enumerate(is_moving):
        if moving and not start_detected:
            gesture_starts.append(i)
            start_detected = True
        elif not moving:
            start_detected = False

    return gesture_starts




#----------------- FRAME EXTRACTON ----------------------



def extract_frames_from_video(video_path, output_folder):
    if os.path.exists(output_folder):
        shutil.rmtree(output_folder)
    os.makedirs(output_folder)
    
    cap = cv2.VideoCapture(video_path)
    frame_count = 0
    saved_count = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
            
        frame_path = os.path.join(output_folder, f"frame_{frame_count:04d}.jpg")
        cv2.imwrite(frame_path, frame)
        saved_count += 1
        frame_count += 1
    
    cap.release()
    return saved_count
