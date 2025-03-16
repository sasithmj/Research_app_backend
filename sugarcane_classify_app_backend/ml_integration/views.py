from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import os
import cv2
import numpy as np
import joblib
from ultralytics import YOLO
from skimage.feature import hog
import matplotlib.pyplot as plt
from django.conf import settings


# Load models
bud_detection_model = YOLO("ml_models/best.pt")
rf_model = joblib.load("ml_models/sugarcane_rf_model.pkl")

VARIETY_NAMES = {
    1: "Common",
    2: "SL 03 336",
    3: "SL 03 1077",
    4: "SL 03 1188"
}


def detect_and_crop_bud(image_path):
    """
    Detects the bud in the image using YOLO and crops it.
    """
    img = cv2.imread(image_path)
    print(type(img))

    # Show Original Image
    # show_image(img, "Original Image")
    print("detecting bud...")
    
    try:
        results = bud_detection_model(img)  # Run YOLO inference
        print("Got YOLO results - type:", type(results))
        
        # Debug the structure of results
        if isinstance(results, list):
            print(f"Results is a list with {len(results)} items")
            if len(results) > 0:
                print(f"First item type: {type(results[0])}")
                if hasattr(results[0], 'boxes'):
                    print(f"Boxes type: {type(results[0].boxes)}")
                    if hasattr(results[0].boxes, 'xyxy'):
                        print(f"xyxy type: {type(results[0].boxes.xyxy)}")
                    else:
                        print("No xyxy attribute in boxes")
                else:
                    print("No boxes attribute in results[0]")
        else:
            print(f"Results is not a list, it's a {type(results)}")
            
        # Extract bounding boxes - handle different result structures
        if isinstance(results, list) and len(results) > 0:
            if hasattr(results[0], 'boxes') and hasattr(results[0].boxes, 'xyxy'):
                boxes = results[0].boxes.xyxy  # Standard structure
            elif isinstance(results[0], dict) and 'boxes' in results[0]:
                if isinstance(results[0]['boxes'], dict) and 'xyxy' in results[0]['boxes']:
                    boxes = results[0]['boxes']['xyxy']
                else:
                    print("Unexpected boxes structure in results")
                    return None
            else:
                print("Could not find boxes in results")
                return None
        else:
            print("Empty or invalid results structure")
            return None

        if len(boxes) == 0:
            print("❌ No bud detected!")
            return None

        # Extract bounding box coordinates (first detected bud)
        x1, y1, x2, y2 = map(int, boxes[0])  # Get first detected bud
        cropped_bud = img[y1:y2, x1:x2]  # Crop the detected bud

        return cropped_bud  # Return cropped image
        
    except Exception as e:
        print(f"Error processing YOLO results: {str(e)}")
        import traceback
        traceback.print_exc()
        return None




def extract_features(img):
    """
    Extracts features from an image (color histograms + HOG).
    """
    IMG_SIZE = (128, 128)  # Resize images
    print("Resizing image to:", IMG_SIZE)  # Debug: Check image resizing

    # Resize and convert to RGB
    img = cv2.resize(img, IMG_SIZE)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Histogram Features (Color Distribution)
    print("Calculating color histograms...")  # Debug: Start histogram calculation
    hist_r = cv2.calcHist([img], [0], None, [256], [0, 256])
    hist_g = cv2.calcHist([img], [1], None, [256], [0, 256])
    hist_b = cv2.calcHist([img], [2], None, [256], [0, 256])

    hist_features = np.concatenate((hist_r.flatten(), hist_g.flatten(), hist_b.flatten()))
    print("Histogram features shape:", hist_features.shape)  # Debug: Check histogram features

    # HOG Feature Extraction
    print("Calculating HOG features...")  # Debug: Start HOG calculation
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)  # Convert to grayscale
    hog_features = hog(
        gray,
        orientations=9,
        pixels_per_cell=(8, 8),
        cells_per_block=(2, 2),
        block_norm='L2-Hys',
        feature_vector=True
    )
    print("HOG features shape:", hog_features.shape)  # Debug: Check HOG features

    # Combine HOG + Histogram features
    combined_features = np.concatenate((hist_features, hog_features))
    print("Combined features shape:", combined_features.shape)  # Debug: Check combined features

    return combined_features  # Return feature vector

@csrf_exempt
def predict_variety(request):
    print("Received request method:", request.method)  # Debug: Check request method
    if request.method == 'POST':
        print("Request contains files:", request.FILES)  # Debug: Check if files are present

        if 'bud_image' not in request.FILES:
            print("Error: No bud image found in request")  # Debug: No image found
            return JsonResponse({'error': 'Bud image is required'}, status=400)

        try:
            # Save bud image
            bud_image_file = request.FILES['bud_image']
            print("Bud image file received:", bud_image_file.name)  # Debug: Check image file name
            bud_path = default_storage.save('tmp/' + bud_image_file.name, ContentFile(bud_image_file.read()))
            bud_image_path = os.path.join(settings.MEDIA_ROOT, bud_path)
            print("Bud image saved at:", bud_image_path)  # Debug: Check saved image path

            # Process bud image
            print("Detecting and cropping bud...")  # Debug: Start bud detection
            cropped_bud = detect_and_crop_bud(bud_image_path)
            if cropped_bud is None:
                print("Error: No bud detected in the image")  # Debug: No bud detected
                return JsonResponse({'error': 'No bud detected in the image'}, status=400)

            # Extract features and predict
            print("Extracting features from the cropped bud...")  # Debug: Start feature extraction
            features = extract_features(cropped_bud)
            features = features.reshape(1, -1)
            print("Features extracted:", features.shape)  # Debug: Check feature shape

            print("Predicting sugarcane variety...")  # Debug: Start prediction
            predicted_class = rf_model.predict(features)[0] + 1
            variety_name = VARIETY_NAMES.get(predicted_class, "Unknown Variety")
            print("Predicted variety:", variety_name)  # Debug: Check predicted variety

            return JsonResponse({'variety': variety_name, 'confidence': 95})  # Example confidence value
        except Exception as e:
            print("Exception occurred:", str(e))  # Debug: Print exception details
            return JsonResponse({'error': str(e)}, status=500)
    else:
        print("Error: Invalid request method")  # Debug: Invalid request method
        return JsonResponse({'error': 'Invalid request method'}, status=400)