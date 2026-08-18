# Civic Connect: Service Layer (Infrastructure)

This document describes the services located in `lib/services/` that handle external integrations (Supabase database, authentication, storage, geolocation, deep linking).

---

## 1. AuthService
Located in [auth_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/auth_service.dart). Manages Supabase authentication sessions and user profile synchronization.

### Key API
- **`currentUser`**: Returns the currently logged-in Supabase `User?`.
- **`isAuthenticated`**: Helper boolean checking if `currentUser` is not null.
- **`onAuthStateChange`**: Stream exposing Supabase authentication status updates.
- **`getCurrentUserProfile()`**: Fetches profile fields (`username`, `email`, `role`, `avatar_url`) from the `profiles` table matching the authenticated user ID.
- **`signInWithEmail({required String email, required String password})`**: Performs password login. Throws `AppAuthException` if failed.
- **`signUpWithEmail({required String email, required String password, required String username})`**: Signs up a new user. It ensures that the username and email are unique, registers the user in Supabase Auth, and writes username details to the `profiles` table.
- **`signOut()`**: Terminate current auth session.
- **`updateProfile({String? username, String? fullName, String? avatarUrl})`**: Updates customizable fields in the `profiles` table.
- **`signInWithGoogle()`**: Starts a native Google Sign-in flow, extracts the ID token, and exchanges it for a Supabase session using `signInWithIdToken`. If no profile row exists, it automatically triggers profile creation.

---

## 2. IssueService
Located in [issue_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/issue_service.dart). Handles creation, fetching, voting, status management, and comment loading for civic issues.

### Key API
- **`getNearbyIssues({required double latitude, required double longitude, double radiusKm = 5.0, int limit = 50})`**: Queries coordinates inside the radius using the `get_nearby_issues` RPC.
- **`getIssueById(String issueId)`**: Queries a single issue and performs an inner join on `profiles` to include reporter details.
- **`createIssue({required String title, required String? description, required String imageUrl, required double latitude, required double longitude})`**: Creates a new issue. Before committing, it calls `geocoding`'s `placemarkFromCoordinates` to convert coordinate coordinates into a human-readable street address.
- **`updateIssueStatus({required String issueId, required String status})`**: Modifies the state of an issue (e.g. from `'Pending'` to `'In Progress'`). Restricted to admin users in UI.
- **`voteOnIssue({required String issueId, required String userId, required bool isAgree})`**: Submits a vote in the `votes` table. It updates or inserts the vote record and automatically calls `_updateVoteCounts()` to update aggregate `agree_count` / `disagree_count` fields in the `issues` table.
- **`getUserIssues(String userId)`**: Fetches issues reported by a specific profile ID.

---

## 3. CommentService
Located in [comment_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/comment_service.dart). Manages comments posted on civic reports.

### Key API
- **`getCommentsByIssueId(String issueId)`**: Retrieves comments in descending order of time, joining the commenter's profile details.
- **`addComment({required String issueId, required String content})`**: Validates content, inserts comment, and returns the parsed [Comment](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/models/comment.dart) object.
- **`updateComment({required String commentId, required String content})`**: Edits comments. Throws an exception if the comment does not belong to the currently logged-in user.
- **`deleteComment(String commentId)`**: Deletes comments after validating ownership.

---

## 4. LocationService
Located in [location_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/location_service.dart). Interacts with native GPS and geocoding plugins.

### Key API
- **`isLocationServiceEnabled()`**: Determines if system GPS toggle is switched on.
- **`checkAndRequestPermission()`**: Checks status of Geolocator permissions (`denied`, `deniedForever`, `whileInUse`, `always`). Requests permissions if not set.
- **`getCurrentPosition()`**: Fetches raw GPS coordinates (`Position`) using High accuracy.
- **`getAddressFromLatLng(double latitude, double longitude)`**: Performs reverse geocoding via the `geocoding` library to translate coordinate numbers into a formatted string (e.g. `'Street Name, City, Country'`).
- **`calculateDistance(...)`**: Uses the Haversine formula to compute the distance between two coordinates in kilometers.

---

## 5. UpvoteService
Located in [upvote_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/upvote_service.dart). Manages the secondary upvoting count structure (distinct from agree/disagree).

### Key API
- **`toggleUpvote(String issueId)`**: Toggles upvote state. If an entry in `issue_upvotes` exists, it is deleted; otherwise, a new one is created.
- **`getUpvoteCount(String issueId)`**: Fetches aggregate upvotes count from `issue_upvotes`.
- **`hasUserUpvoted(String issueId)`**: Returns a boolean indicating if the active user profile has already upvoted the issue.
- **`streamUpvoteCount(String issueId)`**: Emits a realtime stream of integer upvote counts using Supabase real-time database streams.

---

## 6. DeepLinkService
Located in [deep_link_service.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/services/deep_link_service.dart). Captures incoming URL streams on the device, mostly used for OAuth login redirects.

### Key API
- **`handleInitialUri()`**: Inspects if the app was launched via a deep link URI (e.g. `io.supabase.civicconnect://login-callback`). Parses and exchanges the URL session parameters.
- **`listenToDeepLinks()`**: Sets up a persistent stream listener on incoming app links.
