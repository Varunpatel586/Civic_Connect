# Civic Connect: Service Layer (Infrastructure)

This document describes the services located in `lib/services/` that handle external integrations (REST API endpoints, local file uploading, geolocation coordinates, and deep linking).

---

## 1. ApiClient
Located in [api_client.dart](../../../../lib/services/api_client.dart). The core network connector that manages:
- Reading backend URL (`API_BASE_URL`) from dotenv.
- Caching JWT authentication tokens locally via `SharedPreferences`.
- Appending Authorization headers (`Bearer <token>`) automatically.
- Supporting generic `get`, `post`, `put`, `patch`, `delete` HTTP queries.
- Supporting `uploadMultipart` for uploading file streams to the backend server storage.

---

## 2. AuthService
Located in [auth_service.dart](../../../../lib/services/auth_service.dart). Manages backend user session routes.

### Key API
- **`isAuthenticated`**: Checks if the client has a cached JWT token.
- **`getCurrentUserProfile()`**: Performs `GET /auth/profile`. Resolves user metadata.
- **`signInWithEmail({required String email, required String password})`**: Performs `POST /auth/login`. Sets the returned JWT token on success.
- **`signUpWithEmail({required String email, required String password, required String username})`**: Performs `POST /auth/signup`. Sets the returned JWT token.
- **`signOut()`**: Resets the token via `ApiClient.setToken(null)`.
- **`updateProfile({String? username, String? fullName, String? avatarUrl})`**: Performs `PUT /auth/profile`.
- **`signInWithGoogle()`**: Starts a native Google Sign-in flow, obtains the ID Token, and invokes `POST /auth/google` on the backend to exchange it for a JWT session token.

---

## 3. IssueService
Located in [issue_service.dart](../../../../lib/services/issue_service.dart). Interacts with backend issue routes.

### Key API
- **`getNearbyIssues({required double latitude, required double longitude, double radiusKm = 5.0, int limit = 50})`**: Queries `GET /issues/nearby`. Resolves nearby reports based on coordinate distance.
- **`getIssueById(String issueId)`**: Queries `GET /issues/:id`.
- **`createIssue({required String title, required String? description, required String imageUrl, required double latitude, required double longitude})`**: Translates coordinates to address via Geocoding, determines category keywords from title, and calls `POST /issues` on the backend.
- **`updateIssueStatus({required String issueId, required String status})`**: Performs `PATCH /issues/:id/status`.
- **`voteOnIssue({required String issueId, required String userId, required bool isAgree})`**: Performs `POST /issues/:id/vote` with JSON payload `{"isAgree": bool}`. The backend recalculates aggregate counts.
- **`getUserIssues(String userId)`**: Performs `GET /issues/user`.

---

## 4. CommentService
Located in [comment_service.dart](../../../../lib/services/comment_service.dart). Manages comment sections under reports.

### Key API
- **`getCommentsByIssueId(String issueId)`**: Queries `GET /comments/issue/:issueId`.
- **`addComment({required String issueId, required String content})`**: Queries `POST /comments/issue/:issueId`.
- **`updateComment({required String commentId, required String content})`**: Queries `PUT /comments/:commentId`.
- **`deleteComment(String commentId)`**: Queries `DELETE /comments/:commentId`.

---

## 5. LocationService
Located in [location_service.dart](../../../../lib/services/location_service.dart). Interacts with native GPS and geocoding plugins.

### Key API
- **`isLocationServiceEnabled()`**: Determines if system GPS toggle is switched on.
- **`checkAndRequestPermission()`**: Requests permissions dynamically.
- **`getCurrentPosition()`**: Fetches raw GPS coordinates (`Position`) using High accuracy.
- **`getAddressFromLatLng(double latitude, double longitude)`**: Reverse-geocodes coordinate values to formatted street addresses.

---

## 6. UpvoteService
Located in [upvote_service.dart](../../../../lib/services/upvote_service.dart). Handles upvoting counts.

### Key API
- **`toggleUpvote(String issueId)`**: Performs `POST /issues/:id/upvote` to toggle upvotes in MongoDB.
- **`getUpvoteCount(String issueId)`**: Queries `GET /issues/:id/upvote/count`.
- **`streamUpvoteCount(String issueId)`**: Emits real-time upvote streams by polling `getUpvoteCount()` every 5 seconds.

---

## 7. DeepLinkService
Located in [deep_link_service.dart](../../../../lib/services/deep_link_service.dart). Captures incoming URL streams, extracts token parameters, and updates `ApiClient` accordingly.
- **`_handleDeepLink(Uri uri)`**: Parses query parameters: `uri.queryParameters['token']`.
