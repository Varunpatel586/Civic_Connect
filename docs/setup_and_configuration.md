# Civic Connect: Setup and Configuration

This document provides setup instructions, environment variables configuration, database configuration, and running instructions for both the **Node.js Server** and the **Flutter Client**, powered by a single unified root environment file.

---

## Prerequisites
Before running the application, verify your development environment matches the exact toolchain versions detailed in [ENVIRONMENT_VERSIONS.md](../ENVIRONMENT_VERSIONS.md).

Key requirements:
* **Flutter SDK**: `3.35.3` (Stable)
* **Dart SDK**: `3.9.2`
* **JDK (Java Development Kit)**: `21.0.11` (Java 21)
* **Android NDK**: `27.0.12077973`
* **Node.js**: `^20.x` LTS
* **MongoDB**: `^7.x` or `^8.x`


---

## 1. Unified Environment Configuration (`/.env`)

The project uses a single **global `.env` file** placed in the project root. Both the Flutter client and the Node.js server read their configurations from this single source.

Create one `.env` file in the project root directory:
```ini
# === CLIENT CONFIGURATIONS ===
API_BASE_URL=http://10.0.2.2:5000/api
# Note: Use http://localhost:5000/api for iOS simulators/Web runs.

# === SERVER CONFIGURATIONS ===
PORT=5000
MONGO_URI=mongodb://localhost:27017/civic_connect
JWT_SECRET=super_secret_jwt_key_civic_connect_123
API_URL=http://localhost:5000
AI_SERVICE_URL=http://localhost:8000
```

> [!IMPORTANT]
> Flutter bundles `.env` into the application asset bundle. This unified setup is
> intended for local development only; never put private production secrets in
> an environment file shipped with a client application.
>
> **Mobile Client Emulator IP Configuration**:
> - **Android Emulator**: Use `http://10.0.2.2:5000/api` for `API_BASE_URL`. The Android sandbox maps `10.0.2.2` to the host machine's `localhost`.
> - **iOS Simulator / Web**: Use `http://localhost:5000/api` directly.
> - **Physical Device**: Use the local IP address of your host machine (e.g. `http://192.168.1.50:5000/api`) and ensure both host and device are connected to the same Wi-Fi network.

Verify that `.env` is declared in assets inside the root `pubspec.yaml` file:
```yaml
flutter:
  assets:
    - .env
    - assets/images/
```

---

## 2. Running the Backend Server & AI Service (`/server`)

The backend server resolves `.env` dynamically from the parent workspace root folder.

To run the Express API server and the Python FastAPI vision clustering microservice concurrently, execute the following commands in the `/server` directory:
```bash
# 1. Install Node.js packages
npm install

# 2. Run both Node.js Express and Python FastAPI concurrently
npm run dev

# Or run only the Node.js Express server in production mode
npm start
```

> [!IMPORTANT]
> **AI Service Dependencies**: Ensure that you have installed the Python dependencies in `ai_service/requirements.txt` in your active shell or virtual environment before starting `npm run dev`.

When running `npm run dev`, concurrently will start:
* Express server at `http://localhost:5000` (reloads on file changes).
* Python FastAPI microservice at `http://localhost:8000` (reloads on file changes).

---

## 3. Running the Client Mobile App (Root Directory)

The client application loads `API_BASE_URL` from the root `.env` to make REST requests.

Execute the following commands in the project root directory:
```powershell
# 1. Fetch flutter packages
flutter pub get

# 2. Run diagnostic checks
flutter doctor

# 3. Compile and launch on connected emulator
flutter run
```

---

## 4. Deep Linking (OAuth Configuration)

To enable Google sign-in and password resets redirecting back into the mobile app:

### Android Configuration
In `android/app/src/main/AndroidManifest.xml`, configure an intent filter inside the main `<activity>` block:
```xml
<intent-filter android:label="flutter_deeplink_filter">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.civicconnect" android:host="login-callback" />
</intent-filter>
```
When OAuth redirects to this URI, the backend server appends the user JWT token:
`io.supabase.civicconnect://login-callback?token=<jwt-token>`
The client-side `DeepLinkService` captures this token and updates headers.

