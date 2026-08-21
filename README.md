# Civic Connect

A location-aware civic complaint system: citizens photograph municipal issues, the
community validates them, and ward officers triage them to resolution. Flutter
client, Node/Express API, MongoDB.

The point of the system is the **closed loop** — a complaint is not just filed, it
is validated, ranked against a response deadline, worked, and closed, with every
state change on the record.

---

## Features

### Citizen
- **Report** — photograph an issue, classify it, and file it with GPS coordinates.
  Filing is blocked without a location, because a complaint the municipality
  cannot find is one it cannot dispatch anyone to.
- **Complaint reference** — every report gets a quotable ID (`CC-2026-MH-93047`).
- **Feed** — browse by ward or within 5 km, filtered by category.
- **Map** — complaints plotted on OpenStreetMap, coloured by status.
- **Community validation** — Agree / Disagree voting, so duplicates and false
  reports surface without a moderator.
- **Case history** — every status change with its timestamp and the officer's note.
- **Discussion** — threaded comments under each complaint.

### Municipal officer
- **Overview** — open, overdue, resolved, and average time-to-close for the ward.
- **Triage queue** — ranked by urgency: overdue first, then most-supported, then
  oldest waiting.
- **Status control** — move a complaint through its lifecycle with a note for the
  record.

### Response deadlines
Each category carries a response window (water and electricity 2 days, street
lights and garbage 3, drainage 5, potholes 7, roads 10). Anything past its window
is flagged **Overdue** and rises to the top of the queue. The policy lives in
[`server/config/sla.js`](server/config/sla.js) and is served to the client as a
`due_at` on every complaint, so the app and the dashboard cannot disagree about
what is late.

---

## Architecture

```
Flutter client  ──HTTP/JSON──▶  Express API  ──Mongoose──▶  MongoDB
   lib/            + JWT          server/                   civic_connect
                                     │
                                     └─ multer → server/uploads/ (served at /uploads)
```

The client never talks to the database. Field names cross the wire in
`snake_case`; a single `serializeIssue` in
[`server/routes/issues.js`](server/routes/issues.js) produces every issue payload
so a field cannot land on one endpoint and go missing from another.

```
lib/
├── models/       Dart models (Issue, Comment, UserProfile, StatusEvent, WardStats)
├── providers/    AppProvider — global state
├── screens/      Feed, map, detail, report flow, profile, municipal console
├── services/     REST clients (api, auth, issue, comment, admin, location, deep link)
├── theme/        Municipal Navy design system
├── utils/        Complaint references, SLA policy, category taxonomy
└── widgets/      IssueCard, StatusChip, CommentTile

server/
├── config/       Env validation, Mongo, SLA policy, wards, migrations
├── middleware/   JWT auth, municipal-officer gate
├── models/       Mongoose schemas
├── routes/       auth, issues, comments
└── test/         node:test suites
```

---

## Setup

### 1. Environment

Two files, and the split matters.

**`.env`** in the project root — server secrets. Never bundled into the app.

```ini
PORT=5000
MONGO_URI=mongodb://localhost:27017/civic_connect
JWT_SECRET=change-me-to-something-random
API_URL=http://localhost:5000

# Optional. Until set, POST /api/auth/google refuses every request rather
# than trusting the token it was handed.
# GOOGLE_CLIENT_IDS=xxxx.apps.googleusercontent.com

# Optional. Comma-separated web origins. Unset allows every origin.
# CORS_ORIGINS=http://localhost:3000
```

The server refuses to start if `JWT_SECRET` or `MONGO_URI` is missing, and warns
at boot if the secret is a known placeholder. See [`.env.example`](.env.example).

**`.env.client`** — client configuration. Flutter packages this as an asset, so
**anything in it ships inside the APK and is readable by anyone who downloads it**.
Nothing secret goes here.

```ini
API_BASE_URL=http://10.0.2.2:5000/api
```

| Target | `API_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:5000/api` |
| iOS simulator / web | `http://localhost:5000/api` |
| Physical device | `http://<your-LAN-IP>:5000/api` |

### 2. Backend & AI Microservice

To run the Express API server and the Python FastAPI vision clustering microservice concurrently:

```bash
cd server
npm install
npm run dev
```

This script will spin up:
* The Express server at `http://localhost:5000` (reloads automatically using `nodemon`).
* The Python FastAPI vision clustering service at `http://localhost:8000` (reloads automatically using `uvicorn`).

> [!IMPORTANT]
> Make sure that the Python microservice dependencies in `ai_service/requirements.txt` are installed in your active environment before starting.

Alternatively, to launch them separately:

**Run Express Server only:**
```bash
cd server
npm start
```

**Run Python FastAPI service only:**
```bash
cd ai_service
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Seed demo data (optional)

```bash
node server/seed.js
```

Creates two accounts and ten complaints in Bandra West, Mumbai — deliberately
spread so the dashboard has something to say: two past their deadline, three
closed with recorded times, six categories.

| Role | Email | Password |
|---|---|---|
| Citizen | `citizen@civicconnect.org` | `password123` |
| Ward officer | `officer@civicconnect.gov.in` | `password123` |

Sign in as the officer to reach the municipal console from the app bar.

### 4. Flutter client

```bash
flutter pub get
flutter run
```

---

## Tests

```bash
flutter test            # client: SLA, complaint references, cards, theme, stats
cd server && npm test   # server: SLA, wards, sign-in refusals, geo integration
```

The server suite includes integration tests that run against a real MongoDB via
`mongodb-memory-server`, which downloads a `mongod` binary on first run. Without
network access those tests skip rather than fail.

---

## Security and robustness

Things that were wrong and are now handled, in case you are asked:

| | |
|---|---|
| **Secrets** | The server refuses to start without `JWT_SECRET` and `MONGO_URI`, and warns at boot if the secret is the placeholder published in this repo. No hardcoded fallback exists any more. |
| **Google sign-in** | ID tokens are verified against Google's signing keys. With no client IDs configured the endpoint refuses every request rather than trusting the token. |
| **Deep links** | An inbound `?token=` is probed against the API before it may replace a session, and the previous session is restored if rejected. |
| **Uploads** | 8 MB ceiling, one file per request, JPEG/PNG/WebP/HEIC only by both MIME type and extension. Served with `nosniff`. |
| **Brute force** | 20 attempts per 15 minutes on the credential endpoints, 600 per 15 minutes overall. |
| **Ward scoping** | Officers act only on complaints in the wards assigned to them. No assignment means every ward, so the restriction is opt-in. |
| **Client secrets** | `.env.client` is the only env file bundled into the app; the database URI and JWT secret never leave the server. |
| **Errors** | Every endpoint answers with JSON, including 404s, rate limits and crashes, so the client never parses an HTML error page. |

Proximity search uses a `2dsphere` index and `$geoWithin`, so Mongo does the
filtering. Documents predating that field are migrated automatically on boot by
[`server/config/backfill.js`](server/config/backfill.js).

### Still not production-ready

- **Photographs are stored on local disk** in `server/uploads/`. They do not
  survive a container restart and do not scale past one host. Moving to object
  storage is the one remaining structural change.
- **No HTTPS in the development setup.** `usesCleartextTraffic` is enabled on
  Android so the emulator can reach a local HTTP server; turn it off and put the
  API behind TLS before this is reachable from a real network.
- **Ward assignment is by geocoded locality**, not a real boundary registry.
  [`server/config/wards.js`](server/config/wards.js) is the single place to swap
  in a proper lookup.

## Documentation

- [Architecture](docs/architecture.md) — data flow and sequence diagrams
- [Database schema](docs/database_schema.md) — collections, references, indexes
- [Services](docs/services.md) — REST client and geocoding
- [Models](docs/models.md) — Dart model catalogue
- [Screens and widgets](docs/screens_and_widgets.md) — UI component map
- [Setup and configuration](docs/setup_and_configuration.md) — detailed configuration
