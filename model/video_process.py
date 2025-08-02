from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences
import tempfile
import os
import cv2
import shutil

from vid_utils import (
    extract_frames_from_video,
    extract_with_landmarks,
    segment_and_generate_diagrams,
    process_frame_combined,
    predict_sequence,
    detect_gesture_starts_optical_flow,
    segment_hands_from_frame_eff,
    process_frame_combined_eff,
    predict_sequence_eff,
    max_seq_len
)




#------------- LOAD MODELS --------------------------



def load_model_by_type(model_type):
    if model_type == 1:
        return load_model("model_dual_stream_letters_frames10_zern8.h5")
    elif model_type == 2:
        return load_model("model_dual_stream_numbers_frames10_zern8.h5")
    elif model_type == 3:
        return load_model("model_dual_stream_50_words_10_frames_zern8.h5")
    else:
        raise ValueError("Invalid model_type. Use 1 (letters), 2 (numbers), or 3 (words).")

def load_eff_model_by_type(model_type):
    if model_type == 1:
        return load_model("model_eff_only_letters_10_frames_zern8.h5")
    elif model_type == 2:
        return load_model("model_eff_only_numbers_10_frames_zern8.h5")
    elif model_type == 3:
        return load_model("model_eff_only_words_50_frames_10_zern8.h5")
    else:
        raise ValueError("Invalid model_type. Use 1 (letters), 2 (numbers), or 3 (words).")



#------------- EFF & ZERNIKE FEATURES ----------------


def process_video(video_path, model_type):
    model = load_model_by_type(model_type)

    frame_dir = tempfile.mkdtemp()
    extract_frames_from_video(video_path, frame_dir)

    frames = []
    frame_files = sorted([f for f in os.listdir(frame_dir) if f.endswith('.jpg')])
    for frame_file in frame_files:
        frame_path = os.path.join(frame_dir, frame_file)
        frame = cv2.imread(frame_path)
        frames.append(frame)

    important_frames = extract_with_landmarks(frames)

    eff_seq, zern_seq = [], []
    for i, frame in enumerate(important_frames):
        temp_frame_dir = os.path.join(frame_dir, f"seg_{i}")
        os.makedirs(temp_frame_dir, exist_ok=True)

        try:
            segment_and_generate_diagrams(frame, temp_frame_dir)
            eff_feat, zern_feat = process_frame_combined(temp_frame_dir)
            eff_seq.append(eff_feat)
            zern_seq.append(zern_feat)
        except Exception as e:
            print(f"[⚠️] Frame {i} skipped: {e}")
            continue

    if len(eff_seq) == 0:
        shutil.rmtree(frame_dir)
        raise Exception("No valid frames")

    while len(eff_seq) < max_seq_len:
        eff_seq.append(eff_seq[-1])
        zern_seq.append(zern_seq[-1])

    predicted_label, confidence = predict_sequence(model, eff_seq, zern_seq, model_type)
    shutil.rmtree(frame_dir)
    return predicted_label



def process_video_sequence(video_path, model_type):
    model = load_model_by_type(model_type)
    WINDOW_SIZE = 10
    CONFIDENCE_THRESHOLD = 0.7
    MOTION_THRESHOLD = 2.0

    temp_dir = tempfile.mkdtemp()
    extract_frames_from_video(video_path, temp_dir)

    frames = []
    frame_files = sorted([f for f in os.listdir(temp_dir) if f.endswith('.jpg')])
    for frame_file in frame_files:
        frame_path = os.path.join(temp_dir, frame_file)
        frame = cv2.imread(frame_path)
        frames.append(frame)

    gesture_starts = detect_gesture_starts_optical_flow(temp_dir, MOTION_THRESHOLD)
    gesture_starts.append(len(frames))

    segments = []
    for i in range(len(gesture_starts) - 1):
        start = gesture_starts[i]
        end = gesture_starts[i + 1]
        segment = frames[start:end]
        if segment:
            segments.append(segment)

    final_predictions = []
    last_label = None

    for seg_idx, segment in enumerate(segments):
        segment = extract_with_landmarks(segment)
        if not segment:
            continue

        seg_dir = os.path.join(temp_dir, f"segment_{seg_idx}")
        os.makedirs(seg_dir, exist_ok=True)

        eff_seq, zern_seq = [], []

        for i, frame in enumerate(segment):
            frame_dir = os.path.join(seg_dir, f"frame_{i}")
            os.makedirs(frame_dir, exist_ok=True)

            try:
                segment_and_generate_diagrams(frame, frame_dir)
                eff_feat, zern_feat = process_frame_combined(frame_dir)
                eff_seq.append(eff_feat)
                zern_seq.append(zern_feat)
            except Exception as e:
                print(f"[⚠️] Segment {seg_idx}, Frame {i} skipped: {e}")
                continue

        if len(eff_seq) == 0:
            continue

        while len(eff_seq) < WINDOW_SIZE:
            eff_seq.append(eff_seq[-1])
            zern_seq.append(zern_seq[-1])

        label, confidence = predict_sequence(model, eff_seq, zern_seq, model_type)

        if confidence >= CONFIDENCE_THRESHOLD and label != last_label:
            final_predictions.append({
                "segment": seg_idx,
                "label": label,
                "confidence": float(confidence)
            })
            last_label = label

    sentence = " ".join([pred["label"] for pred in final_predictions])
    shutil.rmtree(temp_dir)
    return sentence





#-------------- EFF FEATURES ONLY -------------------



def process_video_eff(video_path, model_type):
    model = load_eff_model_by_type(model_type)

    frame_dir = tempfile.mkdtemp()
    extract_frames_from_video(video_path, frame_dir)

    frames = []
    frame_files = sorted([f for f in os.listdir(frame_dir) if f.endswith('.jpg')])
    for frame_file in frame_files:
        frame_path = os.path.join(frame_dir, frame_file)
        frame = cv2.imread(frame_path)
        frames.append(frame)

    important_frames = extract_with_landmarks(frames)

    eff_seq = []
    for i, frame in enumerate(important_frames):
        temp_frame_dir = os.path.join(frame_dir, f"seg_{i}")
        os.makedirs(temp_frame_dir, exist_ok=True)

        try:
            segment_hands_from_frame_eff(frame, frame_dir)
            eff_feat = process_frame_combined_eff(frame_dir)
            eff_seq.append(eff_feat)
        except Exception as e:
            print(f"[⚠️] Frame {i} skipped: {e}")
            continue

    if len(eff_seq) == 0:
        shutil.rmtree(frame_dir)
        raise Exception("No valid frames")

    while len(eff_seq) < max_seq_len:
        eff_seq.append(eff_seq[-1])

    predicted_label, confidence = predict_sequence_eff(model, eff_seq, model_type)
    shutil.rmtree(frame_dir)
    return predicted_label




def process_video_sequence_eff(video_path, model_type):
    model = load_eff_model_by_type(model_type)
    WINDOW_SIZE = 10
    CONFIDENCE_THRESHOLD = 0.7
    MOTION_THRESHOLD = 2.0

    temp_dir = tempfile.mkdtemp()
    extract_frames_from_video(video_path, temp_dir)

    frames = []
    frame_files = sorted([f for f in os.listdir(temp_dir) if f.endswith('.jpg')])
    for frame_file in frame_files:
        frame_path = os.path.join(temp_dir, frame_file)
        frame = cv2.imread(frame_path)
        frames.append(frame)

    gesture_starts = detect_gesture_starts_optical_flow(temp_dir, MOTION_THRESHOLD)
    gesture_starts.append(len(frames))

    segments = []
    for i in range(len(gesture_starts) - 1):
        start = gesture_starts[i]
        end = gesture_starts[i + 1]
        segment = frames[start:end]
        if segment:
            segments.append(segment)

    final_predictions = []
    last_label = None

    for seg_idx, segment in enumerate(segments):
        segment = extract_with_landmarks(segment)
        if not segment:
            continue

        seg_dir = os.path.join(temp_dir, f"segment_{seg_idx}")
        os.makedirs(seg_dir, exist_ok=True)

        eff_seq = []

        for i, frame in enumerate(segment):
            frame_dir = os.path.join(seg_dir, f"frame_{i}")
            os.makedirs(frame_dir, exist_ok=True)

            try:
                segment_hands_from_frame_eff(frame, frame_dir)
                eff_feat = process_frame_combined_eff(frame_dir)
                eff_seq.append(eff_feat)
            except Exception as e:
                print(f"[⚠️] Segment {seg_idx}, Frame {i} skipped: {e}")
                continue

        if len(eff_seq) == 0:
            continue

        while len(eff_seq) < WINDOW_SIZE:
            eff_seq.append(eff_seq[-1])

        label, confidence = predict_sequence_eff(model, eff_seq, model_type)

        if confidence >= CONFIDENCE_THRESHOLD and label != last_label:
            final_predictions.append({
                "segment": seg_idx,
                "label": label,
                "confidence": float(confidence)
            })
            last_label = label

    sentence = " ".join([pred["label"] for pred in final_predictions])
    shutil.rmtree(temp_dir)
    return sentence
