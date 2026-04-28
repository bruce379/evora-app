# Evora App - One-Time Setup

Run these commands in Terminal from the evora_app folder.

## 1. Init git and push to GitHub

```bash
cd ~/Documents/Claude/Projects/Evora\ Health/evora_app

git init
git config user.email "bruce@gostartr.com"
git config user.name "Bruce"
git branch -m main
git add -A
git commit -m "init: Evora App v1 scaffold - Flutter + Firebase"
git remote add origin https://github.com/bruce379/evora-app.git
git push -u origin main
```

(Create the repo at github.com/new first - name it `evora-app`, private, no README)

---

## 2. Install Flutter (if not installed)

```bash
# macOS via homebrew
brew install flutter
flutter doctor
```

---

## 3. Install dependencies

```bash
flutter pub get
```

---

## 4. Wire Firebase (one-time)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure - uses existing evora-health Firebase project
flutterfire configure --project=evora-health

# This auto-generates lib/firebase_options.dart with correct keys
# Also registers the web app under app.evorahealth.co.za
```

---

## 5. Run locally

```bash
# Web (phone shell preview)
flutter run -d chrome

# iOS simulator
flutter run -d iPhone

# Android emulator
flutter run -d android
```

---

## 6. Deploy web to Firebase Hosting

```bash
flutter build web --release
firebase deploy --only hosting
```

Set hosting target in firebase.json to app.evorahealth.co.za

---

## Notes
- Colors/branding are placeholder - will update after design review
- Bluetooth pairing stubbed out - requires native app for full BLE
- All new registrations auto-tagged source: evora_app in Firestore
- Email sequence trigger field: emailSequence = "onboarding"
