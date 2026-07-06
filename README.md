# Legally — AI Legal Intelligence

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)](#)
[![License](https://img.shields.io/badge/License-MIT-green)](#)

**Legally** is an AI-powered legal advisory and intelligence platform built with Flutter. It is purpose-built around India's **new criminal law framework** (effective July 2024), providing accurate and structured legal guidance under:

- **Bharatiya Nyaya Sanhita, 2023 (BNS)**
- **Bharatiya Nagarik Suraksha Sanhita, 2023 (BNSS)**
- **Bharatiya Sakshya Adhiniyam, 2023 (BSA)**

> ⚠️ This app does **not** reference the old IPC (Indian Penal Code). All responses strictly use the new 2023 criminal law framework.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🤖 **AI Legal Chat** | Ask complex legal questions and get structured answers citing BNS/BNSS/BSA sections |
| 📚 **Browse Laws** | Explore and search sections of India's new criminal laws |
| ⚖️ **Find Lawyers** | Discover and book consultations with verified legal professionals |
| 🛡️ **Admin Dashboard** | Manage users, monitor bookings, and view chat analytics |
| 🌐 **Demo / Offline Mode** | Full offline simulation using in-memory state — works without Firebase |
| 📱 **Cross-Platform** | Runs natively on Android, iOS, and Web from a single codebase |

---

## 🛠️ Tech Stack

- **Framework**: Flutter & Dart
- **Backend**: Node.js microservice hosted on [Render](https://render.com)
- **Auth & Database**: Firebase Authentication + Firebase Realtime Database
- **State**: Local in-memory global state for Demo Mode fallback
- **Platform Support**: Android, iOS, Web

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.7+)
- Android Studio or Xcode (for mobile builds)
- A Firebase project set up at [console.firebase.google.com](https://console.firebase.google.com)

### 1. Clone the Repository

```bash
git clone https://github.com/jadaunaryansingh/Legally_Flutter_App.git
cd Legally_Flutter_App
```

### 2. Configure Firebase

Firebase credentials are excluded from this repository for security. You must add them locally:

**Android:**
- Download `google-services.json` from your Firebase project console.
- Place it in `android/app/google-services.json`.

**Firebase Options (all platforms):**
```bash
# Copy the example template
cp lib/firebase_options.dart.example lib/firebase_options.dart
```
- Open `lib/firebase_options.dart` and fill in your Firebase API keys and project configuration.

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

---

## 🔒 Security

This project is configured to **never commit credentials to Git**. The following are excluded via `.gitignore`:

| File | Reason |
|---|---|
| `lib/firebase_options.dart` | Contains Firebase API keys |
| `google-services.json` | Android Firebase config |
| `GoogleService-Info.plist` | iOS Firebase config |
| `key.properties` | Android keystore credentials |
| `local.properties` | Local SDK paths |
| `.env`, `.env.*` | Environment variable files |

> 💡 See `lib/firebase_options.dart.example` for the expected format when setting up locally.

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry point, all screens and widgets
├── firebase_options.dart      # Firebase config (git-ignored, create locally)
└── firebase_options.dart.example  # Template for Firebase config

android/
└── app/
    └── google-services.json   # Firebase Android config (git-ignored)

ios/
└── Runner/
    └── GoogleService-Info.plist  # Firebase iOS config (git-ignored)
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
