from flask import Flask, request, jsonify
import os
import tempfile

app = Flask(__name__)
UPLOAD_FOLDER = tempfile.mkdtemp()

# Import processing functions
from video_process import (
    process_video,
    process_video_sequence,
    process_video_eff,
    process_video_sequence_eff
)

@app.route("/predict_video", methods=["POST"])
def predict_video():
    if 'video' not in request.files:
        return jsonify({"error": "No video file provided"}), 400

    video = request.files['video']
    filename = os.path.join(UPLOAD_FOLDER, video.filename)
    video.save(filename)

    # Get mode and sequence type from query parameters
    mode = request.args.get('mode', 'complex')       # complex | simple
    seq_type = request.args.get('seq_type', 'single') # single | sequence
    model_type = int(request.args.get('model_type', 3))  # 1=letters, 2=numbers, 3=words

    try:
        # Complex Mode
        if mode == "complex":
            if seq_type == "single":
                result = process_video(filename, model_type=model_type)
            elif seq_type == "sequence":
                result = process_video_sequence(filename, model_type=model_type)
            else:
                return jsonify({"error": "Invalid sequence type"}), 400

        # Simple Mode
        elif mode == "simple":
            if seq_type == "single":
                result = process_video_eff(filename, model_type=model_type)
            elif seq_type == "sequence":
                result = process_video_sequence_eff(filename, model_type=model_type)
            else:
                return jsonify({"error": "Invalid sequence type"}), 400

        else:
            return jsonify({"error": "Invalid mode"}), 400

        return jsonify({
            "mode": f"{mode}_{seq_type}",
            "model_type": model_type,
            "label": result
        })

    except Exception as e:
        return jsonify({
            "error": str(e),
            "mode": f"{mode}_{seq_type}",
            "model_type": model_type
        }), 500

    finally:
        if os.path.exists(filename):
            os.remove(filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
