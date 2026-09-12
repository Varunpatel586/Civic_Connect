# Civic Connect: Service Layer (Infrastructure)

This document describes the services located in `lib/services/` that handle external integrations (REST API endpoints, local file uploading, geolocation coordinates, and deep linking).

---

## 1. ApiClient
Located in [api_client.dart](../lib/services/api_client.dart). The core network connector that manages:
- Reading backend URL (`API_BASE_URL`) from dotenv.
- Caching JWT authentication tokens locally via `SharedPreferences`.
- Appending Authorization headers (`Bearer <token>`) automatically.
- Supporting generic `get`, `post`, `put`, `patch`, `delete` HTTP queries.
- Supporting `uploadMultipart` for uploading file streams to the backend server storage.
- Supporting `classifyImage(XFile)` for pre-submission image classification through
	`POST /issues/classify`.

### Image classification behavior

`classifyImage` sends the captured image to the Express API before the issue form
is submitted. Express forwards the multipart file to the FastAPI vision service
at `POST /api/v1/classify`. The response contains:

- `category`: one of the complaint taxonomy values, including `other`.
- `confidence`: the winning zero-shot CLIP score.
- `is_confident`: whether the score passes the confidence and separation checks.
- `is_blurry` and `blur_score`: image quality indicators.
- `is_civic`: false when a distractor prompt wins.
- `reason`: a user-facing explanation when the category needs confirmation.

The client only auto-selects a category when `is_confident` is true. Uncertain
results start as `other`, allowing the citizen to choose manually instead of
silently filing the default category.

---

## 2. AuthService
Located in [auth_service.dart](../lib/services/auth_service.dart). Manages backend user session routes.

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
Located in [issue_service.dart](../lib/services/issue_service.dart). Interacts with backend issue routes.

### Key API
- **`getNearbyIssues({required double latitude, required double longitude, double radiusKm = 5.0, int limit = 50})`**: Queries `GET /issues/nearby`. Resolves nearby reports based on coordinate distance.
- **`getIssueById(String issueId)`**: Queries `GET /issues/:id`.
- **`createIssue({required String category, required String description, required List<String> imageUrls, required double latitude, required double longitude, String? address, String? title})`**: Resolves address from coordinates via Geocoding if needed, and posts to `POST /issues`. The backend evaluates if the category matches active complaints within a 15-meter radius and triggers the visual similarity engine.
- **`updateIssueStatus({required String issueId, required String status})`**: Performs `PATCH /issues/:id/status`.
- **`voteOnIssue({required String issueId, required String userId, required bool isAgree})`**: Performs `POST /issues/:id/vote` with JSON payload `{"isAgree": bool}`. The backend recalculates aggregate counts.
- **`getUserIssues(String userId)`**: Performs `GET /issues/user`.

---

## 4. CommentService
Located in [comment_service.dart](../lib/services/comment_service.dart). Manages comment sections under reports.

### Key API
- **`getCommentsByIssueId(String issueId)`**: Queries `GET /comments/issue/:issueId`.
- **`addComment({required String issueId, required String content})`**: Queries `POST /comments/issue/:issueId`.
- **`updateComment({required String commentId, required String content})`**: Queries `PUT /comments/:commentId`.
- **`deleteComment(String commentId)`**: Queries `DELETE /comments/:commentId`.

---

## 5. LocationService
Located in [location_service.dart](../lib/services/location_service.dart). Interacts with native GPS and geocoding plugins.

### Key API
- **`isLocationServiceEnabled()`**: Determines if system GPS toggle is switched on.
- **`checkAndRequestPermission()`**: Requests permissions dynamically.
- **`getCurrentPosition()`**: Fetches raw GPS coordinates (`Position`) using High accuracy.
- **`getAddressFromLatLng(double latitude, double longitude)`**: Reverse-geocodes coordinate values to formatted street addresses.

## 6. AdminService
Located in [admin_service.dart](../lib/services/admin_service.dart). Handles municipal officer operations.

### Key API
- **`getStats()`**: Fetches general ward counters and statistics (`WardStats`) via `GET /issues/stats`.
- **`getQueue({String? status, String? category})`**: Fetches the ranked triage queue (`List<Issue>`) from `GET /issues/queue`.
- **`updateStatus({required String issueId, required String status, String note})`**: Changes a complaint's status and adds an explanation note via `PATCH /issues/:issueId/status`.

---


## 7. DeepLinkService
Located in [deep_link_service.dart](../lib/services/deep_link_service.dart). Captures incoming URL streams, extracts token parameters, and updates `ApiClient` accordingly.
- **`_handleDeepLink(Uri uri)`**: Parses query parameters: `uri.queryParameters['token']`.

---

## 8. AI Vision Clustering Service (Microservice)
Located in the `ai_service/` directory and hosted as a Python FastAPI service.
It exposes two separate image workflows:

### Pre-submission classification

* **Endpoint**: `POST /api/v1/classify`
* **Input**: Multipart image field named `file`.
* **Processing**: Zero-shot `openai/clip-vit-base-patch32` scores civic-category
	prompts alongside non-civic distractor prompts. A category is considered
	confident only when its score is at least `0.55`, exceeds the strongest
	alternative by at least `0.10`, and the image is not blurry.
* **Quality checks**: Blur is measured using Laplacian variance after scaling to
	a fixed width. Unrelated images are returned as `other` with `is_civic=false`.
* **Output**: Category, confidence, confidence state, blur data, civic state,
	and a reason for manual confirmation when needed.

### Duplicate comparison

* **Endpoint**: `POST /api/v1/compare`
* **Input**: Target image path, candidate issue image paths, and a minimum
	inlier threshold. The current backend uses `25` inliers.
* **Processing**: Standardizes image width, detects ORB features, matches binary
	descriptors with a Hamming-distance brute-force matcher, and verifies the
	matches using a RANSAC homography.
* **Output**: Returns the candidate with the highest verified inlier count and
	`is_duplicate=true` only when the threshold is met.

