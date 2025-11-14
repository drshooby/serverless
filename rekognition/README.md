# AWS Rekognition Custom Labels - Valorant Kill Detection Model

This project trains an AWS Rekognition Custom Labels model to detect "kill" events in images using object detection.

Data handling scripts are written by Claude AI.

## Dataset Credit

Dataset borrowed from [ClipSyncAI by Frozen-Bugg](https://github.com/Frozen-Bugg/ClipSyncAI/tree/master). The original data is provided in `data.zip` within their repository.

## Project Structure

```
.
├── main.py                          # Converts YOLO labels to Rekognition format + augmentation
├── generate_manifests.py            # Generates manifest files for Rekognition
├── data/                            # Original dataset (from data.zip)
│   ├── train/
│   │   ├── images/
│   │   └── labels/                  # YOLO format (.txt files)
│   ├── valid/
│   │   ├── images/
│   │   └── labels/
│   └── test/
│       ├── images/
│       └── labels/
└── data_rekognition_format/         # Generated - Rekognition-ready dataset
    ├── train/
    │   ├── images/                  # Original + augmented images
    │   └── labels/                  # JSON format
    ├── valid/
    │   ├── images/
    │   └── labels/
    └── test/
        ├── images/
        └── labels/
```

## What Each File Does

### `main.py`

- Converts YOLO format labels (`.txt`) to Rekognition JSON format
- Applies data augmentation to training images (hue shifts, brightness, rotation, blur, etc.)
- Creates 3 augmented versions per training image
- **Input**: `data/` directory with YOLO format
- **Output**: `data_rekognition_format/` directory with JSON labels
- Increases training data from ~230 images to ~920 images

### `generate_manifests.py`

- Reads the converted dataset from `data_rekognition_format/`
- Generates manifest files required by AWS Rekognition Custom Labels
- Creates separate manifests for train, validation, and test splits
- **Output**: `train_manifest.json`, `valid_manifest.json`, `test_manifest.json`

## Setup & Installation

1. **Install dependencies**:

```bash
pip install albumentations opencv-python pillow
```

2. **Extract dataset**:

```bash
unzip data.zip
```

3. **Configure AWS credentials**:

```bash
aws configure
```

## Step-by-Step Instructions

### Step 1: Convert Dataset & Apply Augmentation

Run the conversion script to transform YOLO labels to Rekognition format and augment training data:

```bash
python main.py
```

This will:

- Convert all YOLO `.txt` labels to Rekognition JSON format
- Create augmented versions of training images (3x per image)
- Output everything to `data_rekognition_format/`

**Expected output**: ~920 training images (230 original + 690 augmented)

### Step 2: Generate Manifest Files

Before running, update `generate_manifests.py`:

- Set `BUCKET_NAME` to your S3 bucket (e.g., `custom-labels-console-us-east-1-764f97bb2d`)
- Verify `CLASS_MAP` is correct (default: `{0: "kill"}`)

```bash
python generate_manifests.py
```

This creates:

- `train_manifest.json`
- `valid_manifest.json`
- `test_manifest.json`

### Step 3: Upload to S3

Upload the dataset and manifest files to S3:

```bash
# Upload entire dataset
aws s3 sync data_rekognition_format s3://custom-labels-console-us-east-1-764f97bb2d/dataset/

# Upload manifest files
aws s3 cp train_manifest.json s3://custom-labels-console-us-east-1-764f97bb2d/dataset/manifests/train_manifest.json
aws s3 cp valid_manifest.json s3://custom-labels-console-us-east-1-764f97bb2d/dataset/manifests/valid_manifest.json
aws s3 cp test_manifest.json s3://custom-labels-console-us-east-1-764f97bb2d/dataset/manifests/test_manifest.json
```

**Note**: Replace bucket name with your actual bucket.

### Step 4: Create Rekognition Dataset

1. Go to [AWS Rekognition Custom Labels Console](https://console.aws.amazon.com/rekognition/)
2. Create a new project (or use existing)
3. Create dataset:
   - **Training dataset**: Select "Import images labeled by SageMaker Ground Truth"
   - Enter S3 URI: `s3://custom-labels-console-us-east-1-764f97bb2d/dataset/manifests/train_manifest.json`
   - **Test dataset**: Select "Import images labeled by SageMaker Ground Truth"
   - Enter S3 URI: `s3://custom-labels-console-us-east-1-764f97bb2d/dataset/manifests/test_manifest.json`
4. Click "Create dataset"

### Step 5: Train Model

1. Click "Train model" in the Rekognition console
2. Select your project
3. Add tags (optional)
4. Keep default encryption settings
5. Click "Train model"

**Training time**: 1-3 hours

**Cost warning**: You'll be charged for training time and inference hours when the model is running.

## Dataset Details

- **Class**: `kill` (ClassId: 0)
- **Format**: Bounding box object detection
- **Training images**: ~920 (with augmentation)
- **Validation images**: varies
- **Test images**: ~33
- **Augmentations applied**: Hue/saturation shifts, brightness/contrast, blur, noise, rotation, horizontal flip, scaling

## Troubleshooting

### Manifest errors in Rekognition

- Ensure manifest files use correct S3 paths
- Check that class IDs in JSON labels match `CLASS_MAP`
- Verify images exist at the S3 locations referenced in manifests

### Missing label files

- Ensure every image has a corresponding label file
- Check file naming: `image.jpg` should have `image.json` label

### Augmentation creates invalid bounding boxes

- This is handled automatically - invalid boxes are skipped
- If many augmentations fail, reduce rotation/scale limits in `main.py`

## Model Usage (After Training)

1. Start the model in Rekognition console
2. Use AWS SDK to make inference calls
3. Stop the model when not in use to avoid charges

## Notes

- AWS Rekognition Custom Labels charges by the hour for both training and inference
- Keep the model stopped when not actively using it
- The augmentation pipeline can be customized in `main.py` by modifying the `augmentor` settings
