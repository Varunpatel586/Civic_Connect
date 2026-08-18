# Civic Connect 🏛️

**Civic Connect** is a location-aware mobile application built with Flutter (Frontend) and a Node.js/Express + MongoDB server (Backend). It empowers citizens to report, map, and democratically validate local civic issues (such as potholes, streetlights, garbage pile-ups, water supply failures, and road hazards) directly to public entities.

---

## Key Features

- 📸 **Camera & Image Reporting**: Take direct snapshots of civic complaints. Supports uploading multiple attachments per report.
- 📍 **GPS & Geocoding Location**: Automatically capture exact coordinates and translate them to human-readable street addresses.
- 🗺️ **Proximity Feed**: Read, query, and search reported issues within a custom radius boundary.
- 🔐 **Secure Session Auth**: JWT-based login and signup integrations powered by standard bcrypt hashing and Google OAuth verification on MongoDB.
- 💬 **Comments Section**: Community discussions under specific complaint tickets.
- 👍 **Democratic Validation**: Agree/Disagree validation voting system to filter out duplicates or verify reports.
- 🛡️ **Admin Status Escalation**: Admin actions to update statuses (`Pending`, `In Progress`, `Resolved`, `Rejected`).

---

## Repository Architecture

```
├── docs/                # Project Documentation Portal
│   ├── README.md        # Documentation Index Directory
│   ├── architecture.md  # Software architecture models and diagrams
│   ├── database.md      # MongoDB collections structure
│   ├── models.md        # Strongly typed Dart serialization classes
│   ├── services.md      # API integration, Geolocator, and deep links
│   ├── setup.md         # Setup scripts, environment variables, and configuration
│   └── views.md         # Interactive UI screens and custom items
├── server/              # Node.js/Express & MongoDB Backend API
│   ├── config/          # MongoDB database connect
│   ├── middleware/      # JWT verification middleware
│   ├── models/          # Mongoose data schemas (User, Issue, Comment, etc.)
│   ├── routes/          # Express route endpoints (auth, issues, comments)
│   ├── uploads/         # Local folder storing uploaded complaint images
│   ├── .env             # Server environment variables
│   └── server.js        # Express app main bootstrapper
└── lib/                 # Flutter source files
    ├── models/          # Data representations
    ├── providers/       # State controllers
    ├── screens/         # UI pages
    ├── services/        # Backend REST connectors
    └── widgets/         # Reusable layouts
```

---

## Comprehensive Project Documentation

We have prepared comprehensive documentation files explaining the architecture, services, schemas, and views. Explore them here:

- **[Docs Home / Index](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/README.md)**: Main portal listing all documentation files.
- **[Architecture Blueprint](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/architecture.md)**: Diagrams showing communication between UI, Providers, Services, REST API, and MongoDB.
- **[Database Schema Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/database_schema.md)**: MongoDB collection maps, indexes, and schemas.
- **[Services Layer Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/services.md)**: REST API endpoint maps, coordinates geocoding, and local file upload systems.
- **[Data Models Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/models.md)**: Class maps converting JSON parameters to Dart types.
- **[Screens & Widgets Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/screens_and_widgets.md)**: Visual layout structures and interactive cards.
- **[Setup & Configuration Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/setup_and_configuration.md)**: Environment variable configuration, MongoDB settings, and running scripts for server and client.

---

## Quick Start Guide

### 1. Run Backend Server
Inside the `server/` directory:
- Create `server/.env`:
  ```ini
  PORT=5000
  MONGO_URI=mongodb://localhost:27017/civic_connect
  JWT_SECRET=super_secret_jwt_key_civic_connect_123
  API_URL=http://localhost:5000
  ```
- Install dependencies and start:
  ```bash
  npm install
  npm start
  ```

### 2. Configure & Run Flutter Mobile App
In the root directory:
- Create `.env`:
  ```ini
  API_BASE_URL=http://10.0.2.2:5000/api # Use http://localhost:5000/api for iOS simulators
  ```
- Fetch packages and start:
  ```powershell
  flutter pub get
  flutter run
  ```

---

## Core Technologies
- **Client**: Flutter & Dart (Material 3 UI, Google Fonts)
- **Backend API**: Node.js & Express (Multer, jsonwebtoken, bcryptjs)
- **Database**: MongoDB (Mongoose ODM)
- **State Management**: Provider
- **Device Sensors**: Camera API, Geolocator (GPS tracking)
- **Geocoding**: Reverse coordinates mapping to address string
