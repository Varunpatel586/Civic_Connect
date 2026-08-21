# Civic Connect: Project Documentation Portal

Welcome to the **Civic Connect** documentation directory. This folder contains all the architectural blueprints, database descriptions, services mapping, models, configurations, and walkthroughs for the application, migrated to a MongoDB + Node.js backend.

---

## Documentation Index

Please refer to the following documents for details on each subsystem:

### 1. [Architecture Blueprint](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/architecture.md)
Contains structural diagrams, architectural patterns, data flow mechanisms, and sequence workflows showing how actions are handled between Flutter, Express, and MongoDB.

### 2. [Database Schema Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/database_schema.md)
Details database structures in MongoDB. Document contains the Entity-Relationship (ER) diagram, Mongoose schemas, collection attributes, reference mappings, and index details.

### 3. [Services Layer Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/services.md)
Outlines external integrations including ApiClient REST calls, native GPS Geolocator permissions, reverse geocoding functions, Google Sign-in flow, and JWT-based deep linking.

### 4. [Data Models Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/models.md)
Documents serializable model schemas (User Profiles, Issues, Comments, Votes) mapped between MongoDB JSON responses and strongly typed Dart objects.

### 5. [Screens and Widgets Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/screens_and_widgets.md)
Maps user interface components. Detailing stateful/stateless views, status colored badges, feeds, photo capturer screens, and comment lists.

### 6. [Setup and Configuration Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/setup_and_configuration.md)
Detailed walkthrough explaining how to write the `.env` settings file, connect to local/cloud MongoDB instances, configure local multer upload folders, handle deep link redirect tokens, and run both backend and client locally.

---

## Key Project Code Links
To explore the implementation files directly:
- **Application Bootstrap**: [main.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/main.dart)
- **REST API Client Helper**: [api_client.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/api_client.dart)
- **Node.js Express Server Entrypoint**: [server.js](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/server/server.js)
- **Global State Coordinator**: [app_provider.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/providers/app_provider.dart)
- **Dependency Configurations File**: [pubspec.yaml](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/pubspec.yaml)
