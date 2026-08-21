# Civic Connect: Development Environment Version Reference

This document lists the exact versions of all SDKs, runtimes, and tools used in this project to ensure consistent builds across all developer machines and environments.

---

## 🛠️ Unified Version Matrix

| Tool / SDK | Version | Purpose | Download Link |
| :--- | :--- | :--- | :--- |
| **Flutter SDK** | `3.35.3` (Stable) | Mobile application framework | [Flutter SDK Archive](https://docs.flutter.dev/release/archive?tab=windows) |
| **Dart SDK** | `3.9.2` (Bundled with Flutter) | Client application programming language | *Included automatically with Flutter SDK* |
| **Java JDK** | `21.0.11` (Java 21 LTS) | Android compilation and Gradle builds | [Adoptium Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21) |
| **Android SDK Platform** | API 36 (`android-36`) | Android OS build target | Manage via Android Studio SDK Manager |
| **Android SDK Build-Tools**| `36.1.0-rc1` (or stable) | Android packaging tools | Manage via Android Studio SDK Manager |
| **Android NDK** | `27.0.12077973` | Native compilation for Flutter plugins | Manage via Android Studio SDK Manager |
| **Node.js** | `^20.x` LTS (recommended) | Backend API Server runtime | [Node.js Downloads](https://nodejs.org/) |
| **MongoDB** | `^7.x` or `^8.x` | Database system | [MongoDB Community Server](https://www.mongodb.com/try/download/community) |

---

## 📥 Detailed Setup & Installation Links

### 1. Flutter & Dart
Download **Flutter SDK version `3.35.3`** for your operating system.
* **Windows**: [Download Flutter 3.35.3 Windows](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.3-stable.zip)
* Extract the zip to your preferred SDK path (e.g. `C:\src\flutter` or `E:\src\flutter`).
* Add the path to the `bin` directory (e.g. `C:\src\flutter\bin`) to your system **PATH** environment variable.

### 2. JDK (Java Development Kit)
We recommend **Eclipse Temurin JDK 21** as it is a widely tested open-source LTS distribution.
* **Windows x64 Installer**: [Temurin JDK 21 .msi](https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.msi)
* During installation, check the box to **"Set JAVA_HOME variable"** and **"Associate .jar files"**.
* To check if your Flutter tool is using this version, run:
  ```bash
  flutter doctor -v
  ```
  If it uses a different JDK (e.g., one bundled with Android Studio), run this to force it:
  ```bash
  flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-21.0.6.7-hotspot"
  ```
  *(Adjust the path according to your installation folder)*

### 3. Android SDK, NDK, and Build-Tools
Open **Android Studio** and go to **Tools** > **SDK Manager**:
1. **SDK Platforms**: Check **Android 16.0 ("VanillaIceCream" / API 36)** and install.
2. **SDK Tools**:
   * Check **Show Package Details** in the bottom-right corner.
   * Scroll to **NDK (Side by side)** and check version `27.0.12077973`.
   * Scroll to **Android SDK Build-Tools** and check version `36.1.0-rc1` (or the highest 36.x version).
   * Click **Apply** to download and install.

### 4. Node.js & npm
Download the Node.js **LTS (Long Term Support)** installer.
* **Windows Installer**: [Node.js v20.x x64 .msi](https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi)

### 5. MongoDB
Install MongoDB Community Server to run a local database.
* **Windows Installer**: [MongoDB Community Server msi](https://www.mongodb.com/try/download/community)

---

## 🛠️ Auto-Version Tooling Support

### FVM (Flutter Version Manager)
If you use FVM to manage Flutter SDK versions in your workspace, the project root contains a config file. Just run:
```bash
fvm use
```
This will automatically switch the local workspace to the exact Flutter version (`3.35.3`).
