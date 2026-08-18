# Civic Connect

Civic Connect is a location-aware mobile application built with Flutter and a Node.js/Express backend querying a MongoDB database. The system enables citizens to report, map, and validate municipal issues such as potholes, damaged streetlights, and public hazards directly to authorities.

---

## Core Features

- **Complaint Reporting**: Capture photo evidence and submit reports with supporting images.
- **Geographic Pinpointing**: Automatically resolve coordinates using GPS and reverse-geocode them to formatted address strings.
- **Proximity Search**: Filter and view issues reported within a specified radius using geospatial proximity calculations.
- **Community Validation**: Prevent duplicate reports through an Agree/Disagree voting system.
- **Status Verification**: Track issues through state lifecycles: Pending, In Progress, Resolved, and Rejected.
- **Authentication**: JWT-secured login and signup workflows supporting email/password and Google OAuth token exchange.
- **Discussions**: Threaded comment sections under reported complaints.

---

## System Architecture

The project operates under a client-server architecture model. To ensure security, the mobile client communicates solely via REST endpoints with a Node.js middle-tier API:

- **Client App (Flutter)**: Manages UI rendering and uses Provider state management to coordinate authentication, location, and issue updates.
- **Backend API (Express & Node.js)**: Verifies JWT tokens, processes local file uploads, parses geospatial queries, and interacts with MongoDB.
- **Database (MongoDB)**: Stores data in collections using Mongoose schemas with compound unique indexing to prevent duplicate voting.

---

## Repository Structure

```
├── docs/                # System documentation specifications
│   ├── README.md        # Documentation index
│   ├── architecture.md  # System diagrams and data flows
│   ├── database.md      # MongoDB collections and index schema
│   ├── models.md        # Client-side Dart models
│   ├── services.md      # REST Client endpoints mapping
│   ├── setup.md         # Detailed configuration settings
│   └── views.md         # UI components and widgets mapping
├── server/              # Node.js Express server backend
│   ├── config/          # MongoDB configuration and Mongoose connector
│   ├── middleware/      # JWT authentication middleware
│   ├── models/          # Mongoose database models
│   ├── routes/          # Express route controllers
│   ├── uploads/         # Local storage folder for complaint images
│   └── server.js        # Main server entrypoint
└── lib/                 # Flutter mobile application codebase
    ├── models/          # Dart models
    ├── providers/       # ChangeNotifier state providers
    ├── screens/         # Page views
    ├── services/        # REST API connectors
    └── widgets/         # Reusable widgets
```

---

## Configuration & Local Run Guide

### 1. Configure the Environment
Create a unified environment configuration file named `.env` in the project root directory:

```ini
# Client Variables
API_BASE_URL=http://10.0.2.2:5000/api

# Server Variables
PORT=5000
MONGO_URI=mongodb://localhost:27017/civic_connect
JWT_SECRET=super_secret_jwt_key_civic_connect_123
API_URL=http://localhost:5000
```

*Note: For iOS simulators or Web builds, set `API_BASE_URL` to `http://localhost:5000/api`.*

### 2. Run the Express Backend
Navigate to the `/server` directory and run:
```bash
npm install
npm start
```

### 3. Run the Flutter Mobile Client
Navigate to the project root directory and run:
```bash
flutter pub get
flutter run
```

---

## Technical Specifications

For detailed analysis of individual components, refer to the specification files in the documentation folder:

- **[Documentation Index](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/README.md)**: Navigation portal for all specifications.
- **[System Architecture](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/architecture.md)**: In-depth data flow and sequence diagrams.
- **[Database Schemas](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/database_schema.md)**: Mongoose schemas, reference linkages, and collection indexing.
- **[Services Mapping](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/services.md)**: REST client network structures and geocoding services.
- **[Mobile View Components](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/screens_and_widgets.md)**: Layout widgets, status color chips, and sheet builders.
- **[Setup Specifications](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/setup_and_configuration.md)**: Detailed database scripts and configurations.
