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
