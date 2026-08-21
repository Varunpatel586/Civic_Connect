# Civic Connect: Vision Clustering Service

This Python microservice is built using **FastAPI** to evaluate visual duplicates for municipal complaints in the Civic Connect application.

It extracts deep visual semantic features using a lightweight CLIP model (`clip-ViT-B-32`) and compares complaints within a 15-meter radius using Cosine Similarity.

---

## 1. Setup & Installation

### Option A: Automatic Concurrent Run (Recommended)
This service can be run concurrently with the Node.js backend when executing `npm run dev` in the `/server` folder. Make sure to set up Python dependencies first:

```bash
# 1. Navigate to this folder
cd ai_service

# 2. Set up virtual environment
python -m venv venv
venv\Scripts\activate   # On Windows
source venv/bin/activate # On Unix/macOS

# 3. Install packages
pip install -r requirements.txt
```

Once installed, go to `../server` and run `npm run dev` to start both the Express API and this vision service concurrently.

---

## 2. API Specifications

### `POST /api/v1/compare`
Computes Cosine Similarity between a new target image and a list of active candidate issues within range.

#### Request Schema:
```json
{
  "target_image_path": "server/uploads/photo-1700000.jpg",
  "candidates": [
    {
      "issue_id": "66c7b...",
      "image_paths": ["server/uploads/photo-1699999.jpg"]
    }
  ],
  "similarity_threshold": 0.82
}
```

#### Response Schema:
```json
{
  "is_duplicate": true,
  "matched_issue_id": "66c7b...",
  "similarity_score": 0.9412,
  "message": "Match found above threshold"
}
```
