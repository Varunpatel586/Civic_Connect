# Civic Connect 🏛️

**Civic Connect** is a location-aware mobile application built with Flutter and Supabase designed to empower citizens to report, track, and validate local civic issues (such as potholes, streetlights, garbage pile-ups, water supply failures, and road hazards) directly to public entities.

---

## Key Features

- 📸 **Camera & Image Reporting**: Take direct snapshots of civic complaints. Support for uploading multiple attachments per report.
- 📍 **GPS & Geocoding Location**: Automatically capture exact coordinates and translate them to human-readable street addresses.
- 🗺️ **Proximity Feed**: Read, query, and search reported issues within a custom radius boundary.
- 🔐 **Secure Session Auth**: Login and signup integrations powered by Supabase Auth (includes native Google OAuth flow).
- 💬 **Comments Section**: Community discussions under specific complaint tickets.
- 👍 **Democratic Validation**: Agree/Disagree validation voting system to filter out duplicates or verify reports.
- 🛡️ **Admin Status Escalation**: Standardized admin panel actions to update statuses (`Pending`, `In Progress`, `Resolved`, `Rejected`).

---

## Repository Architecture

```
├── docs/                # Project Documentation Portal
│   ├── README.md        # Documentation Index Directory
│   ├── architecture.md  # Software architecture models and diagrams
│   ├── database.md      # Database schemas, tables, and SQL functions
│   ├── models.md        # Strongly typed Dart serialization classes
│   ├── services.md      # API integration, Geolocator, and deep links
│   ├── setup.md         # Setup scripts, environment variables, and configuration
│   └── views.md         # Interactive UI screens and custom items
└── lib/                 # Flutter source files
    ├── models/          # Data representations
    ├── providers/       # State controllers
    ├── screens/         # UI pages
    ├── services/        # Backend connectors
    └── widgets/         # Reusable layouts
```

---

## Comprehensive Project Documentation

We have prepared comprehensive documentation files explaining the architecture, services, schemas, and views. Explore them here:

- **[Docs Home / Index](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/README.md)**: Main portal listing all documentation files.
- **[Architecture Blueprint](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/architecture.md)**: Diagrams showing communication between UI, Providers, Services, and Supabase.
- **[Database Schema Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/database_schema.md)**: Entity-Relation database diagrams, table definitions, and SQL functions.
- **[Services Layer Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/services.md)**: Interfaces detailing database queries, location parsing, and deep links.
- **[Data Models Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/models.md)**: Class maps converting JSON parameters to Dart types.
- **[Screens & Widgets Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/screens_and_widgets.md)**: Visual layout structures and interactive cards.
- **[Setup & Configuration Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/setup_and_configuration.md)**: Environment variable configuration, bucket policies, and running scripts.

---

## Quick Start Guide

### 1. Setup Environment
Create a `.env` file in the project root:
```ini
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-api-key
```

### 2. Fetch Packages
```powershell
flutter pub get
```

### 3. Start App
```powershell
flutter run
```

---

## Core Technologies
- **Client**: Flutter & Dart (Material 3 UI, Google Fonts)
- **Backend-as-a-Service**: Supabase (Database, Auth, Storage)
- **State Management**: Provider
- **Device Sensors**: Camera API, Geolocator (GPS tracking)
- **Geocoding**: Reverse coordinates mapping to address string
