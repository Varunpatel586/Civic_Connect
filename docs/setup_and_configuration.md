# Civic Connect: Setup and Configuration

This document provides setup instructions, environment variables configuration, database configuration, and running instructions for **Civic Connect**.

---

## Prerequisites
Before running the application, make sure you have the following installed:
- **Flutter SDK**: `^3.9.2` (run `flutter --version` to check)
- **Dart SDK**: `^3.9.2`
- **Android Studio / Xcode** (for emulation and compilation tools)
- **Supabase Account**: An active Supabase database project

---

## 1. Environment Variables Configuration

The app relies on a `.env` file located at the project root directory. This is loaded during boot time in [main.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/main.dart).

Create a `.env` file in the project root:
```ini
SUPABASE_URL=https://<your-supabase-project-id>.supabase.co
SUPABASE_ANON_KEY=<your-anon-public-api-key>
```

Add `.env` to your `pubspec.yaml` assets configuration to package it with your app:
```yaml
flutter:
  assets:
    - .env
    - assets/images/
```

---

## 2. Supabase Backend Setup

For the application services to operate, configure the following schemas, buckets, and policies in your Supabase project dashboard:

### A. Database Tables & Relations
Create the tables below using the Supabase SQL editor:
- **`roles`**: Contains columns `id` (int PK) and `name` (text). Add rows for `1` (`user`) and `2` (`admin`).
- **`profiles`**: Contains columns `id` (uuid PK, references auth.users), `username` (text unique), `email` (text), `role_id` (int, references roles.id, default 1), `avatar_url` (text), `created_at` (timestamptz).
- **`issues`**: Contains columns `id` (uuid PK, default gen_random_uuid()), `user_id` (uuid, references profiles.id), `title` (text), `category` (text), `description` (text), `image_url` (text), `image_urls` (text[]), `latitude` (numeric), `longitude` (numeric), `address` (text), `status` (text, default `'Pending'`), `agree_count` (int, default 0), `disagree_count` (int, default 0), `created_at` (timestamptz), `updated_at` (timestamptz).
- **`comments`**: Contains columns `id` (bigint PK generated always as identity), `issue_id` (uuid, references issues), `user_id` (uuid, references profiles.id), `content` (text), `created_at` (timestamptz).
- **`votes`**: Contains columns `id` (uuid PK), `issue_id` (uuid, references issues), `user_id` (uuid, references profiles.id), `is_agree` (boolean), `created_at` (timestamptz), `updated_at` (timestamptz).
- **`issue_upvotes`**: Contains columns `id` (uuid PK), `issue_id` (uuid, references issues), `user_id` (uuid, references profiles.id), `created_at` (timestamptz).

### B. Storage Buckets
Create a public storage bucket in Supabase named **`issue_photos`**. This bucket holds the images captured on user cameras.
Set up a Row Level Security (RLS) policy on the bucket allowing authenticated users write access and public read access.

### C. Database RPC Functions
Execute the following SQL commands to register stored procedures required by [IssueService](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/issue_service.dart):

```sql
-- 1. get_nearby_issues
CREATE OR REPLACE FUNCTION get_nearby_issues(
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION,
  max_count INTEGER
)
RETURNS SETOF issues
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM issues
  WHERE (6371 * acos(
    cos(radians(lat)) * cos(radians(latitude)) * 
    cos(radians(longitude) - radians(lng)) + 
    sin(radians(lat)) * sin(radians(latitude))
  )) <= radius_km
  ORDER BY created_at DESC
  LIMIT max_count;
END;
$$;

-- 2. get_issue_votes
CREATE OR REPLACE FUNCTION get_issue_votes(p_issue_id UUID)
RETURNS TABLE (agree_count INT, disagree_count INT) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE is_agree = true)::INT as agree_count,
    COUNT(*) FILTER (WHERE is_agree = false)::INT as disagree_count
  FROM votes
  WHERE issue_id = p_issue_id;
END;
$$;
```

---

## 3. Deep Linking (OAuth Configuration)

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

### iOS Configuration
In `ios/Runner/Info.plist`, configure custom URL schemes:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.civicconnect</string>
        </array>
    </dict>
</array>
```

---

## 4. Run the Project Locally

Run the following commands in the workspace root directory:

```powershell
# 1. Fetch dependencies
flutter pub get

# 2. Check issues and verify setup
flutter doctor

# 3. Compile and Run on connected emulator/device
flutter run
```
