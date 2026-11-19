# Shelf Scanner

Flutter Android app for live shelf-row, product, and empty-space detection using
the supplied YOLO TFLite models. The app uses GetX for state and navigation and
performs model work in a worker isolate.

## Features

- Rear-camera preview, photo capture/review/retake, and video recording.
- Live product detection with shelf detection sampled every three camera frames.
- Shelf and product bounding boxes labeled with class name and confidence
  (for example, `product 0.87`).
- Dropped live frames while inference is busy; FPS and inference time appear in
  the camera HUD.
- Photo inference and video review with up to eight sampled frames.
- Tries the TensorFlow Lite GPU delegate on Android; if delegate setup or model
  initialization fails, logs the reason and retries on CPU.
- Camera and microphone permission failures are shown in the app rather than
  terminating it.

## Model files and tensor formats

Place the supplied, float32 TFLite files here:

```text
assets/models/product_detector.tflite
assets/models/shelf_segmenter.tflite
```

| Model | Input | Outputs | Classes |
|---|---|---|---|
| `product_detector.tflite` | `[1, 3, 640, 640]`, NCHW, RGB float32 | `[1, 6, 8400]` | `empty space`, `product` |
| `shelf_segmenter.tflite` | `[1, 640, 640, 3]`, NHWC, RGB float32 | detection head `[1, 37, 8400]`, prototypes `[1, 160, 160, 32]` | `shelf` |

Both models receive RGB values normalized to `[0, 1]`. Frames are resized with
aspect ratio preserved and gray letterbox padding. The runner handles either
NHWC or NCHW input, decodes channel-first or channel-last YOLO heads, applies
class-aware NMS, and maps the boxes back to the upright image coordinates.
Shelf detections use the segmentation model's box head; prototype masks are
not rendered.

## Converting the original `.pt` models

Run from the directory containing the two original weight files. The following
uses the Ultralytics exporter and creates float32 TFLite files at 640 pixels:

```powershell
python -m pip install "ultralytics==8.3.40"
yolo export model=detect_product_empty_space.pt format=tflite imgsz=640 batch=1 half=False int8=False
yolo export model=segment_shelf_rows.pt format=tflite imgsz=640 batch=1 half=False int8=False
```

Ultralytics writes each export under a model-specific `*_saved_model` folder.
Copy the resulting `*_float32.tflite` files into `assets/models/` and rename
them to the exact names in the table above. Keep the model versions supplied
with this project unless intentionally regenerating and revalidating them.
Quantized exports are not supported by this app's float32 preprocessing.

## Build and run

Use Flutter 3.41 or newer with Android tooling installed. From the project root:

```powershell
flutter pub get
flutter run --release
```

connect and authorize a real Android phone for camera testing. The Android app
uses application ID `com.miscos.shelfscanner`, requires Android API 26 or newer,
and requests camera and microphone permissions. CameraX includes a
`WRITE_EXTERNAL_STORAGE` declaration limited to API 28 and older so its capture
plugin can save media on those legacy Android versions; modern Android does not
grant or require broad shared-storage access for this app.

### Smaller release APKs

Build one APK per ABI (recommended to avoid a universal APK):

```powershell
flutter build apk --release --split-per-abi
```

The APKs are written to `build/app/outputs/flutter-apk/`, including
`app-arm64-v8a-release.apk` for most modern Android phones. To build only arm64:

```powershell
flutter build apk --release --target-platform android-arm64
```

For an installable release bundle instead:

```powershell
flutter build appbundle --release
```

## Controls and behavior

- **Photo:** capture an image, process it on the review screen, or retake.
- **Video:** record and stop; the app analyzes up to eight evenly spaced frames
  and displays the resulting detections with video playback.
- **Rotate AI frame:** adjusts the live analysis orientation if a device reports
  an unusual camera sensor orientation.
- Live inference is paused in video mode to avoid competing with recording.

## Known limitations and submission checks

- Video results are sampled-frame results, not continuous detection playback.
- Shelf segmentation masks are not displayed; shelf bounding boxes and scores
  are shown instead.
- GPU delegate support and performance vary by Android device. The app falls
  back to CPU when delegate initialization/inference setup fails, but device
  performance still needs to be measured on the target phone.
- The current release build uses the Android debug signing key for local
  installation. Configure a private release keystore before store distribution.
- Validate camera and microphone permission prompts, live box alignment in
  portrait and landscape, photo/video flows, and inference speed on the actual
  submission device. A shelf-scene demo recording must also be captured on a
  real phone.

## Development checks

```powershell
flutter test
flutter analyze
```
