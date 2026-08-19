# Civic Connect: Screens and Widgets

This document describes the presentation layer classes in `lib/screens/` and `lib/widgets/` that implement the user interface of **Civic Connect**.

---

## Screens

### 1. AuthScreen
Located in [auth_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/auth_screen.dart).
- **Purpose**: Manages authentication entry points (Login vs. Signup toggle).
- **Features**:
  - Secure email/password forms with validation.
  - Integrates a Google Authentication button using `AuthService.signInWithGoogle()`, exchanging tokens with the Node.js backend.
  - Displays loading indicators during backend requests and errors in an alert strip.

### 2. HomeScreen
Located in [home_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/home_screen.dart).
- **Purpose**: The core layout scaffold containing global navigation.
- **Features**:
  - Implements a material-design bottom navigation bar with a curved cutout.
  - Hosts a center-docked Floating Action Button (FAB) that opens the camera to report an issue.
  - Manages view routing toggles across Feed, Map, and Profile sections.
  - Verifies session tokens using `AuthService().isAuthenticated` before launching the camera.

### 3. FeedScreen
Located in [feed_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/feed_screen.dart).
- **Purpose**: Displays reported civic issues in a feed.
- **Features**:
  - Dynamically fetches nearby issues from the `/issues/nearby` REST endpoint.
  - If the database is empty or queries fail, it loads representative seed issues (Potholes, streetlights, garbage pile-ups) with placeholder parameters.
  - Provides swipe-to-refresh integration.
  - Integrates `PostDetailsBottomSheet` for viewing details and comments in place, fetching from `/comments/issue/:issueId`.

### 4. CameraScreen
Located in [camera_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/camera_screen.dart).
- **Purpose**: Captures photos of civic issues.
- **Features**:
  - Integrates with the `camera` package to control hardware lenses.
  - Requests native GPS location permission simultaneously during view initialization.
  - Once captured, forwards the image path alongside the resolved Latitude & Longitude to the submission form.

### 5. IssueSubmissionScreen
Located in [issue_submission_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/issue_submission_screen.dart).
- **Purpose**: Form to enter complaint parameters and submit to the backend database.
- **Features**:
  - Renders a dropdown list of categories (pothole, street light, water supply, electricity, garbage, road damage, drainage, other).
  - Integrates `image_picker` to upload multiple supporting photos.
  - Uploads images as binary streams to the backend server `/issues/upload` endpoint using `ApiClient().uploadMultipart`, retrieving static server URLs.
  - Saves the issue to MongoDB via `POST /issues`.

### 6. IssueDetailScreen
Located in [issue_detail_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/issue_detail_screen.dart).
- **Purpose**: Displays full details of a reported issue and its comments.
- **Features**:
  - Displays map coordinates, full description, and status chip.
  - Includes a comments stream allowing users to post replies.
  - Connects to `share_plus` to allow native system sharing of reported issues.

### 7. ProfileScreen
Located in [profile_screen.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/screens/profile_screen.dart).
- **Purpose**: Displays the user's profile card, statistics, and reported issue history.
- **Features**:
  - Displays count statistics for complaints submitted, votes registered, and resolved status counts.
  - Loads a list of issues reported by the authenticated user using `AppProvider.userIssues`.
  - Queries `AppProvider.currentUser` to display profile fields, and calls `AuthService.updateProfile` to modify profile details.

---

## Widgets

### 1. IssueCard
Located in [issue_card.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/widgets/issue_card.dart).
- **Purpose**: The primary item card rendered inside feed lists.
- **Visuals**:
  - Loads images with progress indicators using `cached_network_image`.
  - Displays colored status chips:
    - **PENDING**: Blue (`Colors.blue`)
    - **IN PROGRESS**: Orange (`Colors.orange`)
    - **RESOLVED**: Green (`Colors.green`)
    - **REJECTED**: Red (`Colors.red`)
  - Displays the geocoded street address and timestamp.
  - Hosts interactive buttons for **Agree** (upvotes), **Disagree** (downvotes), and **Comment** navigation. Calls `/issues/:id/vote`.

### 2. UpvoteButton
Located in [UpvoteButton.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/widgets/UpvoteButton.dart).
- **Purpose**: A reusable vote state toggle icon.
- **Features**:
  - Shows filled thumbs up if voted, outlined if not.
  - Toggles count changes locally and updates the database using `UpvoteService` (`POST /issues/:id/upvote`).

### 3. CommentTile
Located in [comment_tile.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/widgets/comment_tile.dart).
- **Purpose**: Renders a single comment block.
- **Features**: Displays commenter avatar (or fallback icon), username, time since creation, and comment content.

### 4. AuthWrapper
Located in [auth_wrapper.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/widgets/auth_wrapper.dart).
- **Purpose**: Root switcher routing traffic based on authorization state.
- **Features**: Returns `HomeScreen` if logged in, otherwise routes to `AuthScreen`.
