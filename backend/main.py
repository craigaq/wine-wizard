from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional

import dataclasses

from recommendation_service import (
    RecommendationService, WineProfile, UserPreferences,
    check_food_pairing_conflicts,
)
from term_mapping import TECHNICAL_TO_UI
from local_sourcing import find_nearby

app = FastAPI(title="Wine Wizard API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Wine catalog
# ---------------------------------------------------------------------------

_CATALOG: list[WineProfile] = [
    # Whites & Sparkling
    WineProfile("Sauvignon Blanc",  acidity=4.5, body=2.0, tannin=0.5, aromatics=4.0),
    WineProfile("Chardonnay",       acidity=3.0, body=3.5, tannin=0.5, aromatics=3.5),
    WineProfile("Riesling",         acidity=4.5, body=1.5, tannin=0.5, aromatics=4.5),
    WineProfile("Pinot Grigio",     acidity=3.5, body=2.0, tannin=0.5, aromatics=2.5),
    WineProfile("Viognier",         acidity=2.5, body=3.5, tannin=0.5, aromatics=5.0),
    WineProfile("Albariño",         acidity=4.5, body=2.0, tannin=0.5, aromatics=3.5),
    WineProfile("Gewürztraminer",   acidity=3.0, body=2.5, tannin=0.5, aromatics=5.0),
    WineProfile("Moscato",          acidity=3.0, body=1.5, tannin=0.5, aromatics=5.0),
    WineProfile("Prosecco",         acidity=4.5, body=1.5, tannin=0.5, aromatics=3.0),
    WineProfile("Grenache Blanc",   acidity=3.0, body=3.0, tannin=0.5, aromatics=3.5),
    # Reds
    WineProfile("Pinot Noir",           acidity=3.5, body=2.5, tannin=2.5, aromatics=4.0),
    WineProfile("Cabernet Sauvignon",   acidity=3.0, body=4.5, tannin=4.5, aromatics=4.5),
    WineProfile("Malbec",               acidity=3.0, body=4.0, tannin=4.0, aromatics=3.5),
    WineProfile("Syrah/Shiraz",         acidity=3.0, body=4.5, tannin=4.0, aromatics=4.5),
    WineProfile("Grenache",             acidity=3.0, body=3.5, tannin=2.5, aromatics=3.5),
    WineProfile("Tempranillo",          acidity=3.5, body=3.5, tannin=3.5, aromatics=3.5),
    WineProfile("Sangiovese",           acidity=4.0, body=3.0, tannin=3.5, aromatics=3.5),
    WineProfile("Zinfandel",            acidity=3.0, body=4.0, tannin=3.5, aromatics=4.5),
    WineProfile("Nebbiolo",             acidity=4.0, body=4.0, tannin=5.0, aromatics=4.0),
    WineProfile("Bordeaux Blend",       acidity=3.5, body=4.5, tannin=4.5, aromatics=4.0),
]

_service = RecommendationService(_CATALOG)


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class RecommendRequest(BaseModel):
    crispness_acidity: int = Field(..., ge=1, le=5, description="Crispness (Acidity) preference 1-5")
    weight_body: int       = Field(..., ge=1, le=5, description="Weight (Body) preference 1-5")
    texture_tannin: int    = Field(..., ge=1, le=5, description="Texture (Tannin) preference 1-5")
    flavor_intensity: int  = Field(..., ge=1, le=5, description="Flavor Intensity (Aromatics) preference 1-5")
    food_pairing: Optional[str] = Field("none", description="Food pairing backend ID")
    top_n: Optional[int]   = Field(None, ge=1, description="Return top N results")


class WineResult(BaseModel):
    name: str
    score: float
    attribute_scores: dict[str, float]
    wine_profile: dict[str, float]   # raw 1-5 attribute values keyed by UI label


class RecommendResponse(BaseModel):
    recommendations: list[WineResult]
    ui_labels: dict[str, str]
    conflict_alert: Optional[dict] = None
    gastro_clash: Optional[dict] = None


class NearbyRequest(BaseModel):
    wine_name: str
    user_lat: float
    user_lng: float
    budget_min: float = 0.0
    budget_max: float = 9999.0


class MerchantResponse(BaseModel):
    name: str
    address: str
    brand: str
    distance_km: float
    price_usd: float
    score: float


class NearbyResponse(BaseModel):
    wine_name: str
    merchants: list[MerchantResponse]


class CheckPairingResponse(BaseModel):
    gastro_clash: Optional[dict] = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/hello")
def hello():
    return {"message": "Hello from Wine Wizard!"}


@app.get("/check-pairing", response_model=CheckPairingResponse)
def check_pairing(
    food_type: str = Query(..., description="Food pairing selection"),
    crispness_acidity: int = Query(..., ge=1, le=5),
    weight_body: int = Query(..., ge=1, le=5),
    texture_tannin: int = Query(..., ge=1, le=5),
    flavor_intensity: int = Query(..., ge=1, le=5),
):
    """
    Lightweight endpoint: checks for food/palate clashes without running
    the full recommendation engine. Called immediately after food selection
    so the UI can surface a Gastro-Clash alert before the quiz is complete.
    """
    try:
        prefs = UserPreferences(
            crispness_acidity=crispness_acidity,
            weight_body=weight_body,
            texture_tannin=texture_tannin,
            flavor_intensity=flavor_intensity,
            food_pairing=food_type,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    clash = check_food_pairing_conflicts(prefs)
    return CheckPairingResponse(
        gastro_clash=dataclasses.asdict(clash) if clash else None,
    )


def _build_conflict_alert(prefs: UserPreferences) -> dict | None:
    """Return alert data for the first detected palate conflict, or None."""
    # Light body + high tannin — the classic contradiction
    if prefs.weight_body <= 2 and prefs.texture_tannin >= 4:
        return {
            "title": "🧙‍♂️ Your Wizard Senses a Disturbance",
            "message": (
                "Ah — Light Weight with High Texture. Bold. Rare. "
                "Like a featherweight boxer with an iron grip.\n\n"
                "Most light-bodied wines keep their tannins polite and their manners impeccable. "
                "For a wider selection from the cellar, the Wizard suggests softening the Texture."
            ),
            "field": "texture_tannin",
            "suggested_value": 2,
        }
    # Low flavor + high acidity — sharp without expression
    if prefs.flavor_intensity <= 1 and prefs.crispness_acidity >= 4:
        return {
            "title": "🧙‍♂️ The Wizard Raises an Eyebrow",
            "message": (
                "Maximum Crispness with barely any Flavor Intensity — "
                "you're asking for a razor edge with nothing behind it.\n\n"
                "The sharpness would dominate completely. "
                "The Wizard suggests lifting Flavor Intensity so there's something to cut through."
            ),
            "field": "flavor_intensity",
            "suggested_value": 3,
        }
    # Maximum tannin + maximum acidity — very aggressive palate
    if prefs.texture_tannin >= 5 and prefs.crispness_acidity >= 5:
        return {
            "title": "🧙‍♂️ The Wizard Is Impressed (and Concerned)",
            "message": (
                "Maximum Texture AND Maximum Crispness. "
                "You want every molecule of that wine to fight back.\n\n"
                "This is a very narrow field — few wines survive both extremes well. "
                "The Wizard suggests dialling Crispness back slightly for a more satisfying match."
            ),
            "field": "crispness_acidity",
            "suggested_value": 3,
        }
    return None


def _wine_profile_dict(wine: WineProfile) -> dict[str, float]:
    """Return a wine's raw attribute profile keyed by UI labels."""
    return {
        TECHNICAL_TO_UI["acidity"]:   wine.acidity,
        TECHNICAL_TO_UI["body"]:      wine.body,
        TECHNICAL_TO_UI["tannin"]:    wine.tannin,
        TECHNICAL_TO_UI["aromatics"]: wine.aromatics,
    }


@app.post("/recommend", response_model=RecommendResponse)
def recommend(req: RecommendRequest):
    try:
        prefs = UserPreferences(
            crispness_acidity=req.crispness_acidity,
            weight_body=req.weight_body,
            texture_tannin=req.texture_tannin,
            flavor_intensity=req.flavor_intensity,
            food_pairing=req.food_pairing,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    results = _service.recommend(prefs, top_n=req.top_n)

    return RecommendResponse(
        recommendations=[
            WineResult(
                name=r.wine.name,
                score=r.score,
                attribute_scores=r.attribute_scores,
                wine_profile=_wine_profile_dict(r.wine),
            )
            for r in results
        ],
        ui_labels=TECHNICAL_TO_UI,
        conflict_alert=_build_conflict_alert(prefs),
        gastro_clash=(
            dataclasses.asdict(clash)
            if (clash := check_food_pairing_conflicts(prefs))
            else None
        ),
    )


@app.post("/nearby", response_model=NearbyResponse)
def nearby(req: NearbyRequest):
    results = find_nearby(
        wine_name=req.wine_name,
        user_lat=req.user_lat,
        user_lng=req.user_lng,
        budget_min=req.budget_min,
        budget_max=req.budget_max,
    )
    return NearbyResponse(
        wine_name=req.wine_name,
        merchants=[
            MerchantResponse(
                name=r.merchant.name,
                address=r.merchant.address,
                brand=r.brand,
                distance_km=r.distance_km,
                price_usd=r.merchant.price_usd,
                score=r.score,
            )
            for r in results
        ],
    )
