from flask import Flask, request, jsonify
import time
import os
import cv2
import numpy as np
from ultralytics import YOLO

app = Flask(__name__)

# Load your YOLO model (adjust the path to your facial feature detection model)
# This model should be trained to detect facial features like eye, eyebrow, nose, lip, mustache-beard, etc.
yolo_model = YOLO("E:/projects/facial feature extraction/best (1).pt")


def process_image(image_path):
    """
    Load the image using OpenCV.
    """
    image = cv2.imread(image_path)
    return image


def generate_summary(image_path):
    """
    Run YOLO detection on the image, compute the center for each detected feature,
    and then calculate Euclidean distances between each pair.
    Finally, return a formatted summary string.
    """
    # Load image (if needed for visualization or further processing)
    image = process_image(image_path)

    # Run YOLO detection on the image.
    # Depending on your YOLO API, you can pass the file path or the image itself.
    results = yolo_model(image_path)
    result = results[0]  # Assuming we take the first detection result

    features = {}
    # Process each detected bounding box.
    for box in result.boxes:
        # Get bounding box coordinates as [x1, y1, x2, y2]
        coords = box.xyxy[0].cpu().numpy()
        x1, y1, x2, y2 = coords
        confidence = float(box.conf[0].cpu().numpy())
        class_id = int(box.cls[0].cpu().numpy())
        # Get the label from the model's names mapping
        label = result.names[class_id]
        # Compute center of bounding box
        center = ((x1 + x2) / 2, (y1 + y2) / 2)
        # If multiple detections exist for the same label, store the one with highest confidence.
        if label not in features or confidence > features[label]['confidence']:
            features[label] = {'confidence': confidence, 'center': center}

    # Compute Euclidean distances between each pair of detected features.
    distances = {}
    feature_names = list(features.keys())
    for i in range(len(feature_names)):
        for j in range(i + 1, len(feature_names)):
            name1 = feature_names[i]
            name2 = feature_names[j]
            center1 = features[name1]['center']
            center2 = features[name2]['center']
            dist = np.sqrt((center1[0] - center2[0]) ** 2 + (center1[1] - center2[1]) ** 2)
            distances[f"{name1}_to_{name2}"] = {
                'distance': dist,
                'confidence': min(features[name1]['confidence'], features[name2]['confidence'])
            }

    # Build the summary string.
    summary = "1. Detected Features:\n"
    summary += "-" * 50 + "\n"
    summary += f"{'Feature':<15} {'Confidence':<12} {'Location (x, y)'}\n"
    summary += "-" * 50 + "\n"
    for feature, data in features.items():
        conf = data['confidence']
        x, y = data['center']
        summary += f"{feature:<15} {conf:>10.2f}    ({x:>6.1f}, {y:>6.1f})\n"

    summary += "\n2. Feature Distances:\n"
    summary += "-" * 50 + "\n"
    summary += f"{'Feature Pair':<25} {'Distance (px)':<15} {'Confidence'}\n"
    summary += "-" * 50 + "\n"
    for pair, data in distances.items():
        dist = data['distance']
        conf = data['confidence']
        summary += f"{pair:<25} {dist:>13.1f}    {conf:>9.2f}\n"

    return summary


@app.route('/analyze', methods=['POST'])
def analyze():
    start_time = time.time()
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    image_file = request.files['image']
    os.makedirs("uploads", exist_ok=True)
    temp_image_path = os.path.join("uploads", image_file.filename)
    image_file.save(temp_image_path)

    # Generate a summary based on real detections.
    summary = generate_summary(temp_image_path)
    inference_time_ms = (time.time() - start_time) * 1000

    response_data = {
        'inference_time_ms': inference_time_ms,
        'summary': summary
    }
    return jsonify(response_data)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
