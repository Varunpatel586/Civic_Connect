from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from PIL import Image
import torch
import torch.nn.functional as F
from sentence_transformers import SentenceTransformer

app = FastAPI(title="Civic Connect Vision Clustering Service")

# Load lightweight CLIP model on startup
model = None

@app.on_event("startup")
def load_model():
    global model
    # Fast, lightweight vision transformer for semantic visual similarity
    model = SentenceTransformer('clip-ViT-B-32')

class CandidateImage(BaseModel):
    issue_id: str
    image_paths: List[str]

class SimilarityRequest(BaseModel):
    target_image_path: str
    candidates: List[CandidateImage]
    similarity_threshold: Optional[float] = 0.82

class SimilarityResponse(BaseModel):
    is_duplicate: bool
    matched_issue_id: Optional[str] = None
    similarity_score: float
    message: str

def get_image_embedding(image_path: str):
    try:
        img = Image.open(image_path).convert("RGB")
        # Ensure model is not None
        if model is None:
            raise HTTPException(status_code=503, detail="Model not loaded yet")
        embedding = model.encode(img, convert_to_tensor=True)
        return embedding
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process image {image_path}: {str(e)}")

@app.post("/api/v1/compare", response_model=SimilarityResponse)
async def compare_images(payload: SimilarityRequest):
    if not payload.candidates:
        return SimilarityResponse(
            is_duplicate=False,
            matched_issue_id=None,
            similarity_score=0.0,
            message="No candidates provided."
        )

    target_emb = get_image_embedding(payload.target_image_path)
    
    highest_score = -1.0
    matched_id = None

    for candidate in payload.candidates:
        for img_path in candidate.image_paths:
            cand_emb = get_image_embedding(img_path)
            # Cosine similarity
            score = F.cosine_similarity(target_emb.unsqueeze(0), cand_emb.unsqueeze(0)).item()
            
            if score > highest_score:
                highest_score = score
                matched_id = candidate.issue_id

    is_duplicate = bool(highest_score >= payload.similarity_threshold)

    return SimilarityResponse(
        is_duplicate=is_duplicate,
        matched_issue_id=matched_id if is_duplicate else None,
        similarity_score=round(float(highest_score), 4),
        message="Match found above threshold" if is_duplicate else "No visual duplicate found."
    )
