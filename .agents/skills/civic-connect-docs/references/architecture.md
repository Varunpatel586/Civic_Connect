# Civic Connect: Architectural Overview

This document outlines the software architecture and directory structure of the **Civic Connect** application, utilizing a Node.js/Express + MongoDB backend API.

## Directory Structure

The project separates frontend client views from backend database operations using a modular REST architecture.

```
├── server/              # Node.js Express & MongoDB Backend
│   ├── config/          # MongoDB db.js connection configuration
│   ├── controllers/     # Controller layer (issueController.js)
│   ├── middleware/      # jwt auth.js verification middleware
│   ├── models/          # Mongoose Schemas (User.js, Issue.js, Comment.js, etc.)
│   ├── routes/          # Express route controllers (auth.js, issues.js, comments.js)
│   ├── uploads/         # Server folder storing uploaded image binaries
│   ├── .env             # Server configurations
│   ├── run-ai.js        # Helper script for running AI venv concurrently
│   └── server.js        # Main Express application entrypoint
├── ai_service/          # Python FastAPI Vision Microservice
│   ├── main.py          # FastAPI server entrypoint (CLIP model comparison)
│   ├── requirements.txt # Python dependencies
│   └── README.md        # Dedicated FastAPI readme
└── lib/                 # Flutter Mobile Client Source
    ├── models/          # Dart models matching backend JSON structures
    ├── providers/       # AppProvider — global state
    ├── screens/         # Flutter UI pages
    ├── services/        # Flutter REST API client service layer
    ├── theme/           # Municipal Navy: colours, typography, ThemeData
    ├── utils/           # SLA policy, complaint references, category taxonomy
    └── widgets/         # Reusable layouts and custom views
```

---

## Architectural Pattern

Civic Connect implements a client-server architecture with an decoupled **AI Microservice** for deep learning operations. All requests flow through Node.js Express, which communicates with MongoDB and queries the FastAPI service for vision deduplication checks:

```mermaid
graph TD
    UI[Screens & Widgets] -->|Observes state / Dispatches| Provider[AppProvider]
    Provider -->|Calls API client methods| ApiClient[ApiClient Helper]
    ApiClient -->|GET / POST / PUT REST Requests| Express[Express Server on port 5000]
    Express -->|Verifies JWT Tokens| Middleware[Auth Middleware]
    Express -->|Queries Mongoose Schemas| Mongo[(MongoDB Database)]
    Express -->|Saves Image Binaries| Uploads[Local Uploads Folder]
    Express -->|Compares Visual Similarity| FastAPI[FastAPI Microservice on port 8000]
    FastAPI -->|Runs CLIP Model| PyTorch[PyTorch / sentence-transformers]
```

### 1. Client Presentation Layer (UI)
Consists of Screens (views representing full screens) and Widgets (reusable layout components). The views are kept as dumb as possible, delegating actions to [AppProvider](../lib/providers/app_provider.dart) and displaying state values.

### 2. Client State Management (Provider)
[AppProvider](../lib/providers/app_provider.dart) uses Flutter's `ChangeNotifier` to hold the application's global state:
- Current authenticated user (`currentUser` of type `UserProfile`)
- Current user GPS location (`currentPosition` and `currentAddress`)
- Lists of reported issues (`nearbyIssues` and `userIssues`)
- Loading indicators and feedback states

The UI listens to this provider using `context.watch<AppProvider>()` or `Provider.of<AppProvider>(context)` and updates reactively.

### 3. Client REST Service Layer
Services encapsulate HTTP REST endpoints and platform functions:
- [ApiClient](../lib/services/api_client.dart): Generic HTTP client wrapping headers, JWT authentication token loading, and multipart requests.
- [AuthService](../lib/services/auth_service.dart): Connects to `/auth/login`, `/auth/signup`, and `/auth/profile`.
- [IssueService](../lib/services/issue_service.dart): Queries `/issues/nearby`, `/issues/user`, and `/issues/:id/vote`.
- [CommentService](../lib/services/comment_service.dart): Queries `/comments/issue/:id` CRUD routes.
- [LocationService](../lib/services/location_service.dart): Fetches GPS coordinates and translates them into street addresses using geocoding.
- [DeepLinkService](../lib/services/deep_link_service.dart): Captures URL deep links for post-OAuth redirect callbacks.

---

## Technical Flow Diagram

The following sequence diagram describes reporting a civic issue with automated proximity checking and image clustering (deduplication):

```mermaid
sequenceDiagram
    participant U as User
    participant CS as CameraScreen
    participant ISS as IssueSubmissionScreen
    participant AC as ApiClient
    participant EX as Express API
    participant LS as LocationService
    participant MG as MongoDB (Mongoose)
    participant AI as FastAPI (CLIP Service)

    U->>CS: Capture photo of pothole
    CS->>LS: Request current coordinates
    LS-->>CS: Return Latitude/Longitude
    CS->>ISS: Navigate with Image & Coordinates
    ISS->>ISS: Input Title, Category & Description
    U->>ISS: Tap Submit
    ISS->>AC: uploadMultipart('/issues/upload')
    AC->>EX: POST /issues/upload (Send File Stream)
    EX->>EX: Save file to server/uploads/ folder
    EX-->>AC: Return JSON with File URL
    AC-->>ISS: Parse Local Server File URL
    ISS->>AC: post('/issues', {title, category, imageUrl, lat, lng})
    AC->>EX: POST /issues (Send JSON Payload)
    
    EX->>LS: Geocode Coordinates to Address (on client or server)
    
    rect rgb(240, 245, 255)
        Note over EX,MG: Geospatial Proximity Check (15m)
        EX->>MG: Find open issues within 15 meters in same category
        MG-->>EX: Return candidate issues
    end

    alt Candidates Exist
        rect rgb(255, 248, 235)
            Note over EX,AI: Visual Similarity Engine
            EX->>AI: POST /api/v1/compare (target & candidate paths)
            AI->>AI: Compute Cosine Similarity using CLIP embeddings
            AI-->>EX: Return match result (is_duplicate: true/false)
        end
    end

    alt Duplicate Match Confirmed
        EX->>MG: Merge: append reporter, append image, increment reportCount
        MG-->>EX: Confirm merge
        EX-->>AC: Return JSON payload (clustered: true, status: 200)
    else No Proximity / No Visual Match / AI Error
        EX->>MG: Save brand new Issue document (reportCount: 1)
        MG-->>EX: Confirm insertion
        EX-->>AC: Return JSON data of Created Issue (clustered: false, status: 201)
    end
    
    AC-->>ISS: Confirm Success
    ISS->>U: Show success message & return to Feed
```

