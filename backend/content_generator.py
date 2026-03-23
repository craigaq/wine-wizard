"""
Wine Wizard — Content Generation Middleware
===========================================
Generates persona-driven, witty and educational blurbs for each
Triple-Region tier recommendation.

Output per tier
---------------
  wit            — Short, punchy one-liner (3 options per tier, deterministically
                   rotated so the same wine always gets the same line).
  edu_insight    — Template-filled educational hook using wine-specific soil,
                   climate, tasting note, and method data.
  comparison_note — How THIS tier differs from the other two (uses real producer names).

Persona Matrix
--------------
  Tier 1  Local Hero      "The Proud Neighbour"
  Tier 2  National Rival  "The Friendly Competitor"
  Tier 3  Global Icon     "The Sophisticated Elder"
"""

from __future__ import annotations

from dataclasses import dataclass

from local_sourcing import MerchantResult


# ---------------------------------------------------------------------------
# Output model
# ---------------------------------------------------------------------------

@dataclass
class TierBlurb:
    persona:          str   # "The Proud Neighbour" | "The Friendly Competitor" | "The Sophisticated Elder"
    wit:              str   # Short punchy one-liner
    edu_insight:      str   # Template-filled educational hook
    comparison_note:  str   # How this tier differs from the other two


_PERSONAS = {
    1: "The Proud Neighbour",
    2: "The Friendly Competitor",
    3: "The Sophisticated Elder",
}


# ---------------------------------------------------------------------------
# Wit statement pools  (3 per tier — deterministically rotated by wine name)
# ---------------------------------------------------------------------------

_WIT: dict[str, list[str]] = {
    "local": [
        "So local, you could practically walk to the cellar door. (Don't though — take an Uber.)",
        "Grown just down the road. It's basically your neighbour in a bottle.",
        "The SA sun captured in glass. It's a local legend for a reason.",
    ],
    "national": [
        "The interstate rival. It's like the State of Origin, but everyone wins.",
        "Coming to you from across the border — don't tell the locals you liked it.",
        "A little holiday in a glass from {region}.",
    ],
    "global": [
        "The passport-required option. Very fancy. Pinky finger up.",
        "The 'Original Gangster' of this style. It's travelled further than most people do in a year.",
        "The benchmark. It's the wine other wines want to be when they grow up.",
    ],
}


# ---------------------------------------------------------------------------
# Template data  (keyed by lowercase region keyword)
# ---------------------------------------------------------------------------

# Primary tasting notes per wine variety
_TASTING_NOTES: dict[str, str] = {
    "Cabernet Sauvignon":    "dark cassis and cedar",
    "Merlot":                "plum and dark chocolate",
    "Pinot Noir":            "red cherry and earthy forest floor",
    "Syrah/Shiraz":          "dark plum and cracked black pepper",
    "Grenache":              "red berry and warm spice",
    "Sangiovese":            "sour cherry and dried herbs",
    "Malbec":                "dark plum and violet",
    "Red Blend":             "rich dark berry and warming spice",
    "Zinfandel":             "blackberry jam and smoky oak",
    "Tempranillo":           "leather and dried cherry",
    "Carménère":             "green pepper and dark fruit",
    "Chardonnay":            "stone fruit and toasted oak",
    "Sauvignon Blanc":       "crisp citrus and fresh herbs",
    "Riesling":              "lime zest and mineral slate",
    "Pinot Grigio":          "green apple and light citrus",
    "Chenin Blanc":          "honey and green apple",
    "Moscato":               "peach blossom and lychee",
    "Grüner Veltliner":      "white pepper and citrus",
    "Gewürztraminer (Dry)":  "lychee and rose petal",
    "Chenin Blanc (Dry)":    "quince and waxy lemon",
    "Trebbiano Toscano":     "light citrus and subtle mineral",
    "Airén":                 "neutral citrus and green apple",
    "Sauvignonasse/Friulano":"peach and white blossom",
}

# SA soil types per region keyword  (for Local edu_hook → [SoilType])
_SA_SOILS: dict[str, str] = {
    "barossa":        "ancient pre-Phylloxera loam",
    "mclaren vale":   "ancient marine sediment over clay and limestone",
    "clare valley":   "quartz-rich limestone",
    "eden valley":    "ancient Cambrian slate and quartzite",
    "coonawarra":     "Terra Rossa over pure white limestone",
    "adelaide hills": "thin, rocky clay",
    "langhorne creek":"deep alluvial silt",
    "riverland":      "sandy loam over clay",
    "padthaway":      "terra rossa soils",
}

# National climate types per region keyword  (for National edu_hook → [ClimateType])
_NATIONAL_CLIMATES: dict[str, str] = {
    "yarra valley":    "cool continental",
    "mornington":      "maritime",
    "grampians":       "high-altitude cool",
    "margaret river":  "maritime Mediterranean",
    "hunter valley":   "humid subtropical",
    "tasmania":        "cold maritime",
    "orange":          "high-altitude cool continental",
    "king valley":     "cool mountain continental",
    "gippsland":       "cool maritime",
    "victoria":        "cool continental",
    "western australia":"maritime Mediterranean",
    "new south wales": "varied continental",
}

# National specific attributes per region keyword  (for National edu_hook → [SpecificAttribute])
_NATIONAL_ATTRIBUTES: dict[str, str] = {
    "yarra valley":   "silky, fine-boned",
    "mornington":     "delicately structured",
    "grampians":      "peppery, restrained",
    "margaret river": "naturally balanced",
    "hunter valley":  "earthy, complex",
    "tasmania":       "pristine, precise",
    "orange":         "crisp, high-altitude",
    "king valley":    "aromatic, continental",
    "gippsland":      "concentrated, cool-climate",
    "victoria":       "cool-climate elegant",
    "western australia": "naturally balanced",
}

# International traditional methods per region keyword  (for Global edu_hook → [TraditionalMethod])
_INTERNATIONAL_METHODS: dict[str, str] = {
    "rhône":           "traditional co-fermentation with Viognier and gentle whole-cluster pressing",
    "bordeaux":        "careful blending with Merlot and extended French oak barrel ageing",
    "burgundy":        "small 228L barrique fermentation and minimal-intervention winemaking",
    "tuscany":         "long maceration of Sangiovese and extended large-cask ageing",
    "piedmont":        "extended maceration of Nebbiolo and mandatory Barolo/Barbaresco cask ageing",
    "rioja":           "extended American oak ageing under the strict Crianza/Reserva/Gran Reserva system",
    "ribera del duero":"high-altitude viticulture and cool-night temperature variation to retain acid",
    "mendoza":         "high-altitude viticulture above 1,000m and long cold-soak maceration",
    "maipo":           "gravity-flow winemaking in hillside wineries and extended maceration",
    "colchagua":       "controlled fermentation and gentle extraction to preserve varietal character",
    "casablanca":      "night-time harvesting to preserve natural acidity and aromatics",
    "alsace":          "late-harvest timing and minimal sulphur additions to preserve natural aromatics",
    "wachau":          "strict Federspiel/Smaragd quality classification and steep Danube-terrace viticulture",
    "napa":            "extended warm-climate hang time and new French oak barrel ageing",
    "sonoma":          "diverse single-vineyard selection and whole-cluster inclusion",
    "marlborough":     "cool-tank stainless steel fermentation to lock in fresh varietal aromatics",
    "new zealand":     "cool-climate canopy management and temperature-controlled fermentation",
    "austria":         "Smaragd-classification terraced viticulture on steep Danube-facing slopes",
    "south africa":    "old bush-vine dry farming and minimal-intervention winemaking",
    "swartland":       "natural fermentation from wild yeasts on old dry-farmed bush vines",
    "friuli":          "skin-contact maceration and extended lees ageing for texture",
    "france":          "appellation-controlled viticulture and traditional méthode ancienne winemaking",
    "italy":           "native yeast fermentation and long maceration on skins",
    "spain":           "extended maceration and oak-classification ageing rules enforced by law",
    "argentina":       "high Andean altitude viticulture and dramatic cold-night temperature swing",
    "chile":           "gravity-flow winemaking in hillside wineries and minimal filtration",
    "germany":         "Prädikat-classification late-harvest selection and cool slow fermentation",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find(region: str, lookup: dict[str, str], default: str = "") -> str:
    """Return the first matching value where the key appears in region (case-insensitive)."""
    r = region.lower()
    for key, value in lookup.items():
        if key in r:
            return value
    return default


def _wit_index(wine_name: str) -> int:
    """Deterministic 0-2 index so the same wine always gets the same wit line."""
    return sum(ord(c) for c in wine_name) % 3


def _primary_note(wine_name: str) -> str:
    return _TASTING_NOTES.get(wine_name, "complex fruit and spice")


# ---------------------------------------------------------------------------
# Per-tier template fillers
# ---------------------------------------------------------------------------

def _local_edu(wine_name: str, region: str) -> str:
    soil = _find(region, _SA_SOILS, "distinctive SA soils")
    note = _primary_note(wine_name)
    return (
        f"Notice the {note} — that comes from our unique {soil} "
        f"and the cooling breezes off the Gulf St Vincent."
    )


def _national_edu(wine_name: str, region: str) -> str:
    climate   = _find(region, _NATIONAL_CLIMATES, "cool continental")
    attribute = _find(region, _NATIONAL_ATTRIBUTES, "distinctive")
    # Trim to just the city/valley name for readability
    short_region = region.split(",")[0].strip()
    return (
        f"Unlike our local heat, {short_region} is {climate}, "
        f"which gives this wine a {attribute} finish."
    )


def _global_edu(wine_name: str, region: str) -> str:
    method = _find(region, _INTERNATIONAL_METHODS, "traditional Old World winemaking methods")
    short_region = region.split(",")[0].strip()
    return (
        f"This is the classic {wine_name} from {short_region}. "
        f"It uses {method} to achieve that world-famous structure."
    )


# ---------------------------------------------------------------------------
# Comparison notes  (generated across all three tiers together)
# ---------------------------------------------------------------------------

# Short character descriptors per region for comparison sentences
_CHARACTER: dict[str, str] = {
    # SA
    "barossa":        "sun-soaked richness",
    "mclaren vale":   "bold coastal power",
    "adelaide hills": "cool-altitude elegance",
    "clare valley":   "crisp mineral drive",
    "eden valley":    "refined mineral precision",
    "coonawarra":     "Terra Rossa structure",
    "langhorne creek":"supple lake-cooled fruit",
    # National
    "yarra valley":   "silky cool-climate finesse",
    "mornington":     "delicate maritime grace",
    "grampians":      "peppery high-altitude restraint",
    "margaret river": "dual-ocean balance",
    "hunter valley":  "earthy aged complexity",
    "tasmania":       "pristine cold-maritime purity",
    "orange":         "crisp high-altitude brightness",
    # International
    "rhône":          "the Old World Syrah archetype",
    "bordeaux":       "the Cabernet blueprint",
    "burgundy":       "centuries of Pinot refinement",
    "mendoza":        "bold Andean altitude power",
    "napa":           "New World opulence",
    "tuscany":        "ancient Sangiovese tradition",
    "rioja":          "oak-aged Spanish grace",
    "marlborough":    "razor-sharp New Zealand precision",
    "wachau":         "mineral Austrian distinction",
    "alsace":         "aromatic Alsatian expressiveness",
    "casablanca":     "cool Pacific Chilean freshness",
    "south africa":   "two-ocean Cape character",
    "friuli":         "structured northern Italian precision",
}


def _char(region: str, tier: int) -> str:
    ch = _find(region, _CHARACTER)
    if ch:
        return ch
    return {1: "SA character", 2: "cool-climate Australian character", 3: "international benchmark character"}[tier]


def _build_comparison_notes(
    tier_groups: dict[int, list[MerchantResult]],
) -> dict[int, str]:
    t1 = tier_groups[1][0] if tier_groups[1] else None
    t2 = tier_groups[2][0] if tier_groups[2] else None
    t3 = tier_groups[3][0] if tier_groups[3] else None

    c1 = _char(t1.region, 1) if t1 else "local SA character"
    c2 = _char(t2.region, 2) if t2 else "national Australian character"
    c3 = _char(t3.region, 3) if t3 else "international benchmark character"

    notes: dict[int, str] = {}

    if t1:
        rivals = []
        if t2:
            rivals.append(f"{t2.brand}'s {c2}")
        if t3:
            rivals.append(f"{t3.brand}'s {c3}")
        if rivals:
            notes[1] = (
                "Richer and more expressive than "
                + " and ".join(rivals)
                + " — and it hasn't had to travel far to reach you."
            )
        else:
            notes[1] = "The only option on the map right now, but it's a strong one."

    if t2:
        base = f"More restrained than {t1.brand}'s {c1}" if t1 else "A distinctive Australian take"
        if t3:
            notes[2] = (
                f"{base}, and more approachable in style than {t3.brand}'s {c3}. "
                f"The middle ground between local pride and international prestige."
            )
        else:
            notes[2] = f"{base} — a genuine alternative perspective on the same grape."

    if t3:
        if t1 and t2:
            notes[3] = (
                f"The original blueprint. Where {t1.brand} brings {c1} "
                f"and {t2.brand} brings {c2}, this is the version that "
                f"shaped what this grape became worldwide."
            )
        elif t1:
            notes[3] = (
                f"The style that inspired {t1.brand}'s {c1} — "
                f"the Old World original the New World is still in conversation with."
            )
        else:
            notes[3] = (
                "The international benchmark — the version every other bottle "
                "in this flight has been measured against."
            )

    return notes


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def generate_tier_blurbs(
    tier_groups: dict[int, list[MerchantResult]],
    wine_name: str,
) -> dict[int, TierBlurb]:
    """
    Generate persona-driven wit + educational blurbs for each populated tier.

    Returns a dict keyed by tier number (1 / 2 / 3).
    Tiers with no results are omitted.
    """
    idx = _wit_index(wine_name)
    comparison_notes = _build_comparison_notes(tier_groups)

    blurbs: dict[int, TierBlurb] = {}

    if tier_groups[1]:
        best = tier_groups[1][0]
        wit_line = _WIT["local"][idx]
        blurbs[1] = TierBlurb(
            persona=_PERSONAS[1],
            wit=wit_line,
            edu_insight=_local_edu(wine_name, best.region),
            comparison_note=comparison_notes.get(1, ""),
        )

    if tier_groups[2]:
        best = tier_groups[2][0]
        wit_line = _WIT["national"][idx].format(region=best.region.split(",")[0].strip())
        blurbs[2] = TierBlurb(
            persona=_PERSONAS[2],
            wit=wit_line,
            edu_insight=_national_edu(wine_name, best.region),
            comparison_note=comparison_notes.get(2, ""),
        )

    if tier_groups[3]:
        best = tier_groups[3][0]
        blurbs[3] = TierBlurb(
            persona=_PERSONAS[3],
            wit=_WIT["global"][idx],
            edu_insight=_global_edu(wine_name, best.region),
            comparison_note=comparison_notes.get(3, ""),
        )

    return blurbs
