import os
import json
from PIL import Image

DATASET_ROOT = "data_rekognition_format"
BUCKET_NAME = "custom-labels-console-us-east-1-764f97bb2d"  # MY BUCKET, CHANGE THIS
S3_PREFIX = "dataset"  # Change if you upload to a different path

# Define your class names here - map class IDs to their names
CLASS_MAP = {
    0: "kill"
}


def create_manifest_for_split(split_name, bucket_name, s3_prefix, class_map):
    img_dir = os.path.join(DATASET_ROOT, split_name, "images")
    lbl_dir = os.path.join(DATASET_ROOT, split_name, "labels")

    if not os.path.exists(img_dir):
        print(f"Warning: {img_dir} does not exist, skipping...")
        return None

    manifest_lines = []

    image_files = [f for f in os.listdir(img_dir)
                   if f.lower().endswith((".jpg", ".png", ".jpeg"))]

    print(f"\nProcessing {split_name}: {len(image_files)} images")

    for img_name in image_files:
        base = os.path.splitext(img_name)[0]
        img_path = os.path.join(img_dir, img_name)
        json_path = os.path.join(lbl_dir, f"{base}.json")

        if not os.path.exists(json_path):
            print(f"Warning: No label file for {img_name}, skipping...")
            continue

        # Get image dimensions
        try:
            with Image.open(img_path) as img:
                width, height = img.size
        except Exception as e:
            print(f"Error reading image {img_name}: {e}")
            continue

        # Read label JSON
        try:
            with open(json_path, 'r') as f:
                label_data = json.load(f)
        except Exception as e:
            print(f"Error reading label {json_path}: {e}")
            continue

        # Convert annotations to Rekognition format
        annotations = []
        for ann in label_data.get('Annotations', []):
            bbox = ann['BoundingBox']
            class_id = ann['ClassId']

            # Convert normalized coordinates (0-1) to pixel coordinates
            annotations.append({
                "class_id": class_id,
                "left": int(bbox['Left'] * width),
                "top": int(bbox['Top'] * height),
                "width": int(bbox['Width'] * width),
                "height": int(bbox['Height'] * height)
            })

        if not annotations:
            print(f"Warning: No annotations for {img_name}, skipping...")
            continue

        # Build S3 path
        s3_image_path = f"s3://{bucket_name}/{s3_prefix}/{split_name}/images/{img_name}"

        # Create manifest entry - Rekognition Custom Labels format
        manifest_entry = {
            "source-ref": s3_image_path,
            "bounding-box": {
                "image_size": [{
                    "width": width,
                    "height": height,
                    "depth": 3
                }],
                "annotations": annotations
            },
            "bounding-box-metadata": {
                "objects": [{"confidence": 1}] * len(annotations),
                "class-map": {str(k): v for k, v in class_map.items()},
                "type": "groundtruth/object-detection",
                "human-annotated": "yes",
                "job-name": "labeling-job",
                "creation-date": "2025-01-01T00:00:00.000000"
            }
        }

        manifest_lines.append(json.dumps(manifest_entry))

    if not manifest_lines:
        print(f"Warning: No valid entries for {split_name}")
        return None

    # Write manifest file
    manifest_filename = f"{split_name}_manifest.json"
    with open(manifest_filename, 'w') as f:
        f.write('\n'.join(manifest_lines))

    print(f"Created {manifest_filename} with {len(manifest_lines)} entries")
    return manifest_filename


def main():
    print("Generating Rekognition Custom Labels manifest files...")
    print(f"Bucket: {BUCKET_NAME}")
    print(f"S3 Prefix: {S3_PREFIX}")
    print(f"Class Map: {CLASS_MAP}")
    print()

    if BUCKET_NAME == "your-bucket-name":
        print("ERROR: Please set BUCKET_NAME in the script!")
        return

    if CLASS_MAP == {0: "class_0", 1: "class_1"}:
        print("WARNING: Using default class names. Update CLASS_MAP with your actual class names!")

    manifests_created = []

    # Create manifest for each split
    for split in ["train", "valid", "test"]:
        manifest_file = create_manifest_for_split(
            split_name=split,
            bucket_name=BUCKET_NAME,
            s3_prefix=S3_PREFIX,
            class_map=CLASS_MAP
        )
        if manifest_file:
            manifests_created.append(manifest_file)

    print("\n" + "=" * 60)
    print("Manifest generation complete!")
    print("=" * 60)
    print("\nCreated files:")
    for mf in manifests_created:
        print(f"  - {mf}")

    print("\nNext steps:")
    print("1. Upload your dataset to S3:")
    print(f"   aws s3 sync {DATASET_ROOT} s3://{BUCKET_NAME}/{S3_PREFIX}/")
    print("\n2. Upload manifest files to S3:")
    for mf in manifests_created:
        print(f"   aws s3 cp {mf} s3://{BUCKET_NAME}/{S3_PREFIX}/manifests/{mf}")
    print("\n3. Create Rekognition Custom Labels dataset:")
    print("   - Go to AWS Rekognition Console")
    print("   - Create new project")
    print("   - Create dataset")
    print("   - Choose 'Import images labeled by SageMaker Ground Truth'")
    print(f"   - Training dataset S3 URI: s3://{BUCKET_NAME}/{S3_PREFIX}/manifests/train_manifest.json")
    print(f"   - Test dataset S3 URI: s3://{BUCKET_NAME}/{S3_PREFIX}/manifests/test_manifest.json")


if __name__ == "__main__":
    main()
