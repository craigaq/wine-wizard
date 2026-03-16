"""
RecommendationService — core scoring engine for Wine Wizard.

Scoring formula
---------------
For each wine attribute a:
    W_Final(a) = W_P(a) × M_S(a)

Where:
    W_P  = preference weight  → user input (1-5) normalised to [0.2, 1.0]
    M_S  = match score        → how closely the wine's profile matches W_P (0.0-1.0)

Food pairing modifiers are applied on top of W_Final:
    adjusted(a) = (W_Final(a) * food_multiplier(a)) + food_boost(a)

The overall wine score is the mean of all adjusted attribute scores.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from food_pairing import FOOD_PAIRING
from term_mapping import TECHNICAL_TO_UI


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class WineProfile:
    """Technical attribute profile for a wine (all values 1-5 scale)."""
    name: str
    acidity: float
    body: float
    tannin: float
    aromatics: float


@dataclass
class UserPreferences:
    """
    User-supplied preference inputs from the UI.

    Attribute names use UI labels; values are integers 1-5.
    food_pairing must be a key present in food_pairing.FOOD_PAIRING.
    """
    crispness_acidity: int      # Crispness (Acidity)
    weight_body: int            # Weight (Body)
    texture_tannin: int         # Texture (Tannin)
    flavor_intensity: int       # Flavor Intensity (Aromatics)
    food_pairing: str = "none"


@dataclass
class ScoredWine:
    """A wine together with its computed recommendation score."""
    wine: WineProfile
    score: float
    attribute_scores: dict[str, float] = field(default_factory=dict)


@dataclass
class FoodPairingAlert:
    """
    Raised when the user's food choice clashes with their palate profile.

    action_type:
        "OVERRIDE"  — the Wizard strongly recommends adjusting preferences
        "WARNING"   — worth noting but not a hard incompatibility

    new_values:
        Dict of UserPreferences field names → suggested replacement values.
        May contain multiple fields (e.g. spicy food adjusts both weight and flavor).
    """
    id: str
    title: str
    message: str
    action_type: str
    new_values: dict[str, int]


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

# Mapping from UserPreferences fields to internal technical attribute names
_PREF_FIELD_TO_ATTR: dict[str, str] = {
    "crispness_acidity": "acidity",
    "weight_body": "body",
    "texture_tannin": "tannin",
    "flavor_intensity": "aromatics",
}

# Ordered tuple of technical attribute names — derived once to avoid repeated dict iteration
_ATTRS: tuple[str, ...] = tuple(_PREF_FIELD_TO_ATTR.values())


def _normalise(user_input: int) -> float:
    """Map a 1-5 user input to a preference weight W_P in [0.2, 1.0]."""
    if not 1 <= user_input <= 5:
        raise ValueError(f"User input must be between 1 and 5, got {user_input}")
    return user_input / 5.0


def _match_score(preference_weight: float, wine_value: float) -> float:
    """
    Compute M_S: how well a wine's attribute value satisfies the preference weight.

    Both preference_weight (W_P) and wine_value are on [0.2, 1.0] after normalisation.
    Returns a value in [0.0, 1.0]; 1.0 = perfect match, 0.0 = opposite ends.
    """
    wine_normalised = wine_value / 5.0
    return 1.0 - abs(preference_weight - wine_normalised)


def _score_attribute(
    attr: str,
    wine_value: float,
    pref_weight: float,
    pairing_cfg: dict,
) -> float:
    """
    Apply the full per-attribute formula and return the adjusted score.

    W_Final  = W_P × M_S
    adjusted = (W_Final × multiplier) + boost
    """
    w_final = pref_weight * _match_score(pref_weight, wine_value)
    multiplier = pairing_cfg["multipliers"].get(attr, 1.0)
    boost = pairing_cfg["boosts"].get(attr, 0.0)
    return (w_final * multiplier) + boost


# ---------------------------------------------------------------------------
# Gastro-clash detection — data-driven rule table
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class _ClashRule:
    """
    A single food/palate incompatibility rule.

    condition:  Lambda that receives UserPreferences and returns True when
                the clash applies.  Evaluated only when food_id matches.
    new_values: Fields to override if the user accepts the Wizard's suggestion.
    """
    food_id:    str
    condition:  Callable[[UserPreferences], bool]
    alert_id:   str
    title:      str
    message:    str
    new_values: dict[str, int]


# Rules are evaluated in order; the first match wins.
# To add a new rule, append a _ClashRule entry — no other code changes needed.
_CLASH_RULES: list[_ClashRule] = [

    # ── White Fish / Shellfish ──────────────────────────────────────────────
    # Tannins react with delicate fish oils → metallic, tinny aftertaste.
    _ClashRule(
        food_id="white_fish",
        condition=lambda p: p.texture_tannin >= 3,
        alert_id="white_fish_tannin_clash",
        title="Wizard Insight: The Metallic Mismatch 🐟",
        message=(
            "You've chosen white fish but your Texture (Tannin) is quite high. "
            "Tannins and delicate fish oils react to create a metallic, tinny taste — "
            "one of the most notorious mismatches in the cellar.\n\n"
            "The Wizard strongly suggests dropping Texture to Silky (1) "
            "so the fish can actually shine."
        ),
        new_values={"texture_tannin": 1},
    ),

    # ── Salmon / Tuna ───────────────────────────────────────────────────────
    # Richer flesh tolerates a little grip — but not a full tannic assault.
    _ClashRule(
        food_id="rich_fish",
        condition=lambda p: p.texture_tannin >= 4,
        alert_id="rich_fish_tannin_clash",
        title="Wizard Insight: Easy on the Grip 🍣",
        message=(
            "Salmon and tuna can handle a light touch of texture — "
            "but at this level the tannins will overpower the fish.\n\n"
            "The Wizard suggests softening Texture to a Gentle (2) "
            "to stay in rosé/light red territory."
        ),
        new_values={"texture_tannin": 2},
    ),

    # ── Spicy Food ──────────────────────────────────────────────────────────
    # High body (alcohol) amplifies capsaicin heat → burning, bitter finish.
    _ClashRule(
        food_id="spicy_food",
        condition=lambda p: p.weight_body >= 4,
        alert_id="spicy_alcohol_clash",
        title="Wizard Insight: Careful with the Heat! 🌶️",
        message=(
            "Bold, heavy wines amplify spicy food — the alcohol fans the flames "
            "and the finish turns bitter.\n\n"
            "The Wizard suggests a Lighter Weight (2) and a touch more "
            "Flavor Intensity (4) — the fruit sweetness will cool the burn."
        ),
        new_values={"weight_body": 2, "flavor_intensity": 4},
    ),

    # ── Tomato-based Pasta / Pizza ──────────────────────────────────────────
    # Flat, low-acid wine tastes dull and flabby against tomato's sharpness.
    _ClashRule(
        food_id="tomato_sauce",
        condition=lambda p: p.crispness_acidity <= 2,
        alert_id="tomato_low_acid_clash",
        title="Wizard Insight: The Flat Tomato Problem 🍅",
        message=(
            "Tomato sauce is highly acidic — a low-crispness wine will taste "
            "flat and lifeless next to it.\n\n"
            "The Wizard suggests lifting Crispness to at least a Medium (3) "
            "so the wine can match the tomato's natural tartness."
        ),
        new_values={"crispness_acidity": 3},
    ),

    # ── Poultry ─────────────────────────────────────────────────────────────
    # Chicken / turkey is too delicate for a heavy tannic assault.
    _ClashRule(
        food_id="poultry",
        condition=lambda p: p.texture_tannin >= 4,
        alert_id="poultry_tannin_clash",
        title="Wizard Insight: Too Much Grip for the Bird 🍗",
        message=(
            "Chicken and turkey have delicate flavours that get steamrolled "
            "by high tannins — the wine ends up tasting bitter and dry.\n\n"
            "The Wizard suggests softening Texture to a Gentle (2) "
            "to let the poultry lead."
        ),
        new_values={"texture_tannin": 2},
    ),
]


def check_food_pairing_conflicts(prefs: UserPreferences) -> FoodPairingAlert | None:
    """
    Scans _CLASH_RULES for the first food/palate mismatch and returns an
    OVERRIDE alert, or None if the profile is harmonious.
    """
    for rule in _CLASH_RULES:
        if prefs.food_pairing == rule.food_id and rule.condition(prefs):
            return FoodPairingAlert(
                id=rule.alert_id,
                title=rule.title,
                message=rule.message,
                action_type="OVERRIDE",
                new_values=rule.new_values,
            )
    return None


# ---------------------------------------------------------------------------
# RecommendationService
# ---------------------------------------------------------------------------

class RecommendationService:
    """
    Scores a list of wines against user preferences and returns ranked results.

    Usage
    -----
    service = RecommendationService(wines)
    results = service.recommend(preferences, top_n=5)
    """

    def __init__(self, wine_catalog: list[WineProfile]) -> None:
        self.wine_catalog = wine_catalog

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def recommend(
        self,
        preferences: UserPreferences,
        top_n: int | None = None,
    ) -> list[ScoredWine]:
        """
        Score every wine in the catalog and return them ranked best-first.

        Parameters
        ----------
        preferences:
            User preference inputs (1-5 per attribute) plus optional food pairing.
        top_n:
            If provided, return only the top N wines.

        Returns
        -------
        List of ScoredWine sorted by descending score.
        """
        pref_weights, pairing_cfg = self._build_scoring_context(preferences)

        scored = sorted(
            (self._score_wine(wine, pref_weights, pairing_cfg) for wine in self.wine_catalog),
            key=lambda s: s.score,
            reverse=True,
        )
        return scored[:top_n] if top_n is not None else scored

    def score_single(
        self,
        wine: WineProfile,
        preferences: UserPreferences,
    ) -> ScoredWine:
        """Score a single wine against the given preferences."""
        pref_weights, pairing_cfg = self._build_scoring_context(preferences)
        return self._score_wine(wine, pref_weights, pairing_cfg)

    # ------------------------------------------------------------------
    # Private helpers (no instance state — static methods)
    # ------------------------------------------------------------------

    @staticmethod
    def _build_scoring_context(
        preferences: UserPreferences,
    ) -> tuple[dict[str, float], dict[str, dict[str, float]]]:
        """Derive pref_weights and pairing_cfg from a UserPreferences instance."""
        pref_weights = {
            attr: _normalise(getattr(preferences, pref_field))
            for pref_field, attr in _PREF_FIELD_TO_ATTR.items()
        }
        pairing_cfg = FOOD_PAIRING.get(preferences.food_pairing, FOOD_PAIRING["none"])
        return pref_weights, pairing_cfg

    @staticmethod
    def _score_wine(
        wine: WineProfile,
        pref_weights: dict[str, float],
        pairing_cfg: dict,
    ) -> ScoredWine:
        """
        Apply the full scoring formula for one wine.

        Step 1: W_Final(a) = W_P(a) × M_S(a)
        Step 2: adjusted(a) = (W_Final(a) × food_multiplier(a)) + food_boost(a)
        Step 3: overall_score = mean(adjusted values)
        """
        attribute_scores: dict[str, float] = {
            TECHNICAL_TO_UI[attr]: round(
                _score_attribute(attr, getattr(wine, attr), pref_weights[attr], pairing_cfg),
                4,
            )
            for attr in _ATTRS
        }
        overall = sum(attribute_scores.values()) / len(attribute_scores)
        return ScoredWine(
            wine=wine,
            score=round(overall, 4),
            attribute_scores=attribute_scores,
        )
