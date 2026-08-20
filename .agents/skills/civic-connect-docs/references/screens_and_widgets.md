# Civic Connect: Screens and Widgets

This document describes the presentation layer in `lib/screens/`, `lib/widgets/`, and `lib/theme/` that implements the user interface of **Civic Connect**.

The interface is called **Municipal Navy**. Read the [Design system](#design-system) section before changing any screen — the visual rules are deliberate, and the fastest way to make a change look wrong is to reintroduce a border.

---

## Screens

### 1. AuthScreen
Located in [auth_screen.dart](../../../../lib/screens/auth_screen.dart).
- **Purpose**: The front door — sign in or register.
- **Features**:
  - A light masthead (wordmark, an amber rule, and the line "Municipal services"). It is **not** a navy colour block; the wordmark carries the identity.
  - A segmented **Sign in / Register** switch (`_ModeToggle`) rather than a hidden mode — the same control the feed uses for scope.
  - Email/password fields with validation; register additionally asks for a username.
  - Google sign-in via `AuthService.signInWithGoogle()`, exchanging the token with the Node backend.
  - Failures surface as `SnackBar`s, not an inline alert strip.

### 2. HomeScreen
Located in [home_screen.dart](../../../../lib/screens/home_screen.dart).
- **Purpose**: The citizen shell that hosts the three main destinations.
- **Features**:
  - A flat `BottomNavigationBar` (Complaints, Map, Profile) with a hairline top edge — no curved notch.
  - A centre-docked FAB that opens the camera; `AuthService().isAuthenticated` is checked before launching it.
  - `_HomeAppBar` shows the wordmark inline with the current locality, so the citizen can see which body will receive what they file.
  - Municipal officers additionally get an entry point to `AdminConsoleScreen`. The server enforces the same rule, so hiding the button is convenience, not security.
  - Holds `_feedRevision`, bumped after filing so `FeedScreen` rebuilds and picks up the new complaint.

### 3. FeedScreen
Located in [feed_screen.dart](../../../../lib/screens/feed_screen.dart).
- **Purpose**: The complaint list.
- **Features**:
  - Loads through `IssueService.getNearbyIssues(...)`. There is **no** seeded/sample fallback — if the server cannot be reached, the screen says so and offers a retry.
  - Two independent filter axes: scope ("where") and category ("what").
    - `_ScopeSwitch` — a segmented **All wards / Near me** control; "Near me" needs a location fix and warns when there is none.
    - `_CategoryTab` — a horizontally scrolling row marked by a rule under the active tab.
  - Category filtering happens client-side over the loaded list; scope filtering re-queries the server.
  - Swipe-to-refresh, plus distinct empty and error states (`_FeedMessage`).
  - Renders `IssueCard`s in a list with 16px gutters and 12px between cards.

### 4. CameraScreen
Located in [camera_screen.dart](../../../../lib/screens/camera_screen.dart).
- **Purpose**: Captures the photograph that evidences a complaint.
- **Features**:
  - Drives hardware lenses through the `camera` package (flash toggle, front/rear swap).
  - Requests GPS permission during initialisation and shows a `_LocationPill` stating whether the photo will carry coordinates.
  - Forwards the captured image plus latitude/longitude to `IssueSubmissionScreen`.
  - Deliberately dark: this is the one screen that does not follow the light card language, because a viewfinder should not compete with the frame.

### 5. IssueSubmissionScreen
Located in [issue_submission_screen.dart](../../../../lib/screens/issue_submission_screen.dart).
- **Purpose**: Turns a photo and a location into a filed complaint.
- **Features**:
  - The form is a stack of cards (`_Section`): Category, What is wrong, Location.
  - `_CategoryPicker` is a **grid of chips**, not a dropdown — eight options is few enough to show at once, and seeing them all helps a citizen pick the right one.
  - `_EvidenceStrip` shows the captured photo plus a thumbnail rail for extra images added via `image_picker`.
  - `_LocationCard` renders three states: locating, resolved (address plus coordinates in the record face), and unavailable (an amber block with a retry).
  - Uploads images to `/issues/upload` via `ApiClient().uploadMultipart`, then files through `AppProvider.reportIssue` so the feed and the citizen's own list both refresh.
  - Filing is disabled until a location is available.

### 6. IssueDetailScreen
Located in [issue_detail_screen.dart](../../../../lib/screens/issue_detail_screen.dart).
- **Purpose**: One complaint in full.
- **Features**:
  - Always refetches rather than reading the provider's cached copy, because only this endpoint returns the status history.
  - Full-bleed photograph at the top — the one element that is not a card, because it is the evidence.
  - Below it, a stack of `_Section` cards:
    - `_Summary` — category, title, complaint reference, filing time, SLA countdown, description.
    - `_LocationRow` — address and coordinates, tappable to open the system maps app.
    - `_VoteBar` — Agree / Disagree with tallies.
    - `_Timeline` — the recorded status history, oldest first, with a filled node for the current state.
    - `_CommentSection` — the discussion, rendered with `CommentTile`.
  - A docked `_CommentComposer` posts new comments.
  - Sharing goes through `share_plus`.

### 7. MapScreen
Located in [map_screen.dart](../../../../lib/screens/map_screen.dart).
- **Purpose**: Complaints plotted where they were reported.
- **Features**:
  - OpenStreetMap tiles via `flutter_map` — no API key, no billing account, nothing to configure before it works.
  - `_ComplaintPin` colours each pin by state (overdue wins over the stored status); `_YouAreHere` marks the citizen.
  - Floating chrome that lifts off the map with shadow rather than borders: `_Legend`, `_MapButton` (centre on me / fit all complaints), and `_SelectedCard` for the tapped pin.
  - `_Attribution` is required by the OpenStreetMap licence — do not remove it.
  - Camera moves are gated on `onMapReady`; the controller throws if driven before `FlutterMap` attaches it.

### 8. ProfileScreen
Located in [profile_screen.dart](../../../../lib/screens/profile_screen.dart).
- **Purpose**: The citizen's own record and account controls.
- **Features**:
  - Renders as content only — `HomeScreen` owns the scaffold and app bar.
  - `_Header` — circular avatar, username, email, and for officers a "Municipal officer" designation. It used to be a navy slab; it is now light like everything else.
  - `_StatStrip` — a card of three counters: Filed, Resolved, Member since.
  - `_EditCard` — inline username editing through `AuthService.updateProfile`, followed by `AppProvider.initialize()`.
  - `_MenuGroup` / `_MenuItem` — cards of account actions (Edit profile, My activity, Help and support, About), separated by inset hairlines.
  - Sign out is a red **tint**, not a red outline, and confirms in a dialog first.

### 9. MyActivityScreen
Also in [profile_screen.dart](../../../../lib/screens/profile_screen.dart).
- **Purpose**: Everything this citizen has contributed.
- **Features**:
  - Two tabs: **Complaints** (their own `IssueCard`s, actions hidden) and **Comments** (loaded via `CommentService.getUserComments()`).
  - Each comment card links back to the complaint it was left on.
  - `_ActivityEmpty` states say what happened and what to do next.

### 10. AdminConsoleScreen
Located in [admin_console_screen.dart](../../../../lib/screens/admin_console_screen.dart).
- **Purpose**: The municipal officer's view — where the ward stands, then what to do next.
- **Features**:
  - Opens on counters rather than the queue, because the first question an officer is asked is "where are we", not "what is next".
  - `_MetricGrid` — one card carrying Open, Overdue, Resolved, and average close time. Overdue stands out by colour alone. The average states what it was measured over, so the number can be defended.
  - `_CategoryBreakdown` — the top five categories as proportion bars.
  - `_QueueHeader` — the triage queue heading, its count, and status filters (`_FilterChip`). Ranking is done by the server: overdue first, then most-supported, then oldest.
  - `_QueueRow` — one complaint per card. Overdue work tints the whole card, the one place colour carries across a surface.
  - `_StatusSheet` — a bottom sheet to move a complaint to a new state with an optional note for the record, via `AdminService.updateStatus`.
  - Data comes from `AdminService.getStats()` and `AdminService.getQueue(status:)`.

---

## Widgets

### 1. IssueCard
Located in [issue_card.dart](../../../../lib/widgets/issue_card.dart).
- **Purpose**: A complaint as it appears in a feed or a queue.
- **Structure**: photograph, then a meta line (category · ward · when) with the status chip, then title, complaint reference, description, a ledger row (SLA countdown plus vote tallies), and the action row.
- **Visuals**:
  - Loads images with `cached_network_image`; failures fall back to a slate placeholder.
  - No rules between the parts — spacing does the separating.
  - Actions are **Agree**, **Disagree**, and **Discuss**, rendered as text with icons rather than three bordered thirds. Voting goes through `AppProvider.voteOnIssue`; unauthenticated taps prompt to sign in.
  - `showActions: false` renders the card read-only (used by My activity).

### 2. StatusChip
Located in [status_chip.dart](../../../../lib/widgets/status_chip.dart). This file also exports `SlaLabel` and `ReferenceLabel`.
- **StatusChip**: the complaint's state, drawn from `StatusColors` in [app_colors.dart](../../../../lib/theme/app_colors.dart) — never from raw `Colors.*`:
  - **PENDING**: blue (`0xFF1D4ED8` on `0xFFEAF1FE`)
  - **IN PROGRESS**: amber (`0xFFB45309` on `0xFFFEF6E7`)
  - **RESOLVED**: green (`0xFF15803D` on `0xFFE9F7EE`)
  - **REJECTED**: red (`0xFFB91C1C` on `0xFFFDECEC`)
  - **OVERDUE**: burnt orange (`0xFF9A3412` on `0xFFFFF1E7`) — derived from the response clock, not stored on the issue, and it overrides whatever status the record carries.
  - Borderless except overdue, which keeps a rule because it is the one state that should stop someone scrolling. Unknown server statuses fall back to pending rather than rendering colourless.
- **SlaLabel**: the response-deadline countdown, computed by `SlaPolicy` in [sla.dart](../../../../lib/utils/sla.dart). A 6px dot reads as a status light; the colour escalates from slate to amber to overdue.
- **ReferenceLabel**: the complaint reference from `ComplaintReference.format()`, set in the monospaced record face.

### 3. CommentTile
Located in [comment_tile.dart](../../../../lib/widgets/comment_tile.dart).
- **Purpose**: One entry in a complaint's discussion.
- **Features**: circular avatar (or the username's initial), username, time since posting, and the comment body.

### 4. AuthWrapper
Located in [auth_wrapper.dart](../../../../lib/widgets/auth_wrapper.dart).
- **Purpose**: Root switcher routing on authorisation state.
- **Features**: returns `HomeScreen` when signed in, otherwise `AuthScreen`.

---

## Design system

Three files in [lib/theme/](../../../../lib/theme/) define everything visual. Screens should read from them rather than hard-coding values.

### [app_colors.dart](../../../../lib/theme/app_colors.dart)
Navy is ink and action, not background. `navy900` for headings and primary actions, `navy700` for secondary, `canvas` (`0xFFF7F8FA`) for page background, `surface` white for cards, `slate600`/`slate400` for body and metadata, `slate200`/`slate100` for the few remaining rules and faint fills. `amber700` is reserved for **time pressure only** — spending it elsewhere costs the one signal that makes an officer look twice. `StatusColors` holds the per-state palettes listed above.

### [app_typography.dart](../../../../lib/theme/app_typography.dart)
Two faces, split by job. **IBM Plex Sans** carries the interface; **IBM Plex Mono** carries anything that is a *record* — complaint references (`recordId`), dashboard values (`metric`), vote tallies (`inlineCount`). Numeric runs use tabular figures so digits hold their columns. Hierarchy comes from size and colour, not boxes. There is exactly one uppercase style, `badge`, and it is spent on a complaint's status alone; everything else is sentence case (`sectionLabel`, `meta`).

### [app_theme.dart](../../../../lib/theme/app_theme.dart)
The organising rule: **surfaces are separated by space and a whisper of shadow, not by rules and colour blocks.**

- `AppTheme.cardDecoration` — white fill, `cardRadius` (14), and `softShadow` (a tight edge layer plus a wide soft lift). Use it for anything that should read as a card.
- `AppTheme.radius` (10) for buttons, inputs, chips; `AppTheme.badgeRadius` (6) for status badges and small fills.
- `AppTheme.hairline` — the only rule left in the system, for edges that are genuinely load bearing (a nav boundary, a focused field).
- Chrome stays near-white: white app bar, no elevation, no surface tint. Inputs are filled and borderless. Buttons are flat.

**Conventions to keep when adding UI**

| Rule | Why |
|---|---|
| Cards sit on the canvas with 16px side gutters | Every list and section already uses it; a different gutter reads as misalignment |
| Lift with `softShadow`, never with Material `elevation` | Enforced by a test in `test/widget_test.dart` |
| Never separate rows with 1px gaps or full-bleed colour strips | That was the old "framed" look this design replaced |
| Sentence case everywhere except the status badge | The one uppercase style is a signal; spending it elsewhere spends the signal |
| Selected states are fills, not outlines | A fill states the same thing with fewer lines |
| Empty and error states use `slate400` icons and say what to do next | `slate200` is a rule colour, not an ink colour |

---

## Testing the presentation layer

Widget tests live in [test/widgets/](../../../../test/widgets/) and the theme's rules are asserted in [test/widget_test.dart](../../../../test/widget_test.dart). Tests run offline: `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll`, and image placeholders spin forever without a network, so pump with `tester.pump()` rather than `pumpAndSettle()`.
