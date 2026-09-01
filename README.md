# NextUnit DocuScan App (Flutter)

A complete, production-ready Flutter Document Scanner, ML Kit OCR Text Extractor, Scan to Excel/CSV Generator, Voice Recorder & Google Drive Storage application.

## 🚀 Key Features
1. **Document Scanning & OCR**: Camera and Gallery document scanning with Google ML Kit text recognition.
2. **Scan to Excel & CSV**: Convert extracted tabular data into formatted `.xlsx` and `.csv` files.
3. **Voice Recording**: Record voice memos and notes attached to scanned documents.
4. **Storage & Google Drive**: Local file management and Google Drive Cloud Sync.
5. **Automated CI/CD**: GitHub Actions workflow (`.github/workflows/build.yml`) that compiles and outputs downloadable `app-release.apk` artifacts.

## 🛠️ How to Run Locally

1. **Install Flutter SDK (>= 3.0.0)**:
   ```bash
   flutter doctor
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on Android / iOS**:
   ```bash
   flutter run
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

## 📦 Automated GitHub Actions APK Build
Push this codebase to your GitHub repository on `main` or `master` branch. The `.github/workflows/build.yml` will automatically trigger, build the release APK, and publish `app-release.apk` under the GitHub Actions Artifacts tab!
