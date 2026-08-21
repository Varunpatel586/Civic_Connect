# Civic Connect: Project Documentation Portal

Welcome to the **Civic Connect** documentation directory. This folder contains all the architectural blueprints, database descriptions, services mapping, models, configurations, and walkthroughs for the application, migrated to a MongoDB + Node.js backend.

---

## Documentation Index

Please refer to the following documents for details on each subsystem:

### 1. [Architecture Blueprint](architecture.md)
Contains structural diagrams, architectural patterns, data flow mechanisms, and sequence workflows showing how actions are handled between Flutter, Express, and MongoDB.

### 2. [Database Schema Specification](database_schema.md)
Details database structures in MongoDB. Document contains the Entity-Relationship (ER) diagram, Mongoose schemas, collection attributes, reference mappings, and index details.

### 3. [Services Layer Guide](services.md)
Outlines external integrations including ApiClient REST calls, native GPS Geolocator permissions, reverse geocoding functions, Google Sign-in flow, and JWT-based deep linking.

### 4. [Data Models Catalog](models.md)
Documents serializable model schemas (User Profiles, Issues, Comments, Votes) mapped between MongoDB JSON responses and strongly typed Dart objects.

### 5. [Screens and Widgets Specification](screens_and_widgets.md)
Maps user interface components. Detailing stateful/stateless views, status colored badges, feeds, photo capturer screens, and comment lists.

### 6. [Setup and Configuration Guide](setup_and_configuration.md)
Detailed walkthrough explaining how to write the `.env` settings file, connect to local/cloud MongoDB instances, configure local multer upload folders, handle deep link redirect tokens, and run both backend and client locally.

### 7. [Clustering Engine & Deduplication](clustering_engine.md)
Detailed design, system architecture, database updates, Python FastAPI model comparisons, and UI updates for the automated issue clustering pipeline.

---

## Key Project Code Links
To explore the implementation files directly:
- **Application Bootstrap**: [main.dart](../lib/main.dart)
- **REST API Client Helper**: [api_client.dart](../lib/services/api_client.dart)
- **Node.js Express Server Entrypoint**: [server.js](../server/server.js)
- **Global State Coordinator**: [app_provider.dart](../lib/providers/app_provider.dart)
- **Dependency Configurations File**: [pubspec.yaml](../pubspec.yaml)
