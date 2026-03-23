"""
Wine Wizard — Mock Wine Database
=================================
Authoritative wine catalog built from the Enhanced Data Schema.

Section 1  — Top 20 globally ranked grape varieties (source: consumer demand
             and planting data).  Covers the wines a real-world retail API
             is most likely to surface.  Used to test Sourcing and Middle
             Ground algorithms against a broad, realistic population.

Section 2  — Middle Ground compromise varietals.  Dry but aromatically intense;
             used by the find_compromise Palate Paradox resolution path.
             Must satisfy: varietal in COMPROMISE_VARIETALS AND style == "Dry".

Enhanced Data Schema field reference
--------------------------------------
sku_id             : str          Unique identifier — inventory tracking.
acidity_ph         : float        pH 2.8–4.0  (lower = more acidic).
body               : float        1–5 expert body rating (Light → Full).
tannin_structure   : int          1–5 tannin perception (Silk → Grip).
aromatic_intensity : int          1–10 (Neutral → Intense).
abv_percentage     : float        Alcohol by Volume %.
residual_sugar_gl  : float        g/L RS; < 5 g/L = "dry on paper" (OIV).
style              : str          "Dry" | "Off-Dry" | "Sweet".
varietal           : str          Grape variety for filter matching.

Internal scoring fields (auto-derived in WineProfile.__post_init__):
  acidity   = 1 + (4.0 − acidity_ph) / 1.2 × 4   (inverted pH → 1-5)
  tannin    = float(tannin_structure)
  aromatics = aromatic_intensity / 2.0              (1-10 → 0.5-5.0)
  alcohol_abv = abv_percentage
"""

from __future__ import annotations

from recommendation_service import WineProfile


# ---------------------------------------------------------------------------
# Section 1 — Top 20 Globally Ranked Grape Varieties
# ---------------------------------------------------------------------------
# Columns:  name            sku       pH     body  tan  arom  ABV    RS g/L

#
# ── Reds ────────────────────────────────────────────────────────────────────
#
_REDS: list[WineProfile] = [

    # Rank 1 — Most planted; consistently top-ranked by consumers
    WineProfile(
        "Cabernet Sauvignon", sku_id="WW-CS01",
        acidity_ph=3.40, body=4.5, tannin_structure=5, aromatic_intensity=9,
        abv_percentage=14.0, residual_sugar_gl=2.0,
        location_tag="Local",           # Coonawarra & Barossa are world-benchmark SA regions
    ),

    # Rank 3 — Strong preference in US, UK, Germany; massive plantings
    WineProfile(
        "Merlot", sku_id="WW-ME01",
        acidity_ph=3.50, body=3.5, tannin_structure=3, aromatic_intensity=6,
        abv_percentage=13.5, residual_sugar_gl=2.0,
        location_tag="National",        # Produced nationally (Barossa, Riverland) but Bordeaux is the benchmark
        # Soft plum/chocolate profile; lower pH than Cab means slightly
        # higher acidity score (≈ 2.67) but still medium-low crispness.
    ),

    # Rank 5 — Universal premium appeal; strong planting footprint
    WineProfile(
        "Pinot Noir", sku_id="WW-PN01",
        acidity_ph=3.25, body=2.5, tannin_structure=3, aromatic_intensity=8,
        abv_percentage=13.0, residual_sugar_gl=2.0,
        location_tag="National",        # Australian identity centred in Yarra Valley VIC & Mornington Peninsula
    ),

    # Rank 6 — Key player in Australia and globally
    WineProfile(
        "Syrah/Shiraz", sku_id="WW-SH01",
        acidity_ph=3.40, body=4.5, tannin_structure=4, aromatic_intensity=9,
        abv_percentage=14.5, residual_sugar_gl=2.0,
        location_tag="Local",           # Barossa Valley SA is THE global benchmark for Shiraz
    ),

    # Rank 7 — Dominates Spain; moderate global market presence
    WineProfile(
        "Tempranillo", sku_id="WW-TP01",
        acidity_ph=3.25, body=3.5, tannin_structure=4, aromatic_intensity=7,
        abv_percentage=13.5, residual_sugar_gl=3.0,
        location_tag="International",   # Rioja & Ribera del Duero Spain are the canonical home
    ),

    # Rank 10 — Mediterranean blend essential; high volume consumption
    WineProfile(
        "Grenache", sku_id="WW-GR01",
        acidity_ph=3.40, body=3.5, tannin_structure=3, aromatic_intensity=7,
        abv_percentage=14.5, residual_sugar_gl=3.0,
        location_tag="Local",           # McLaren Vale SA produces world-class Grenache
    ),

    # Rank 13 — Italy's most planted grape; global respect for Chianti
    WineProfile(
        "Sangiovese", sku_id="WW-SG01",
        acidity_ph=3.10, body=3.0, tannin_structure=4, aromatic_intensity=7,
        abv_percentage=13.5, residual_sugar_gl=2.0,
        location_tag="International",   # Tuscany Italy (Chianti, Brunello)
    ),

    # Rank 14 — Argentina's flagship; international fame in red wine
    WineProfile(
        "Malbec", sku_id="WW-MB01",
        acidity_ph=3.40, body=4.0, tannin_structure=4, aromatic_intensity=7,
        abv_percentage=14.5, residual_sugar_gl=3.0,
        location_tag="International",   # Mendoza Argentina is the global benchmark
    ),

    # Rank 15 — Gaining major ground especially in the US (GSM-style blend)
    WineProfile(
        "Red Blend", sku_id="WW-RB01",
        acidity_ph=3.35, body=4.0, tannin_structure=3, aromatic_intensity=7,
        abv_percentage=14.0, residual_sugar_gl=3.0,
        location_tag="National",        # Australian GSM tradition (McLaren Vale SA / Barossa) — national style identity
        # Generic GSM (Grenache-Syrah-Mourvèdre) profile — fruit-forward,
        # moderate tannin, food-friendly acidity.
    ),

    # Rank 17 — Big presence in US (California rosé & reds)
    WineProfile(
        "Zinfandel", sku_id="WW-ZF01",
        acidity_ph=3.40, body=4.0, tannin_structure=4, aromatic_intensity=9,
        abv_percentage=15.0, residual_sugar_gl=4.0,
        location_tag="International",   # Sonoma & Napa Valley California USA
    ),

    # Rank 19 — Chile's signature red; niche but growing
    WineProfile(
        "Carménère", sku_id="WW-CA01",
        acidity_ph=3.40, body=3.5, tannin_structure=3, aromatic_intensity=7,
        abv_percentage=13.5, residual_sugar_gl=2.0,
        location_tag="International",   # Maipo & Colchagua Valley Chile
        # Herbaceous green-pepper terpenes (pyrazines) similar to Cab Franc;
        # medium tannin, medium-low acidity.  Niche sourcing test case.
    ),
]

#
# ── Whites & Sparkling ───────────────────────────────────────────────────────
#
_WHITES: list[WineProfile] = [

    # Rank 2 — Top international white; leading in US, Japan, UK
    WineProfile(
        "Chardonnay", sku_id="WW-CH01",
        acidity_ph=3.40, body=3.5, tannin_structure=1, aromatic_intensity=7,
        abv_percentage=13.5, residual_sugar_gl=2.0,
        location_tag="Local",           # Adelaide Hills SA is a globally regarded Chardonnay region
    ),

    # Rank 4 — Number one in Australia, UK, NZ; fast global growth
    WineProfile(
        "Sauvignon Blanc", sku_id="WW-SB01",
        acidity_ph=2.95, body=2.0, tannin_structure=1, aromatic_intensity=8,
        abv_percentage=12.5, residual_sugar_gl=2.0,
        location_tag="National",        # Margaret River WA is the leading Australian expression
    ),

    # Rank 8 — High popularity in UK, Canada, US; solid global footprint
    WineProfile(
        "Pinot Grigio", sku_id="WW-PG01",
        acidity_ph=3.25, body=2.0, tannin_structure=1, aromatic_intensity=5,
        abv_percentage=12.0, residual_sugar_gl=2.0,
        location_tag="International",   # Friuli & Alto Adige Italy
    ),

    # Rank 9 — Low-profile internationally; huge in Spain (volume impact)
    WineProfile(
        "Airén", sku_id="WW-AI01",
        acidity_ph=3.20, body=1.5, tannin_structure=1, aromatic_intensity=2,
        abv_percentage=11.0, residual_sugar_gl=2.0,
        location_tag="International",   # La Mancha Spain — world's most planted white grape by area
        # Very neutral, high-acid Spanish white grown mainly for distillation.
        # aromatic_intensity=2 → aromatics=1.0 — will always FAIL the
        # Middle Ground aromatic filter.  Useful negative test case.
    ),

    # Rank 11 — Key in Germany, China, US; specialty appeal growing
    WineProfile(
        "Riesling", sku_id="WW-RI01",
        acidity_ph=2.95, body=1.5, tannin_structure=1, aromatic_intensity=9,
        abv_percentage=9.5, residual_sugar_gl=3.5,
        location_tag="Local",           # Clare Valley & Eden Valley SA are world-class Riesling regions
    ),

    # Rank 12 — Huge volume via Italian whites, Cognac, Armagnac
    WineProfile(
        "Trebbiano Toscano", sku_id="WW-TR01",
        acidity_ph=3.05, body=1.5, tannin_structure=1, aromatic_intensity=3,
        abv_percentage=11.5, residual_sugar_gl=2.0,
        location_tag="International",   # Tuscany & Umbria Italy / Cognac France
        # High acid, very neutral aromatics — the archetypal volume white.
        # aromatic_intensity=3 → aromatics=1.5 — fails Middle Ground filter.
    ),

    # Rank 16 — Versatile; strong in South Africa and Loire Valley
    WineProfile(
        "Chenin Blanc", sku_id="WW-CN01",
        acidity_ph=3.05, body=2.5, tannin_structure=1, aromatic_intensity=7,
        abv_percentage=12.5, residual_sugar_gl=7.0,
        style="Off-Dry",
        location_tag="International",   # Loire Valley France & Swartland South Africa
        # Standard Loire/Vouvray demi-sec style — RS 7 g/L puts it just
        # above the OIV dry ceiling; will be filtered out by filter_by_profile
        # but passes Middle Ground aromatics check (intensity=7 → 3.5).
    ),

    # Rank 18 — Sweet, sparkling styles boosting global consumption
    WineProfile(
        "Moscato", sku_id="WW-MO01",
        acidity_ph=3.40, body=1.5, tannin_structure=1, aromatic_intensity=10,
        abv_percentage=6.5, residual_sugar_gl=100.0,
        style="Sweet",
        location_tag="International",   # Piedmont Italy (Asti Spumante)
    ),

    # Rank 20 — Significant European/South American footprint
    WineProfile(
        "Sauvignonasse/Friulano", sku_id="WW-SF01",
        acidity_ph=3.30, body=2.0, tannin_structure=1, aromatic_intensity=6,
        abv_percentage=12.5, residual_sugar_gl=2.0,
        location_tag="International",   # Friuli Italy & Colchagua Valley Chile
        # Rounder, less grassy than Sauvignon Blanc; similar crisp acidity
        # (score ≈ 3.33) but lower aromatic intensity.
    ),
]


# ---------------------------------------------------------------------------
# Section 2 — Middle Ground Compromise Varietals
# ---------------------------------------------------------------------------
# Must satisfy:  varietal in COMPROMISE_VARIETALS  AND  style == "Dry"
# These are technically dry but aromatically intense enough to sub for
# off-dry pairings with spicy food (Palate Paradox → find_compromise path).
#
_MIDDLE_GROUND: list[WineProfile] = [

    # Dry Alsatian style — lychee/rose terpenes without residual sugar
    WineProfile(
        "Gewürztraminer (Dry)", sku_id="WW-GD01",
        varietal="Gewürztraminer", style="Dry",
        acidity_ph=3.25, body=2.5, tannin_structure=1, aromatic_intensity=10,
        abv_percentage=12.5, residual_sugar_gl=2.5,
        location_tag="International",   # Alsace France
    ),

    # Federspiel (Wachau) — stone fruit, white pepper, high acid, low ABV
    WineProfile(
        "Grüner Veltliner", sku_id="WW-GV01",
        varietal="Grüner Veltliner", style="Dry",
        acidity_ph=2.95, body=2.0, tannin_structure=1, aromatic_intensity=7,
        abv_percentage=11.5, residual_sugar_gl=2.0,
        location_tag="International",   # Wachau & Kamptal Austria
    ),

    # Vouvray Sec — honeyed texture from glycerol; high tartaric acid cleanses spice
    WineProfile(
        "Chenin Blanc (Dry)", sku_id="WW-CB01",
        varietal="Chenin Blanc", style="Dry",
        acidity_ph=2.95, body=3.0, tannin_structure=1, aromatic_intensity=8,
        abv_percentage=12.5, residual_sugar_gl=3.0,
        location_tag="International",   # Loire Valley France (Vouvray Sec)
    ),
]


# ---------------------------------------------------------------------------
# Exported catalog
# ---------------------------------------------------------------------------

WINE_DATABASE: list[WineProfile] = _REDS + _WHITES + _MIDDLE_GROUND

# Lookup by wine name — useful for sourcing layer and tests
WINE_BY_NAME: dict[str, WineProfile] = {w.name: w for w in WINE_DATABASE}
