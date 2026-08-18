# Civic Connect: Project Documentation Portal

Welcome to the **Civic Connect** documentation directory. This folder contains all the architectural blueprints, database descriptions, services mapping, models, configurations, and walkthroughs for the application.

---

## Documentation Index

Please refer to the following documents for details on each subsystem:

### 1. [Architecture Blueprint](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/architecture.md)
Contains structural diagrams, architectural patterns, data flow mechanisms, and sequence workflows showing how actions are handled in the application.

### 2. [Database Schema Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/database_schema.md)
Details database structures in Supabase/PostgreSQL. Document contains the Entity-Relationship (ER) diagram, table attributes, primary/foreign key relationships, constraints, and custom RPC functions.

### 3. [Services Layer Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/services.md)
Outlines external integrations including Supabase API endpoints, native GPS Geolocator permissions, geocoding functions, Google Sign-in flow, and persistent deep linking.

### 4. [Data Models Catalog](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/models.md)
Documents serializable model schemas (User Profiles, Issues, Comments, Votes) mapped between JSON responses and strongly typed Dart objects.

### 5. [Screens and Widgets Specification](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/screens_and_widgets.md)
Maps user interface components. Detailing stateful/stateless views and custom items like status colored badges, feeds bottom-sheets, photo capturer screens, and comment lists.

### 6. [Setup and Configuration Guide](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/docs/setup_and_configuration.md)
Detailed walkthrough explaining how to write the `.env` settings file, configure Supabase buckets, insert RPC SQL snippets, configure platform-specific deep links (Android/iOS), and run the project locally.

---

## Key Project Code Links
To explore the implementation files directly:
- **Application Bootstrap**: [main.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/main.dart)
- **Global State Coordinator**: [app_provider.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/providers/app_provider.dart)
- **Simple Dependency Injector**: [service_locator.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/service_locator.dart)
- **Dependency Configurations File**: [pubspec.yaml](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/pubspec.yaml)
