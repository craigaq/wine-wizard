"""
Local sourcing — finds nearby merchants stocking a given wine.

Unicorn Vintage Trap ranking formula
--------------------------------------
avg  = average price across all catalog merchants stocking the wine
ceil = avg × 1.25  (25% price variance ceiling)

If price ≤ ceil  →  R = D_km × 10  + P_AUD              (distance dominant)
If price > ceil  →  R = D_km × 1   + P_AUD + (P/avg)×50  (greed penalty kicks in)

Lower R = better result.

Triple-Region Tier system
--------------------------
Every wine bottle is classified into one of three geographic tiers based on
its production region.  The middleware uses these tiers to surface one best
match per tier for every recommendation.

  Tier 1 — The Local Hero      Adelaide Hills, McLaren Vale, Barossa Valley (SA)
  Tier 2 — The National Rival  Yarra Valley, Margaret River, Hunter Valley (interstate AU)
  Tier 3 — The Global Icon     France, Italy, USA, NZ, Argentina, Spain … (international)

Pricing Precedent (enforced by the interceptor):
  Tier 3 is suppressed when its cheapest option exceeds 5× the cheapest Tier 1 price,
  unless the user explicitly requests it via show_global_tier=True.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass, field

log = logging.getLogger("wine_wizard.sourcing")


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

@dataclass
class WineProduct:
    """A specific wine bottle stocked by a merchant.

    brand  : Producer / label name  (e.g., "Penfolds RWT").
    region : Wine's production region (e.g., "Barossa Valley, SA").
             Used to classify the bottle into a geographic tier.
    """
    brand:  str
    region: str


@dataclass
class Merchant:
    name:   str
    address: str
    lat:    float
    lng:    float
    price_aud: float
    search_url_template: str = ""       # URL with {brand} placeholder for deep-linking to wine search
    wines: dict[str, WineProduct] = field(default_factory=dict)  # variety → WineProduct
    data_source: str = "Scraped_Data"   # Direct_API | Manual_Upload | Scraped_Data
    last_updated_hours: float = 48.0    # Hours since inventory feed was last refreshed


@dataclass
class MerchantResult:
    merchant:    Merchant
    brand:       str
    region:      str    # wine production region (from WineProduct)
    tier:        int    # 1 | 2 | 3 — geographic tier
    distance_km: float
    # Fields below are populated by the middleware interceptor
    score:             float = 0.0
    confidence_score:  float = 0.0
    needs_verification: bool = False


# ---------------------------------------------------------------------------
# Geographic tier classification
# ---------------------------------------------------------------------------

TIER_LABELS: dict[int, str] = {
    1: "The Local Hero",
    2: "The National Rival",
    3: "The Global Icon",
}

TIER_REGION_HINTS: dict[int, str] = {
    1: "Adelaide Hills, McLaren Vale, Barossa Valley",
    2: "Yarra Valley (VIC), Margaret River (WA), Hunter Valley (NSW)",
    3: "France (Rhône/Bordeaux), Italy (Piedmont), USA (Napa/Oregon)",
}


def get_region_tier(region: str) -> int:
    """Return the geographic tier (1–3) for a wine's production region.

    Checks Tier 1 (SA) first, then Tier 2 (interstate AU); everything else
    defaults to Tier 3 (international).
    """
    r = region.lower()
    # Tier 1 — South Australian producers (minimise food miles, support SA)
    if any(k in r for k in (
        "adelaide hills", "mclaren vale", "barossa", "clare valley",
        "eden valley", "coonawarra", "langhorne creek", "riverland",
        "padthaway", "wrattonbully", "south australia", ", sa",
    )):
        return 1
    # Tier 2 — Interstate Australian producers
    if any(k in r for k in (
        "yarra valley", "mornington", "gippsland", "king valley",
        "grampians", "heathcote", "victoria", ", vic",
        "margaret river", "great southern", "swan valley",
        "western australia", ", wa",
        "hunter valley", "mudgee", "riverina", "orange",
        "new south wales", ", nsw",
        "canberra", "tasmania", ", tas",
        ", aus",
    )):
        return 2
    # Tier 3 — International (France, Italy, USA, NZ, Argentina, Spain …)
    return 3


# ---------------------------------------------------------------------------
# Merchant catalog — Adelaide, South Australia
# (Replace with DB query in production — the Wizard knows this is temporary)
#
# Tier coverage key:
#   T1 = SA producer   T2 = Interstate AU   T3 = International
# ---------------------------------------------------------------------------

MERCHANT_CATALOG: list[Merchant] = [
    # ── Vintage Cellars ─────────────────────────────────────────────────────
    # Real chain (Endeavour Group). Multiple SA locations.
    Merchant(
        name="Vintage Cellars Rundle Mall",
        address="Rundle Mall, Adelaide CBD, SA 5000",
        lat=-34.9214, lng=138.6010,
        price_aud=31.99,
        search_url_template="https://www.vintagecellars.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc": WineProduct("Shaw + Smith",            "Adelaide Hills, SA"),   # T1
            "Chardonnay":      WineProduct("Leeuwin Estate",          "Margaret River, WA"),   # T2
            "Pinot Grigio":    WineProduct("Grosset",                 "Clare Valley, SA"),     # T1
            "Riesling":        WineProduct("Henschke",                "Eden Valley, SA"),      # T1
            "Moscato":         WineProduct("Brown Brothers Moscato",  "King Valley, VIC"),     # T2
            "Airén":           WineProduct("El Coto de Rioja Blanco", "La Rioja, Spain"),      # T3
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),
    # ── Dan Murphy's ────────────────────────────────────────────────────────
    # Real chain (Endeavour Group). danmurphys.com.au
    Merchant(
        name="Dan Murphy's Adelaide City",
        address="76 Grote Street, Adelaide CBD, SA 5000",
        lat=-34.9290, lng=138.5986,
        price_aud=23.99,
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",             "Barossa Valley, SA"),   # T1
            "Malbec":             WineProduct("Zuccardi Valle",               "Mendoza, Argentina"),   # T3
            "Syrah/Shiraz":       WineProduct("Wolf Blass Gold Label",        "Barossa Valley, SA"),   # T1
            "Chardonnay":         WineProduct("Wolf Blass",                   "Barossa Valley, SA"),   # T1
            "Pinot Noir":         WineProduct("Yering Station",               "Yarra Valley, VIC"),    # T2
            "Merlot":             WineProduct("Penfolds Thomas Hyland",       "Barossa Valley, SA"),   # T1
            "Grenache":           WineProduct("d'Arenberg The Stump Jump",    "McLaren Vale, SA"),     # T1
            "Red Blend":          WineProduct("d'Arenberg The Stump Jump GSM","McLaren Vale, SA"),     # T1
            "Zinfandel":          WineProduct("Ravenswood Vintners Blend",    "Sonoma, USA"),          # T3
        },
        data_source="Direct_API",
        last_updated_hours=0.25,
    ),
    Merchant(
        name="Dan Murphy's Marion",
        address="297 Diagonal Road, Oaklands Park, SA 5046",
        lat=-35.0140, lng=138.5504,
        price_aud=23.99,
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",          "Barossa Valley, SA"),   # T1
            "Syrah/Shiraz":       WineProduct("Penfolds RWT",              "Barossa Valley, SA"),   # T1
            "Chardonnay":         WineProduct("Petaluma",                  "Adelaide Hills, SA"),   # T1
            "Pinot Noir":         WineProduct("Yering Station",            "Yarra Valley, VIC"),    # T2
            "Malbec":             WineProduct("Zuccardi Valle",            "Mendoza, Argentina"),   # T3
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",              "Adelaide Hills, SA"),   # T1
            "Riesling":           WineProduct("Henschke",                  "Eden Valley, SA"),      # T1
            "Red Blend":          WineProduct("Penfolds Bin 138 GSM",      "Barossa Valley, SA"),   # T1
            "Grenache":           WineProduct("d'Arenberg The Stump Jump", "McLaren Vale, SA"),     # T1
            "Tempranillo":        WineProduct("Bodegas Muga Rioja Reserva","Rioja, Spain"),         # T3
            "Sangiovese":         WineProduct("Antinori Tignanello",       "Tuscany, Italy"),       # T3
            "Zinfandel":          WineProduct("Ridge Lytton Springs",      "Sonoma, USA"),          # T3
            # Middle Ground compromise varietals
            "Gewürztraminer (Dry)":  WineProduct("Trimbach Alsace",        "Alsace, France"),       # T3
            "Grüner Veltliner":      WineProduct("Domäne Wachau Federspiel","Wachau, Austria"),     # T3
            "Chenin Blanc (Dry)":    WineProduct("Domaine Huet Vouvray Sec","Loire Valley, France"),# T3
        },
        data_source="Direct_API",
        last_updated_hours=0.5,
    ),
    # ── BWS ─────────────────────────────────────────────────────────────────
    # Real chain (Endeavour Group). bws.com.au
    Merchant(
        name="BWS Norwood",
        address="175 The Parade, Norwood, SA 5067",
        lat=-34.9218, lng=138.6302,
        price_aud=20.99,
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc":        WineProduct("Jacob's Creek",                    "Barossa Valley, SA"),      # T1
            "Pinot Grigio":           WineProduct("Banrock Station",                  "Riverland, SA"),           # T1
            "Riesling":               WineProduct("Peter Lehmann",                    "Barossa Valley, SA"),      # T1
            "Malbec":                 WineProduct("Angove",                           "McLaren Vale, SA"),        # T1
            "Merlot":                 WineProduct("Jacob's Creek Classic",            "Barossa Valley, SA"),      # T1
            "Tempranillo":            WineProduct("Angove Long Row",                  "McLaren Vale, SA"),        # T1
            "Carménère":              WineProduct("Concha y Toro Casillero del Diablo","Maipo Valley, Chile"),    # T3
            "Trebbiano Toscano":      WineProduct("Berton Vineyard",                  "Riverina, NSW"),           # T2
            "Sauvignonasse/Friulano": WineProduct("Cono Sur Bicicleta",               "Casablanca Valley, Chile"),# T3
        },
        data_source="Direct_API",
        last_updated_hours=2.0,
    ),
    Merchant(
        name="BWS Burnside",
        address="447 Portrush Road, Burnside, SA 5066",
        lat=-34.9277, lng=138.6598,
        price_aud=22.99,
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Syrah/Shiraz":       WineProduct("Penfolds RWT",             "Barossa Valley, SA"),   # T1
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 389",         "Barossa Valley, SA"),   # T1
            "Riesling":           WineProduct("Yalumba",                  "Eden Valley, SA"),      # T1
            "Chardonnay":         WineProduct("Petaluma Hanlin Hill",     "Adelaide Hills, SA"),   # T1
            "Pinot Noir":         WineProduct("Bass Phillip Premium",     "Gippsland, VIC"),       # T2
            "Sauvignon Blanc":    WineProduct("Dog Point",                "Marlborough, NZ"),      # T3
            "Pinot Grigio":       WineProduct("Timo Mayer",               "Yarra Valley, VIC"),    # T2
            "Malbec":             WineProduct("Clos de los Siete",        "Mendoza, Argentina"),   # T3
            "Red Blend":          WineProduct("Penfolds Bin 138 GSM",     "Barossa Valley, SA"),   # T1
            "Grenache":           WineProduct("Château Rayas Châteauneuf-du-Pape","Rhône Valley, France"),# T3
        },
        data_source="Direct_API",
        last_updated_hours=3.0,
    ),
    # ── First Choice Liquor ──────────────────────────────────────────────────
    # Real chain (Coles Group). firstchoiceliquor.com.au
    Merchant(
        name="First Choice Liquor Glenelg",
        address="Broadway Kurralta Park, 151 Anzac Hwy, Kurralta Park, SA 5037",
        lat=-34.9800, lng=138.5161,
        price_aud=26.99,
        search_url_template="https://www.firstchoiceliquor.com.au/search?searchTerm={brand}",
        wines={
            "Syrah/Shiraz":    WineProduct("Best's Great Western Shiraz",  "Grampians, VIC"),           # T2
            "Malbec":          WineProduct("Catena Zapata",                "Mendoza, Argentina"),       # T3
            "Sauvignon Blanc": WineProduct("Wirra Wirra",                  "McLaren Vale, SA"),         # T1
            "Pinot Grigio":    WineProduct("Banrock Station",              "Riverland, SA"),            # T1
            "Sangiovese":      WineProduct("Ruffino Chianti",              "Tuscany, Italy"),           # T3
            "Carménère":       WineProduct("Undurraga Carménère",          "Colchagua Valley, Chile"),  # T3
            "Chenin Blanc":    WineProduct("Indaba Chenin Blanc",          "Western Cape, South Africa"),# T3
            "Airén":           WineProduct("Bodegas Lozano La Mancha",     "La Mancha, Spain"),         # T3
        },
        data_source="Direct_API",
        last_updated_hours=1.0,
    ),
    # ── Liquorland ───────────────────────────────────────────────────────────
    # Real chain (Coles Group). liquorland.com.au
    Merchant(
        name="Liquorland Prospect",
        address="253 Prospect Road, Prospect, SA 5082",
        lat=-34.8878, lng=138.5997,
        price_aud=21.99,
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Pinot Noir":             WineProduct("Squealing Pig",                     "Marlborough, NZ"),         # T3
            "Sauvignon Blanc":        WineProduct("Oyster Bay",                        "Marlborough, NZ"),         # T3
            "Malbec":                 WineProduct("Angove",                            "McLaren Vale, SA"),        # T1
            "Pinot Grigio":           WineProduct("Jacob's Creek",                     "Barossa Valley, SA"),      # T1
            "Merlot":                 WineProduct("Lindeman's Bin 40",                 "Coonawarra, SA"),          # T1
            "Red Blend":              WineProduct("19 Crimes",                         "Victoria, AUS"),           # T2
            "Sauvignonasse/Friulano": WineProduct("Borgo Conventi Friulano",           "Friuli, Italy"),           # T3
            "Trebbiano Toscano":      WineProduct("Frascati Superiore Fontana Candida","Lazio, Italy"),            # T3
        },
        data_source="Direct_API",
        last_updated_hours=6.0,
    ),
    Merchant(
        name="Liquorland Unley",
        address="204 Unley Road, Unley, SA 5061",
        lat=-34.9418, lng=138.5987,
        price_aud=21.99,
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Pinot Noir":         WineProduct("Grosset",            "Clare Valley, SA"),    # T1
            "Chardonnay":         WineProduct("Petaluma",           "Adelaide Hills, SA"),  # T1
            "Riesling":           WineProduct("Grosset Polish Hill","Clare Valley, SA"),    # T1
            "Cabernet Sauvignon": WineProduct("Wynns Coonawarra",   "Coonawarra, SA"),      # T1
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",       "Adelaide Hills, SA"),  # T1
            "Syrah/Shiraz":       WineProduct("Turkey Flat",        "Barossa Valley, SA"),  # T1
        },
        data_source="Direct_API",
        last_updated_hours=6.0,
    ),
    # ── Vintage Cellars (second location) ────────────────────────────────────
    Merchant(
        name="Vintage Cellars Henley Beach",
        address="262 Henley Beach Road, Henley Beach, SA 5022",
        lat=-34.9199, lng=138.4998,
        price_aud=33.99,
        search_url_template="https://www.vintagecellars.com.au/search?q={brand}",
        wines={
            "Chardonnay":      WineProduct("Yalumba",                "Eden Valley, SA"),    # T1
            "Riesling":        WineProduct("Jim Barry The Florita",  "Clare Valley, SA"),   # T1
            "Sauvignon Blanc": WineProduct("Wirra Wirra Mrs Wigley", "McLaren Vale, SA"),   # T1
            "Syrah/Shiraz":    WineProduct("Turkey Flat",            "Barossa Valley, SA"), # T1
            "Pinot Noir":      WineProduct("Leeuwin Estate Art Series","Margaret River, WA"),# T2
            "Merlot":          WineProduct("Duckhorn Three Palms",   "Napa Valley, USA"),   # T3
            "Malbec":          WineProduct("Achaval Ferrer",         "Mendoza, Argentina"), # T3
            "Pinot Grigio":    WineProduct("Jermann",                "Friuli, Italy"),      # T3
            # Middle Ground compromise varietals
            "Gewürztraminer (Dry)":  WineProduct("Zind-Humbrecht Alsace",          "Alsace, France"),       # T3
            "Grüner Veltliner":      WineProduct("Nikolaihof Wachau Reserve",      "Wachau, Austria"),      # T3
            "Chenin Blanc (Dry)":    WineProduct("Clos Rougeard Saumur Blanc Sec", "Loire Valley, France"), # T3
            "Chenin Blanc":          WineProduct("Mullineux Old Vines",            "Swartland, South Africa"),# T3
            "Trebbiano Toscano":     WineProduct("Lungarotti Rubesco Bianco",      "Umbria, Italy"),        # T3
            "Sauvignonasse/Friulano":WineProduct("Vie di Romans Friulano",         "Friuli, Italy"),        # T3
            "Tempranillo":           WineProduct("Vega Sicilia Unico",             "Ribera del Duero, Spain"),# T3
            "Sangiovese":            WineProduct("Sassicaia Bolgheri",             "Tuscany, Italy"),       # T3
            "Zinfandel":             WineProduct("Ridge Monte Bello",              "Santa Cruz Mountains, USA"),# T3
            "Carménère":             WineProduct("Almaviva Puente Alto",           "Maipo Valley, Chile"),  # T3
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),
]


# ---------------------------------------------------------------------------
# Inventory Ghost — confidence scoring
# ---------------------------------------------------------------------------

_SOURCE_CONFIDENCE: dict[str, float] = {
    "Direct_API":    0.95,  # Real-time sync
    "Manual_Upload": 0.60,  # Updated daily/weekly
    "Scraped_Data":  0.40,  # High risk of being outdated
}

_VERIFICATION_THRESHOLD = 0.70  # Below this → show "Call to Confirm" badge


def get_stock_certainty(data_source: str, last_updated_hours: float) -> tuple[float, bool]:
    """Return (confidence_score, needs_verification) for a merchant's inventory data.

    Confidence decays at 0.05 per hour from the source baseline, floored at 0.10.
    Scores below 0.70 trigger the "Call to Confirm" badge in the UI.
    """
    base = _SOURCE_CONFIDENCE.get(data_source, 0.40)
    time_decay = last_updated_hours * 0.05
    score = max(0.10, base - time_decay)
    return round(score, 3), score < _VERIFICATION_THRESHOLD


# ---------------------------------------------------------------------------
# Distance + ranking
# ---------------------------------------------------------------------------

def _avg_market_price(wine_name: str) -> float:
    """Average price across every catalog merchant that stocks wine_name."""
    prices = [m.price_aud for m in MERCHANT_CATALOG if wine_name in m.wines]
    return sum(prices) / len(prices) if prices else 0.0


def calculate_merchant_rank(distance: float, price: float, avg_market_price: float) -> float:
    """Unicorn Vintage Trap ranking — lower score = better result."""
    if avg_market_price <= 0:
        return distance * 10 + price
    price_ceiling = avg_market_price * 1.25
    if price > price_ceiling:
        adjusted_wd   = 1.0
        penalty_score = (price / avg_market_price) * 50
    else:
        adjusted_wd   = 10.0
        penalty_score = 0.0
    return distance * adjusted_wd + price * 1.0 + penalty_score


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two GPS coordinates in kilometres."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def find_raw_candidates(
    wine_name: str,
    user_lat: float,
    user_lng: float,
    budget_min: float = 0.0,
    budget_max: float = 9999.0,
) -> list[MerchantResult]:
    """Return merchants stocking wine_name within budget, with distance and tier populated.

    Results are unranked — score, confidence_score, and needs_verification are
    left at defaults.  The middleware interceptor applies Unicorn Vintage Trap
    ranking and Inventory Ghost freshness scoring before results reach the API layer.
    """
    results: list[MerchantResult] = []

    for merchant in MERCHANT_CATALOG:
        if wine_name not in merchant.wines:
            continue
        if not (budget_min <= merchant.price_aud <= budget_max):
            log.info(
                "[Budget Gate] EXCLUDED  %-35s  $%.2f outside budget $%.2f–$%.2f",
                merchant.name, merchant.price_aud, budget_min, budget_max,
            )
            continue
        product = merchant.wines[wine_name]
        tier    = get_region_tier(product.region)
        d       = haversine_km(user_lat, user_lng, merchant.lat, merchant.lng)
        log.info(
            "[Budget Gate] PASSED     %-35s  $%.2f  %.2f km  tier=%d  region=%s",
            merchant.name, merchant.price_aud, d, tier, product.region,
        )
        results.append(MerchantResult(
            merchant=merchant,
            brand=product.brand,
            region=product.region,
            tier=tier,
            distance_km=round(d, 2),
        ))

    return results
