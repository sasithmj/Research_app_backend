from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import os
import cv2
import numpy as np
import joblib
import base64
import pickle  # Import pickle to load the sugar production model
from ultralytics import YOLO
from skimage.feature import hog
from skimage.feature.texture import graycomatrix, graycoprops
from django.conf import settings
import xgboost as xgb  # Import XGBoost

# Load models for bud detection and classification
bud_detection_model = YOLO("ml_models/best.pt")
rf_model_bud = joblib.load("ml_models/sugarcane_rf_model.pkl")

# Load models for stem detection and classification
stem_detection_model = YOLO("ml_models/StemDetection_v1.pt")
rf_model_stem = joblib.load("ml_models/modelsbest_xgboost.pkl")

# Load the sugar production prediction model
sugar_production_model = pickle.load(open("ml_models/sugar_production_model.pkl", "rb"))

VARIETY_NAMES = {
    1: "SL 96 128",
    2: "SL 03 336",
    3: "SL 03 1077",
    4: "SL 03 1188"
}

# ============================
# Existing Functions for Bud and Stem Classification
# ============================

def detect_and_crop_bud(image_path):
    """
    Detects the bud in the image using YOLO and crops it.
    """
    img = cv2.imread(image_path)
    if img is None:
        print("❌ Failed to load bud image!")
        return None

    print("Detecting bud...")
    try:
        results = bud_detection_model(img)  # Run YOLO inference
        if isinstance(results, list) and len(results) > 0 and hasattr(results[0], 'boxes') and hasattr(results[0].boxes, 'xyxy'):
            boxes = results[0].boxes.xyxy  # Extract bounding boxes
        else:
            print("❌ No bud detected or invalid results structure!")
            return None

        if len(boxes) == 0:
            print("❌ No bud detected!")
            return None

        # Extract bounding box coordinates (first detected bud)
        x1, y1, x2, y2 = map(int, boxes[0])
        cropped_bud = img[y1:y2, x1:x2]  # Crop the detected bud
        return cropped_bud

    except Exception as e:
        print(f"Error processing bud YOLO results: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def extract_bud_features(img):
    """
    Extracts features from a bud image (color histograms + HOG).
    """
    IMG_SIZE = (128, 128)
    print("Resizing bud image to:", IMG_SIZE)

    # Resize and convert to RGB
    img = cv2.resize(img, IMG_SIZE)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Histogram Features (Color Distribution)
    print("Calculating bud color histograms...")
    hist_r = cv2.calcHist([img], [0], None, [256], [0, 256])
    hist_g = cv2.calcHist([img], [1], None, [256], [0, 256])
    hist_b = cv2.calcHist([img], [2], None, [256], [0, 256])
    hist_features = np.concatenate((hist_r.flatten(), hist_g.flatten(), hist_b.flatten()))
    print("Bud histogram features shape:", hist_features.shape)

    # HOG Feature Extraction
    print("Calculating bud HOG features...")
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    hog_features = hog(
        gray,
        orientations=9,
        pixels_per_cell=(8, 8),
        cells_per_block=(2, 2),
        block_norm='L2-Hys',
        feature_vector=True
    )
    print("Bud HOG features shape:", hog_features.shape)

    # Combine HOG + Histogram features
    combined_features = np.concatenate((hist_features, hog_features))
    print("Bud combined features shape:", combined_features.shape)

    return combined_features, img

def detect_and_crop_stem(image_path):
    """
    Detects the stem in the image using YOLO and crops it.
    """
    img = cv2.imread(image_path)
    if img is None:
        print("❌ Failed to load stem image!")
        return None

    print("Detecting stem...")
    try:
        results = stem_detection_model(img)  # Run YOLO inference for stem
        if isinstance(results, list) and len(results) > 0 and hasattr(results[0], 'boxes') and hasattr(results[0].boxes, 'xyxy'):
            boxes = results[0].boxes.xyxy  # Extract bounding boxes
        else:
            print("❌ No stem detected or invalid results structure!")
            return None

        if len(boxes) == 0:
            print("❌ No stem detected!")
            return None

        # Extract bounding box coordinates (first detected stem)
        x1, y1, x2, y2 = map(int, boxes[0])
        cropped_stem = img[y1:y2, x1:x2]  # Crop the detected stem
        return cropped_stem

    except Exception as e:
        print(f"Error processing stem YOLO results: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def extract_stem_features(image):
    """
    Extracts features from a stem image (color histograms, color stats, texture).
    """
    IMG_SIZE = (128, 128)
    print("Resizing stem image to:", IMG_SIZE)
    image = cv2.resize(image, IMG_SIZE)

    # Extract color histogram (RGB & HSV)
    print("Calculating stem color histograms...")
    color_hist = extract_color_histogram(image)
    print("Stem color histogram features shape:", color_hist.shape)

    # Extract color statistics (mean and std for RGB & HSV)
    print("Calculating stem color stats...")
    color_stats = extract_color_stats(image)
    print("Stem color stats shape:", color_stats.shape)

    # Extract texture features (GLCM)
    print("Calculating stem texture features...")
    texture_features = extract_texture_features(image)
    print("Stem texture features shape:", texture_features.shape)

    # Combine all features
    combined_features = np.concatenate((color_hist, color_stats, texture_features))
    print("Stem combined features shape:", combined_features.shape)

    return combined_features, image

def extract_color_histogram(image, bins=32):
    hist_features = []
    # RGB Histogram
    for i in range(3):
        hist = cv2.calcHist([image], [i], None, [bins], [0, 256]).flatten()
        hist_features.extend(hist)

    # Convert to HSV and compute HSV Histogram
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    for i in range(3):
        hist = cv2.calcHist([hsv], [i], None, [bins], [0, 256]).flatten()
        hist_features.extend(hist)

    return np.array(hist_features)

def extract_color_stats(image):
    stats = []
    for i in range(3):
        stats.append(np.mean(image[:, :, i]))
        stats.append(np.std(image[:, :, i]))

    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    for i in range(3):
        stats.append(np.mean(hsv[:, :, i]))
        stats.append(np.std(hsv[:, :, i]))

    return np.array(stats)

def extract_texture_features(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    glcm = graycomatrix(gray, distances=[1], angles=[0], levels=256, symmetric=True, normed=True)
    contrast = graycoprops(glcm, 'contrast')[0, 0]
    dissimilarity = graycoprops(glcm, 'dissimilarity')[0, 0]
    homogeneity = graycoprops(glcm, 'homogeneity')[0, 0]
    energy = graycoprops(glcm, 'energy')[0, 0]
    correlation = graycoprops(glcm, 'correlation')[0, 0]
    return np.array([contrast, dissimilarity, homogeneity, energy, correlation])

# ============================
# Existing View for Variety Prediction
# ============================

@csrf_exempt
def predict_variety(request):
    print("Received request method:", request.method)
    if request.method == 'POST':
        print("Request contains files:", request.FILES)

        # Check for both bud and stem images
        if 'bud_image' not in request.FILES or 'stem_image' not in request.FILES:
            print("Error: Both bud and stem images are required")
            return JsonResponse({'error': 'Both bud and stem images are required'}, status=400)

        try:
            # Save bud image
            bud_image_file = request.FILES['bud_image']
            print("Bud image file received:", bud_image_file.name)
            bud_path = default_storage.save('tmp/' + bud_image_file.name, ContentFile(bud_image_file.read()))
            bud_image_path = os.path.join(settings.MEDIA_ROOT, bud_path)
            print("Bud image saved at:", bud_image_path)

            # Save stem image
            stem_image_file = request.FILES['stem_image']
            print("Stem image file received:", stem_image_file.name)
            stem_path = default_storage.save('tmp/' + stem_image_file.name, ContentFile(stem_image_file.read()))
            stem_image_path = os.path.join(settings.MEDIA_ROOT, stem_path)
            print("Stem image saved at:", stem_image_path)

            # Process bud image
            print("Detecting and cropping bud...")
            cropped_bud = detect_and_crop_bud(bud_image_path)
            if cropped_bud is None:
                print("Error: No bud detected in the image")
                return JsonResponse({'error': 'No bud detected in the image'}, status=400)

            # Process stem image
            print("Detecting and cropping stem...")
            cropped_stem = detect_and_crop_stem(stem_image_path)
            if cropped_stem is None:
                print("Error: No stem detected in the image")
                return JsonResponse({'error': 'No stem detected in the image'}, status=400)

            # Extract features and predict for bud
            print("Extracting features from the cropped bud...")
            bud_features, resized_bud = extract_bud_features(cropped_bud)
            bud_features = bud_features.reshape(1, -1)
            print("Bud features extracted:", bud_features.shape)

            print("Predicting sugarcane variety from bud...")
            bud_predicted_class = rf_model_bud.predict(bud_features)[0] + 1
            bud_variety_name = VARIETY_NAMES.get(bud_predicted_class, "Unknown Variety")
            bud_class_probabilities = rf_model_bud.predict_proba(bud_features)[0]
            bud_class_probabilities = [float(prob) for prob in bud_class_probabilities]
            bud_predicted_class_index = np.argmax(bud_class_probabilities)
            bud_confidence = float(bud_class_probabilities[bud_predicted_class_index])*100
            print("Bud predicted variety:", bud_variety_name)
            print("Bud class probabilities:", bud_class_probabilities)

            # Extract features and predict for stem
            print("Extracting features from the cropped stem...")
            stem_features, resized_stem = extract_stem_features(cropped_stem)
            stem_features = stem_features.reshape(1, -1)
            print("Stem features extracted:", stem_features.shape)

            print("Predicting sugarcane variety from stem using XGBoost...")
            stem_class_probabilities = rf_model_stem.predict_proba(stem_features)[0]
            stem_class_probabilities = [float(prob) for prob in stem_class_probabilities]
            stem_predicted_class_index = np.argmax(stem_class_probabilities)
            stem_predicted_class = stem_predicted_class_index + 1
            stem_variety_name = VARIETY_NAMES.get(stem_predicted_class, "Unknown Variety")
            stem_confidence = float(stem_class_probabilities[stem_predicted_class_index])
            print("Stem predicted variety:", stem_variety_name)
            print("Stem class probabilities:", stem_class_probabilities)

            # Combine probabilities from bud and stem
            bud_weight = 0.5
            stem_weight = 0.5
            bud_class_probabilities = np.array(bud_class_probabilities)
            stem_class_probabilities = np.array(stem_class_probabilities)
            combined_probabilities = (bud_weight * bud_class_probabilities + stem_weight * stem_class_probabilities) / (bud_weight + stem_weight)
            combined_probabilities = [float(prob) for prob in combined_probabilities]
            print("Combined probabilities:", combined_probabilities)

            # Determine final variety and confidence from combined probabilities
            final_predicted_class_index = np.argmax(combined_probabilities)
            final_predicted_class = final_predicted_class_index + 1
            final_variety = VARIETY_NAMES.get(final_predicted_class, "Unknown Variety")
            final_confidence = float(combined_probabilities[final_predicted_class_index]) * 100
            print("Final predicted variety:", final_variety)
            print("Final confidence:", final_confidence)

            # Save the cropped bud image
            cropped_bud_path = os.path.join(settings.MEDIA_ROOT, 'cropped_buds', f"cropped_{bud_image_file.name}")
            os.makedirs(os.path.dirname(cropped_bud_path), exist_ok=True)
            cv2.imwrite(cropped_bud_path, cropped_bud)

            # Save the cropped stem image
            cropped_stem_path = os.path.join(settings.MEDIA_ROOT, 'cropped_stems', f"cropped_{stem_image_file.name}")
            os.makedirs(os.path.dirname(cropped_stem_path), exist_ok=True)
            cv2.imwrite(cropped_stem_path, cropped_stem)

            # Convert cropped bud image to base64
            _, bud_buffer = cv2.imencode('.jpg', cropped_bud)
            cropped_bud_base64 = base64.b64encode(bud_buffer).decode('utf-8')

            # Convert cropped stem image to base64
            _, stem_buffer = cv2.imencode('.jpg', cropped_stem)
            cropped_stem_base64 = base64.b64encode(stem_buffer).decode('utf-8')

            # Return the final combined result along with individual predictions for reference
            return JsonResponse({
                'variety': final_variety,
                'confidence':final_confidence 
,
                # 'bud_variety': bud_variety_name,
                # 'bud_confidence': bud_confidence * 100,
                # 'stem_variety': stem_variety_name,
                # 'stem_confidence': stem_confidence * 100,
                'cropped_bud_image': cropped_bud_base64,
                'cropped_stem_image': cropped_stem_base64
            })

        except Exception as e:
            print("Exception occurred:", str(e))
            import traceback
            traceback.print_exc()
            return JsonResponse({'error': str(e)}, status=500)
    else:
        print("Error: Invalid request method")
        return JsonResponse({'error': 'Invalid request method'}, status=400)

@csrf_exempt
def predict_sugar_production(request):
    """
    Predicts sugar production based on average yearly sunshine hours, soil temperature, and max temperature.
    Expects a POST request with JSON data containing 'sunshine', 'soil_temp', and 'temp_max'.
    """
    print("Received request method:", request.method)
    if request.method == 'POST':
        try:
            # Parse the request body (expecting JSON data)
            import json
            data = json.loads(request.body)
            print("Request data:", data)

            # Extract the input values
            sunshine = float(data.get('sunshine'))
            soil_temp = float(data.get('soil_temp'))
            temp_max = float(data.get('temp_max'))

            # Validate inputs
            if sunshine is None or soil_temp is None or temp_max is None:
                print("Error: Missing required fields")
                return JsonResponse({'error': 'Missing required fields: sunshine, soil_temp, and temp_max are required'}, status=400)

            # Prepare input data for prediction
            input_data = np.array([[sunshine, soil_temp, temp_max]])
            print("Input data for prediction:", input_data)

            # Make prediction using the loaded model
            prediction = sugar_production_model.predict(input_data)[0]
            print("Predicted sugar production:", prediction)

            # Convert prediction to a native Python float to ensure JSON serialization
            prediction = float(prediction)

            # Return the prediction in a JSON response
            return JsonResponse({
                'predicted_sugar_production': round(prediction, 2),  # Round to 2 decimal places for readability
                'unit': 'tons'
            })

        except ValueError as ve:
            print("ValueError occurred:", str(ve))
            return JsonResponse({'error': 'Invalid input values: sunshine, soil_temp, and temp_max must be numeric'}, status=400)
        except Exception as e:
            print("Exception occurred:", str(e))
            import traceback
            traceback.print_exc()
            return JsonResponse({'error': str(e)}, status=500)
    else:
        print("Error: Invalid request method")
        return JsonResponse({'error': 'Invalid request method'}, status=400)