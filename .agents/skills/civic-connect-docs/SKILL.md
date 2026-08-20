---
name: civic-connect-docs
description: >-
  Provides access to the comprehensive project documentation for Civic Connect.
  Use this skill when you need detailed reference information about project architecture,
  models, services, database schema, screens/widgets, or setup configurations.
---

# Civic Connect: Project Documentation Portal

Welcome to the **Civic Connect** documentation directory. This folder contains all the architectural blueprints, database descriptions, services mapping, models, configurations, and walkthroughs for the application, migrated to a MongoDB + Node.js backend.

---

## Documentation Index

Please refer to the following documents for details on each subsystem:

### 1. [architecture.md](../../../.agents/skills/civic-connect-docs/references/architecture.md)
Contains structural diagrams, architectural patterns, data flow mechanisms, and sequence workflows showing how actions are handled between Flutter, Express, and MongoDB.

### 2. [database_schema.md](../../../.agents/skills/civic-connect-docs/references/database_schema.md)
Details database structures in MongoDB. Document contains the Entity-Relationship (ER) diagram, Mongoose schemas, collection attributes, reference mappings, and index details.

### 3. [services.md](../../../.agents/skills/civic-connect-docs/references/services.md)
Outlines external integrations including ApiClient REST calls, native GPS Geolocator permissions, reverse geocoding functions, Google Sign-in flow, and JWT-based deep linking.

### 4. [models.md](../../../.agents/skills/civic-connect-docs/references/models.md)
Documents serializable model schemas (User Profiles, Issues, Comments, Votes) mapped between MongoDB JSON responses and strongly typed Dart objects.

### 5. [screens_and_widgets.md](../../../.agents/skills/civic-connect-docs/references/screens_and_widgets.md)
Maps the presentation layer: every screen and reusable widget, plus the Municipal Navy design system (colours, typography, card language) and the conventions to follow when adding UI.

### 6. [setup_and_configuration.md](../../../.agents/skills/civic-connect-docs/references/setup_and_configuration.md)
Detailed walkthrough explaining how to write the `.env` settings file, connect to local/cloud MongoDB instances, configure local multer upload folders, handle deep link redirect tokens, and run both backend and client locally.

---

## Key Project Code Links
To explore the implementation files directly:
- **Application Bootstrap**: [main.dart](../../../lib/main.dart)
- **REST API Client Helper**: [api_client.dart](../../../lib/services/api_client.dart)
- **Node.js Express Server Entrypoint**: [server.js](../../../server/server.js)
- **Global State Coordinator**: [app_provider.dart](../../../lib/providers/app_provider.dart)
- **Dependency Configurations File**: [pubspec.yaml](../../../pubspec.yaml)
- **Design System (colours, type, ThemeData)**: [lib/theme/](../../../lib/theme/)
