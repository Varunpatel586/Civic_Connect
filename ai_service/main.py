import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import os

app = FastAPI(title="Civic Connect Local Vision Clustering")

class CandidateImage(BaseModel):
    issue_id: str
    image_paths: List[str]

class SimilarityRequest(BaseModel):
    target_image_path: str
    candidates: List[CandidateImage]
    min_inliers_threshold: Optional[int] = 25 

class SimilarityResponse(BaseModel):
    is_duplicate: bool
    matched_issue_id: Optional[str] = None
    similarity_score: float # Inlier count
    message: str

def compute_geometric_match(path1: str, path2: str) -> int:
    """Returns the number of geometrically verified matching keypoints (inliers)."""
    try:
        # 1. Read images in Grayscale
        img1 = cv2.imread(path1, cv2.IMREAD_GRAYSCALE)
        img2 = cv2.imread(path2, cv2.IMREAD_GRAYSCALE)

        if img1 is None or img2 is None:
            return 0

        # 2. Standardize scale (crucial for ORB, which is only partially scale-invariant)
        def resize_img(img, width=600):
            h, w = img.shape
            scale = width / float(w)
            return cv2.resize(img, (width, int(h * scale)))

        img1 = resize_img(img1)
        img2 = resize_img(img2)

        # 3. Detect features using ORB (Oriented FAST and Rotated BRIEF)
        orb = cv2.ORB_create(nfeatures=1500)
        kp1, des1 = orb.detectAndCompute(img1, None)
        kp2, des2 = orb.detectAndCompute(img2, None)

        if des1 is None or des2 is None or len(kp1) < 10 or len(kp2) < 10:
            return 0

        # 4. Match features using Brute Force Hamming distance
        bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
        matches = bf.match(des1, des2)

        if len(matches) < 10:
            return 0

        # 5. Extract coordinates of matched points
        src_pts = np.float32([kp1[m.queryIdx].pt for m in matches]).reshape(-1, 1, 2)
        dst_pts = np.float32([kp2[m.trainIdx].pt for m in matches]).reshape(-1, 1, 2)

        # 6. Apply RANSAC to filter out false matches based on physical geometry
        M, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, 5.0)

        if mask is None:
            return 0

        # The sum of the mask is the exact number of physically verified matching points
        return int(np.sum(mask))

    except Exception as e:
        print(f"CV Error comparing {path1} & {path2}: {str(e)}")
        return 0

@app.post("/api/v1/compare", response_model=SimilarityResponse)
async def compare_images(payload: SimilarityRequest):
    # Log requests to a file for debugging
    log_dir = os.path.dirname(__file__)
    log_file_path = os.path.join(log_dir, "compare_debug.log")
    
    with open(log_file_path, "a") as log_file:
        log_file.write(f"\n--- Request: target={os.path.basename(payload.target_image_path)}, threshold={payload.min_inliers_threshold} ---\n")

    if not payload.candidates:
        with open(log_file_path, "a") as log_file:
            log_file.write("No candidates provided.\n")
        return SimilarityResponse(
            is_duplicate=False, 
            matched_issue_id=None, 
            similarity_score=0.0, 
            message="No candidates provided."
        )

    best_inlier_count = 0
    matched_id = None

    # Transitive Clustering Check: Compare against ALL images in the cluster
    for candidate in payload.candidates:
        for img_path in candidate.image_paths:
            inliers = compute_geometric_match(payload.target_image_path, img_path)
            
            log_line = f"Comparing {os.path.basename(payload.target_image_path)} to {os.path.basename(img_path)}: inliers = {inliers} (candidate issue={candidate.issue_id})\n"
            print(log_line.strip())
            with open(log_file_path, "a") as log_file:
                log_file.write(log_line)
                
            if inliers > best_inlier_count:
                best_inlier_count = inliers
                matched_id = candidate.issue_id

    is_duplicate = bool(best_inlier_count >= payload.min_inliers_threshold)

    with open(log_file_path, "a") as log_file:
        log_file.write(f"Result: is_duplicate={is_duplicate}, highest_inliers={best_inlier_count}, matched_id={matched_id}\n")

    return SimilarityResponse(
        is_duplicate=is_duplicate,
        matched_issue_id=matched_id if is_duplicate else None,
        similarity_score=float(best_inlier_count), 
        message=f"Match found with {best_inlier_count} geometric inliers" if is_duplicate else "No visual duplicate found."
    )
import io
from PIL import Image
from transformers import pipeline
from fastapi import UploadFile, File

# --- Classification -------------------------------------------------------
#
# Zero-shot CLIP scores the image against a fixed list of text prompts and
# softmaxes across them. That carries one consequence worth stating plainly:
# the model can only answer "which of these labels fits best", never "none of
# them". With civic labels alone, a photo of a wall, a face, or pure noise came
# back as a confident street light — random noise measured 0.86 before the
# distractor prompts below existed.
#
# So the candidate list deliberately carries non-civic prompts. If one of them
# wins, the photo is rejected instead of filed. They are never returned as a
# category; they exist only to give the softmax somewhere else to go.

CIVIC_PROMPTS = {
    "a close-up photo of a pothole, a deep hole or crater in the road surface, often filled with muddy water": "pothole",
    "a photo looking up at an outdoor street lamp post, light pole, or dark municipal lantern": "street_light",
    "a photo showing a large pile of garbage, overflowing trash dump, or roadside waste": "garbage",
    "a photo showing flowing water leak, burst pipe flooding, or water supply disruption": "water",
    "a photo showing a clogged drainage ditch, open sewer manhole, or dirty wastewater": "drainage",
    # The pothole and road prompts are deliberately worded to exclude each
    # other: "deep hole" against "with no deep hole". Their first drafts both
    # mentioned broken road surfaces, and every real pothole photo in
    # server/uploads/ was then classified as road. Separating them moved those
    # three from wrong to correct at 0.84-0.98 confidence.
    # Both of these are already in the complaint taxonomy but were missing
    # here, so an electrical hazard was forced into whichever of the other five
    # happened to score highest.
    "a photo of damaged electrical wiring, a fallen power line, or an exposed electrical box": "electricity",
    "a photo of a cracked or uneven road surface or a damaged footpath, with no deep hole": "road",
}

DISTRACTOR_PROMPTS = [
    "a close-up photo of a person, a selfie, or a portrait",
    "a photo taken indoors of a room, furniture, or a wall",
    "a photo of food, a meal, or a drink",
    "a screenshot, a document, or a page of text",
    "a photo of an animal or a pet",
    "a blurry, dark, or meaningless photograph of nothing in particular",
    "a photo of plain sky, a plain wall, or an empty surface",
]

CANDIDATE_LABELS = list(CIVIC_PROMPTS.keys()) + DISTRACTOR_PROMPTS

# Below this the winning label is not clearly ahead of its alternatives, and
# the citizen should pick the category themselves.
CONFIDENCE_FLOOR = 0.38

# Laplacian variance scales with resolution, so a 12 MP phone photo and a
# downscaled copy of the same scene score very differently. Measuring at a
# fixed width first is what makes a single threshold meaningful.
BLUR_WORK_WIDTH = 640
BLUR_FLOOR = 85.0

classifier = None
classifier_error = None


@app.on_event("startup")
def load_models():
    """Warms CLIP once, so the first citizen to file a complaint does not pay
    for the weights loading."""
    global classifier, classifier_error
    try:
        classifier = pipeline(
            "zero-shot-image-classification",
            model="openai/clip-vit-base-patch32",
        )
    except Exception as exc:
        # A failed load must not take the service down: the duplicate matcher
        # above is pure OpenCV and stays useful without CLIP.
        classifier_error = str(exc)
        print(f"[ai] classifier unavailable: {exc}")


def blur_variance_of(cv_img) -> float:
    """Focus measure, normalised for resolution."""
    gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
    height, width = gray.shape[:2]
    if width > BLUR_WORK_WIDTH:
        scale = BLUR_WORK_WIDTH / float(width)
        gray = cv2.resize(gray, (BLUR_WORK_WIDTH, max(1, int(height * scale))))
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


class ClassificationResult(BaseModel):
    category: str
    confidence: float
    is_confident: bool
    blur_score: float
    is_blurry: bool
    # Added rather than renamed: the Flutter client reads the four fields above
    # and keeps working untouched.
    is_civic: bool = True
    reason: str = ""


@app.post("/api/v1/classify", response_model=ClassificationResult)
async def classify_and_check_quality(file: UploadFile = File(...)):
    if classifier is None:
        raise HTTPException(
            status_code=503,
            detail=f"Classifier unavailable: {classifier_error or 'still starting'}",
        )

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        cv_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if cv_img is None:
            raise HTTPException(status_code=400, detail="Invalid image file.")

        blur_score = blur_variance_of(cv_img)
        is_blurry = blur_score < BLUR_FLOOR

        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
        predictions = classifier(pil_img, candidate_labels=CANDIDATE_LABELS)
        top_match = predictions[0]
        confidence = round(float(top_match["score"]), 4)

        category = CIVIC_PROMPTS.get(top_match["label"])

        if category is None:
            # A distractor won. Fall back to the taxonomy's own catch-all so
            # the value is always one the complaint schema will accept.
            return ClassificationResult(
                category="other",
                confidence=confidence,
                is_confident=False,
                blur_score=round(blur_score, 2),
                is_blurry=is_blurry,
                is_civic=False,
                reason="This does not look like a civic issue. Pick a category yourself if it is one.",
            )

        confident = confidence >= CONFIDENCE_FLOOR and not is_blurry
        return ClassificationResult(
            category=category,
            confidence=confidence,
            is_confident=confident,
            blur_score=round(blur_score, 2),
            is_blurry=is_blurry,
            is_civic=True,
            reason=(
                ""
                if confident
                else (
                    "Photo is too blurry to read"
                    if is_blurry
                    else "Not sure what this shows — please confirm the category"
                )
            ),
        )
    # Re-raised before the catch-all, which previously turned the 400 above
    # into a 500.
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class SeverityResult(BaseModel):
    severity_score: int

@app.post("/api/v1/analyze-severity", response_model=SeverityResult)
async def analyze_severity(file: UploadFile = File(...)):
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    cv_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 100, 200)
    edge_density = np.sum(edges > 0) / edges.size
    
    if edge_density > 0.05: score = 5
    elif edge_density > 0.03: score = 4
    elif edge_density > 0.01: score = 3
    elif edge_density > 0.005: score = 2
    else: score = 1
        
    return SeverityResult(severity_score=score)
