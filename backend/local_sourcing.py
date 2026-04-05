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

Commercial Group system
------------------------
Every merchant belongs to a commercial_group:
  "endeavour"   — Dan Murphy's, BWS  (Endeavour Group ASX: EDV)
  "coles_liquor"— Liquorland, Liquorland Cellars, Liquorland Warehouse (Coles Group)
  "independent" — East End Cellars, Fassina Liquor, Cellarbrations
  "online"      — Vinomofo, Naked Wines, The Wine Collective, Wine Selectors, etc.

When a preferred_partner is set in PARTNER_CONFIG, that group's results are
boosted in ranking and competitor group results are filtered out.  All boosted
results carry a [Partner] badge in the UI (disclosed to users).
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass, field

log = logging.getLogger("wine_wizard.sourcing")


# ---------------------------------------------------------------------------
# Partner configuration — set commercial_group to activate boost + exclusion
# ---------------------------------------------------------------------------
# Leave preferred_partner as None for neutral / no-deal operation.
# Set to "endeavour" or "coles_liquor" when a commercial agreement is active.
# "independent" and "online" groups are never excluded (they have no competitor
# relationship with retail chains and their presence improves result quality).
#
PARTNER_CONFIG: dict = {
    "preferred_partner": None,      # None | "endeavour" | "coles_liquor"
    "partner_rank_boost": 0.25,     # Subtract from rank score (lower = better)
    "exclude_rival_group": True,    # When True, rival chain group is hidden
}

# Map of rival pairs — when one group is preferred, the other is excluded
_RIVAL_GROUPS: dict[str, str] = {
    "endeavour":   "coles_liquor",
    "coles_liquor": "endeavour",
}


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
    name:               str
    address:            str
    lat:                float
    lng:                float
    price_aud:          float
    commercial_group:   str   = "independent"  # endeavour | coles_liquor | independent | online
    search_url_template: str  = ""             # URL with {brand} placeholder for deep-linking
    wines: dict[str, WineProduct] = field(default_factory=dict)  # variety → WineProduct
    data_source:        str   = "Scraped_Data" # Direct_API | Manual_Upload | Scraped_Data
    last_updated_hours: float = 48.0           # Hours since inventory feed was last refreshed
    is_online_only:     bool  = False          # True for delivery-only retailers


@dataclass
class MerchantResult:
    merchant:    Merchant
    brand:       str
    region:      str    # wine production region (from WineProduct)
    tier:        int    # 1 | 2 | 3 — geographic tier
    distance_km: float
    is_partner:  bool  = False   # True when merchant belongs to preferred_partner group
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
    """Return the geographic tier (1–3) for a wine's production region."""
    r = region.lower()
    if any(k in r for k in (
        "adelaide hills", "mclaren vale", "barossa", "clare valley",
        "eden valley", "coonawarra", "langhorne creek", "riverland",
        "padthaway", "wrattonbully", "south australia", ", sa",
    )):
        return 1
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
    return 3


# ---------------------------------------------------------------------------
# Merchant catalog — Adelaide, South Australia
#
# Groups:
#   endeavour    — Dan Murphy's (9 SA stores), BWS (24 SA metro stores)
#   coles_liquor — Liquorland, Liquorland Cellars (ex-Vintage Cellars),
#                  Liquorland Warehouse (ex-First Choice)
#   independent  — East End Cellars, Fassina Liquor, Cellarbrations
#   online       — Vinomofo, Naked Wines, The Wine Collective, Wine Selectors,
#                  Just Wines, Laithwaites AU
#
# NOTE: All prices and stock are PLACEHOLDER values pending validator scrape.
#       The merchant_validator.py layer will replace price_aud with live values
#       and mark each entry as validated=True when confirmed on the merchant site.
# ---------------------------------------------------------------------------

MERCHANT_CATALOG: list[Merchant] = [

    # =========================================================================
    # ENDEAVOUR GROUP — Dan Murphy's
    # =========================================================================

    Merchant(
        name="Dan Murphy's Adelaide City",
        address="76 Grote Street, Adelaide CBD, SA 5000",
        lat=-34.9290, lng=138.5986,
        price_aud=23.99,
        commercial_group="endeavour",
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",              "Barossa Valley, SA"),
            "Malbec":             WineProduct("Zuccardi Valle",                "Mendoza, Argentina"),
            "Syrah/Shiraz":       WineProduct("Wolf Blass Gold Label",         "Barossa Valley, SA"),
            "Chardonnay":         WineProduct("Wolf Blass",                    "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Yering Station",                "Yarra Valley, VIC"),
            "Merlot":             WineProduct("Penfolds Thomas Hyland",        "Barossa Valley, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump",     "McLaren Vale, SA"),
            "Red Blend":          WineProduct("d'Arenberg The Stump Jump GSM", "McLaren Vale, SA"),
            "Zinfandel":          WineProduct("Ravenswood Vintners Blend",     "Sonoma, USA"),
        },
        data_source="Direct_API",
        last_updated_hours=0.25,
    ),

    Merchant(
        name="Dan Murphy's Marion",
        address="297 Diagonal Road, Oaklands Park, SA 5046",
        lat=-35.0140, lng=138.5504,
        price_aud=23.99,
        commercial_group="endeavour",
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon":    WineProduct("Penfolds Bin 407",               "Barossa Valley, SA"),
            "Syrah/Shiraz":          WineProduct("Penfolds RWT",                   "Barossa Valley, SA"),
            "Chardonnay":            WineProduct("Petaluma",                       "Adelaide Hills, SA"),
            "Pinot Noir":            WineProduct("Yering Station",                 "Yarra Valley, VIC"),
            "Malbec":                WineProduct("Zuccardi Valle",                 "Mendoza, Argentina"),
            "Sauvignon Blanc":       WineProduct("Shaw + Smith",                   "Adelaide Hills, SA"),
            "Riesling":              WineProduct("Henschke",                       "Eden Valley, SA"),
            "Red Blend":             WineProduct("Penfolds Bin 138 GSM",           "Barossa Valley, SA"),
            "Grenache":              WineProduct("d'Arenberg The Stump Jump",      "McLaren Vale, SA"),
            "Tempranillo":           WineProduct("Bodegas Muga Rioja Reserva",     "Rioja, Spain"),
            "Sangiovese":            WineProduct("Antinori Tignanello",            "Tuscany, Italy"),
            "Zinfandel":             WineProduct("Ridge Lytton Springs",           "Sonoma, USA"),
            "Gewürztraminer (Dry)":  WineProduct("Trimbach Alsace",                "Alsace, France"),
            "Grüner Veltliner":      WineProduct("Domäne Wachau Federspiel",       "Wachau, Austria"),
            "Chenin Blanc (Dry)":    WineProduct("Domaine Huet Vouvray Sec",       "Loire Valley, France"),
        },
        data_source="Direct_API",
        last_updated_hours=0.5,
    ),

    Merchant(
        name="Dan Murphy's Torrensville",
        address="38A South Road, Torrensville, SA 5031",
        lat=-34.9380, lng=138.5620,
        price_aud=23.99,
        commercial_group="endeavour",
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Wynns Black Label",             "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Penfolds St Henri",             "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Stonier Reserve",               "Mornington Peninsula, VIC"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",                  "Adelaide Hills, SA"),
            "Chardonnay":         WineProduct("Leeuwin Estate Art Series",     "Margaret River, WA"),
            "Riesling":           WineProduct("Grosset Polish Hill",           "Clare Valley, SA"),
            "Merlot":             WineProduct("Penfolds Thomas Hyland",        "Barossa Valley, SA"),
            "Red Blend":          WineProduct("Penfolds Bin 138 GSM",          "Barossa Valley, SA"),
            "Tempranillo":        WineProduct("Torres Gran Sangre de Toro",    "Catalunya, Spain"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier",  "Eden Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=1.0,
    ),

    Merchant(
        name="Dan Murphy's Marden",
        address="9 Lower Portrush Road, Marden, SA 5070",
        lat=-34.9050, lng=138.6410,
        price_aud=23.99,
        commercial_group="endeavour",
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Katnook Estate",                "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Langmeil Freedom",              "Barossa Valley, SA"),
            "Grenache":           WineProduct("Yangarra Old Vine",             "McLaren Vale, SA"),
            "Sauvignon Blanc":    WineProduct("Wirra Wirra Mrs Wigley",        "McLaren Vale, SA"),
            "Chardonnay":         WineProduct("Grosset Piccadilly",            "Adelaide Hills, SA"),
            "Pinot Grigio":       WineProduct("Heemskerk",                     "Tasmania, TAS"),
            "Malbec":             WineProduct("Achaval Ferrer",                "Mendoza, Argentina"),
            "Sangiovese":         WineProduct("Coriole",                       "McLaren Vale, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=1.5,
    ),

    Merchant(
        name="Dan Murphy's Gilles Plains",
        address="575 North East Road, Gilles Plains, SA 5086",
        lat=-34.8500, lng=138.6500,
        price_aud=23.99,
        commercial_group="endeavour",
        search_url_template="https://www.danmurphys.com.au/search?searchTerm={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",          "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Wolf Blass Gold Label",     "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Yering Station",            "Yarra Valley, VIC"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",              "Adelaide Hills, SA"),
            "Chardonnay":         WineProduct("Wolf Blass",                "Barossa Valley, SA"),
            "Riesling":           WineProduct("Henschke",                  "Eden Valley, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump", "McLaren Vale, SA"),
            "Malbec":             WineProduct("Zuccardi Valle",            "Mendoza, Argentina"),
        },
        data_source="Direct_API",
        last_updated_hours=2.0,
    ),

    # =========================================================================
    # ENDEAVOUR GROUP — BWS
    # =========================================================================

    Merchant(
        name="BWS Norwood",
        address="175 The Parade, Norwood, SA 5067",
        lat=-34.9218, lng=138.6302,
        price_aud=20.99,
        commercial_group="endeavour",
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc":        WineProduct("Jacob's Creek",                      "Barossa Valley, SA"),
            "Pinot Grigio":           WineProduct("Banrock Station",                    "Riverland, SA"),
            "Riesling":               WineProduct("Peter Lehmann",                      "Barossa Valley, SA"),
            "Malbec":                 WineProduct("Angove",                             "McLaren Vale, SA"),
            "Merlot":                 WineProduct("Jacob's Creek Classic",              "Barossa Valley, SA"),
            "Tempranillo":            WineProduct("Angove Long Row",                    "McLaren Vale, SA"),
            "Carménère":              WineProduct("Concha y Toro Casillero del Diablo", "Maipo Valley, Chile"),
            "Trebbiano Toscano":      WineProduct("Berton Vineyard",                    "Riverina, NSW"),
            "Sauvignonasse/Friulano": WineProduct("Cono Sur Bicicleta",                 "Casablanca Valley, Chile"),
        },
        data_source="Direct_API",
        last_updated_hours=2.0,
    ),

    Merchant(
        name="BWS Burnside",
        address="447 Portrush Road, Burnside, SA 5066",
        lat=-34.9277, lng=138.6598,
        price_aud=22.99,
        commercial_group="endeavour",
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Syrah/Shiraz":       WineProduct("Penfolds RWT",          "Barossa Valley, SA"),
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 389",      "Barossa Valley, SA"),
            "Riesling":           WineProduct("Yalumba",               "Eden Valley, SA"),
            "Chardonnay":         WineProduct("Petaluma Hanlin Hill",  "Adelaide Hills, SA"),
            "Pinot Noir":         WineProduct("Yering Station",        "Yarra Valley, VIC"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",          "Adelaide Hills, SA"),
            "Pinot Grigio":       WineProduct("Timo Mayer",            "Yarra Valley, VIC"),
            "Malbec":             WineProduct("Clos de los Siete",     "Mendoza, Argentina"),
            "Red Blend":          WineProduct("Penfolds Bin 138 GSM",  "Barossa Valley, SA"),
            "Grenache":           WineProduct("Wirra Wirra",           "McLaren Vale, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=3.0,
    ),

    Merchant(
        name="BWS Unley",
        address="204 Unley Road, Unley, SA 5061",
        lat=-34.9418, lng=138.5987,
        price_aud=20.99,
        commercial_group="endeavour",
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc":    WineProduct("Jacob's Creek",             "Barossa Valley, SA"),
            "Chardonnay":         WineProduct("Wolf Blass Yellow Label",   "Barossa Valley, SA"),
            "Pinot Grigio":       WineProduct("Banrock Station",           "Riverland, SA"),
            "Merlot":             WineProduct("Jacob's Creek Classic",     "Barossa Valley, SA"),
            "Cabernet Sauvignon": WineProduct("Wolf Blass Yellow Label",   "Barossa Valley, SA"),
            "Riesling":           WineProduct("Peter Lehmann",             "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Squealing Pig",             "Marlborough, NZ"),
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),

    Merchant(
        name="BWS Glenelg",
        address="Bayside Village, 1 Colley Terrace, Glenelg, SA 5045",
        lat=-34.9802, lng=138.5154,
        price_aud=20.99,
        commercial_group="endeavour",
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc":    WineProduct("Jacob's Creek",           "Barossa Valley, SA"),
            "Pinot Grigio":       WineProduct("Banrock Station",         "Riverland, SA"),
            "Merlot":             WineProduct("Jacob's Creek Classic",   "Barossa Valley, SA"),
            "Cabernet Sauvignon": WineProduct("Wolf Blass Yellow Label", "Barossa Valley, SA"),
            "Riesling":           WineProduct("Peter Lehmann",           "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Penfolds Koonunga Hill",  "Barossa Valley, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump","McLaren Vale, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),

    Merchant(
        name="BWS North Adelaide",
        address="86 O'Connell Street, North Adelaide, SA 5006",
        lat=-34.9058, lng=138.5941,
        price_aud=20.99,
        commercial_group="endeavour",
        search_url_template="https://www.bws.com.au/search?q={brand}",
        wines={
            "Pinot Noir":         WineProduct("Yering Station",          "Yarra Valley, VIC"),
            "Chardonnay":         WineProduct("Petaluma",                "Adelaide Hills, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",            "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Grosset Polish Hill",     "Clare Valley, SA"),
            "Cabernet Sauvignon": WineProduct("Wynns Coonawarra",        "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Turkey Flat",             "Barossa Valley, SA"),
            "Malbec":             WineProduct("Angove",                  "McLaren Vale, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=3.0,
    ),

    # =========================================================================
    # COLES LIQUOR GROUP — Liquorland
    # =========================================================================

    Merchant(
        name="Liquorland Prospect",
        address="253 Prospect Road, Prospect, SA 5082",
        lat=-34.8878, lng=138.5997,
        price_aud=21.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Pinot Noir":             WineProduct("Squealing Pig",                      "Marlborough, NZ"),
            "Sauvignon Blanc":        WineProduct("Oyster Bay",                         "Marlborough, NZ"),
            "Malbec":                 WineProduct("Angove",                             "McLaren Vale, SA"),
            "Pinot Grigio":           WineProduct("Jacob's Creek",                      "Barossa Valley, SA"),
            "Merlot":                 WineProduct("Lindeman's Bin 40",                  "Coonawarra, SA"),
            "Red Blend":              WineProduct("19 Crimes",                          "Victoria, AUS"),
            "Sauvignonasse/Friulano": WineProduct("Borgo Conventi Friulano",            "Friuli, Italy"),
            "Trebbiano Toscano":      WineProduct("Frascati Superiore Fontana Candida", "Lazio, Italy"),
        },
        data_source="Direct_API",
        last_updated_hours=6.0,
    ),

    Merchant(
        name="Liquorland Unley",
        address="204 Unley Road, Unley, SA 5061",
        lat=-34.9418, lng=138.5987,
        price_aud=21.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Pinot Noir":         WineProduct("Grosset",             "Clare Valley, SA"),
            "Chardonnay":         WineProduct("Petaluma",            "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Grosset Polish Hill", "Clare Valley, SA"),
            "Cabernet Sauvignon": WineProduct("Wynns Coonawarra",    "Coonawarra, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",        "Adelaide Hills, SA"),
            "Syrah/Shiraz":       WineProduct("Turkey Flat",         "Barossa Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=6.0,
    ),

    Merchant(
        name="Liquorland Marion",
        address="Westfield Marion, 297 Diagonal Road, Oaklands Park, SA 5046",
        lat=-35.0130, lng=138.5510,
        price_aud=21.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Wynns Black Label",      "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Geoff Merrill",          "McLaren Vale, SA"),
            "Sauvignon Blanc":    WineProduct("Oyster Bay",             "Marlborough, NZ"),
            "Chardonnay":         WineProduct("Squealing Pig",          "Marlborough, NZ"),
            "Pinot Noir":         WineProduct("Squealing Pig",          "Marlborough, NZ"),
            "Merlot":             WineProduct("Lindeman's Bin 40",      "Coonawarra, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump","McLaren Vale, SA"),
            "Riesling":           WineProduct("Wolf Blass Yellow Label", "Barossa Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=8.0,
    ),

    # =========================================================================
    # COLES LIQUOR GROUP — Liquorland Cellars (ex-Vintage Cellars, rebranded 2025)
    # =========================================================================

    Merchant(
        name="Liquorland Cellars Hutt Street",
        address="143 Hutt Street, Adelaide SA 5000",
        lat=-34.9311, lng=138.6078,
        price_aud=33.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Chardonnay":            WineProduct("Yalumba",                    "Eden Valley, SA"),
            "Riesling":              WineProduct("Jim Barry The Florita",      "Clare Valley, SA"),
            "Sauvignon Blanc":       WineProduct("Wirra Wirra Mrs Wigley",     "McLaren Vale, SA"),
            "Syrah/Shiraz":          WineProduct("Turkey Flat",                "Barossa Valley, SA"),
            "Pinot Noir":            WineProduct("Leeuwin Estate Art Series",  "Margaret River, WA"),
            "Merlot":                WineProduct("Duckhorn Three Palms",       "Napa Valley, USA"),
            "Malbec":                WineProduct("Achaval Ferrer",             "Mendoza, Argentina"),
            "Pinot Grigio":          WineProduct("Jermann",                    "Friuli, Italy"),
            "Gewürztraminer (Dry)":  WineProduct("Zind-Humbrecht Alsace",      "Alsace, France"),
            "Grüner Veltliner":      WineProduct("Nikolaihof Wachau Reserve",  "Wachau, Austria"),
            "Chenin Blanc (Dry)":    WineProduct("Clos Rougeard Saumur Blanc", "Loire Valley, France"),
            "Chenin Blanc":          WineProduct("Mullineux Old Vines",        "Swartland, South Africa"),
            "Tempranillo":           WineProduct("Vega Sicilia Unico",         "Ribera del Duero, Spain"),
            "Sangiovese":            WineProduct("Sassicaia Bolgheri",         "Tuscany, Italy"),
            "Zinfandel":             WineProduct("Ridge Monte Bello",          "Santa Cruz Mountains, USA"),
            "Carménère":             WineProduct("Almaviva Puente Alto",       "Maipo Valley, Chile"),
            "Viognier (Dry)":        WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),

    Merchant(
        name="Liquorland Cellars North Adelaide",
        address="70 O'Connell Street, North Adelaide, SA 5006",
        lat=-34.9060, lng=138.5935,
        price_aud=31.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",          "Adelaide Hills, SA"),
            "Chardonnay":         WineProduct("Leeuwin Estate",        "Margaret River, WA"),
            "Pinot Grigio":       WineProduct("Grosset",               "Clare Valley, SA"),
            "Riesling":           WineProduct("Henschke",              "Eden Valley, SA"),
            "Moscato":            WineProduct("Brown Brothers Moscato","King Valley, VIC"),
            "Pinot Noir":         WineProduct("Bass Phillip Premium",  "Gippsland, VIC"),
            "Cabernet Sauvignon": WineProduct("Katnook Estate",        "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Langmeil Freedom",      "Barossa Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=4.0,
    ),

    # =========================================================================
    # COLES LIQUOR GROUP — Liquorland Warehouse (ex-First Choice Liquor)
    # =========================================================================

    Merchant(
        name="Liquorland Warehouse Hindmarsh",
        address="Corner South Road & Port Road, Hindmarsh, SA 5007",
        lat=-34.9080, lng=138.5720,
        price_aud=26.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Syrah/Shiraz":    WineProduct("Best's Great Western Shiraz", "Grampians, VIC"),
            "Malbec":          WineProduct("Catena Zapata",               "Mendoza, Argentina"),
            "Sauvignon Blanc": WineProduct("Wirra Wirra",                 "McLaren Vale, SA"),
            "Pinot Grigio":    WineProduct("Banrock Station",             "Riverland, SA"),
            "Sangiovese":      WineProduct("Ruffino Chianti",             "Tuscany, Italy"),
            "Carménère":       WineProduct("Undurraga Carménère",         "Colchagua Valley, Chile"),
            "Chenin Blanc":    WineProduct("Indaba Chenin Blanc",         "Western Cape, South Africa"),
            "Airén":           WineProduct("Bodegas Lozano La Mancha",    "La Mancha, Spain"),
            "Riesling":        WineProduct("Wolf Blass Yellow Label",     "Barossa Valley, SA"),
            "Grenache":        WineProduct("d'Arenberg The Stump Jump",   "McLaren Vale, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=1.0,
    ),

    Merchant(
        name="Liquorland Warehouse Unley",
        address="245 Unley Road, Unley, SA 5061",
        lat=-34.9430, lng=138.5975,
        price_aud=26.99,
        commercial_group="coles_liquor",
        search_url_template="https://www.liquorland.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",         "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Wolf Blass Gold Label",    "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Yering Station",           "Yarra Valley, VIC"),
            "Chardonnay":         WineProduct("Petaluma",                 "Adelaide Hills, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",             "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Grosset Polish Hill",      "Clare Valley, SA"),
            "Merlot":             WineProduct("Penfolds Thomas Hyland",   "Barossa Valley, SA"),
            "Grenache":           WineProduct("Yangarra Old Vine",        "McLaren Vale, SA"),
            "Tempranillo":        WineProduct("Bodegas Muga Rioja Reserva","Rioja, Spain"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
        },
        data_source="Direct_API",
        last_updated_hours=1.5,
    ),

    # =========================================================================
    # INDEPENDENT — East End Cellars (premium specialist, ships nationally)
    # =========================================================================

    Merchant(
        name="East End Cellars",
        address="25 Vardon Avenue, Adelaide CBD, SA 5000",
        lat=-34.9230, lng=138.6095,
        price_aud=45.00,
        commercial_group="independent",
        search_url_template="https://www.eastendcellars.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Grange",                "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Henschke Hill of Grace",         "Eden Valley, SA"),
            "Pinot Noir":         WineProduct("Bass Phillip Premium",           "Gippsland, VIC"),
            "Chardonnay":         WineProduct("Leeuwin Estate Art Series",      "Margaret River, WA"),
            "Riesling":           WineProduct("Grosset Polish Hill",            "Clare Valley, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",                   "Adelaide Hills, SA"),
            "Grenache":           WineProduct("Yangarra High Sands",            "McLaren Vale, SA"),
            "Malbec":             WineProduct("Achaval Ferrer Malbec",          "Mendoza, Argentina"),
            "Tempranillo":        WineProduct("Vega Sicilia Unico",             "Ribera del Duero, Spain"),
            "Sangiovese":         WineProduct("Sassicaia Bolgheri",             "Tuscany, Italy"),
            "Gewürztraminer (Dry)":WineProduct("Zind-Humbrecht Alsace",        "Alsace, France"),
            "Chenin Blanc (Dry)": WineProduct("Clos Rougeard Saumur Blanc",    "Loire Valley, France"),
            "Viognier (Dry)":     WineProduct("Château Grillet",               "Rhône Valley, France"),
            "Grüner Veltliner":   WineProduct("Nikolaihof Wachau Reserve",     "Wachau, Austria"),
            "Pinot Grigio":       WineProduct("Jermann Pinot Grigio",          "Friuli, Italy"),
            "Moscato":            WineProduct("Vietti Moscato d'Asti",         "Piedmont, Italy"),
            "Zinfandel":          WineProduct("Ridge Monte Bello",             "Santa Cruz Mountains, USA"),
            "Carménère":          WineProduct("Almaviva Puente Alto",          "Maipo Valley, Chile"),
        },
        data_source="Manual_Upload",
        last_updated_hours=24.0,
    ),

    # =========================================================================
    # INDEPENDENT — Fassina Liquor (Adelaide family chain, 8 stores)
    # =========================================================================

    Merchant(
        name="Fassina Liquor Walkerville",
        address="89 Walkerville Terrace, Walkerville, SA 5081",
        lat=-34.8970, lng=138.6170,
        price_aud=28.99,
        commercial_group="independent",
        search_url_template="https://www.fassina.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Wynns Black Label",      "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Turkey Flat",            "Barossa Valley, SA"),
            "Grenache":           WineProduct("Yangarra Old Vine",      "McLaren Vale, SA"),
            "Pinot Noir":         WineProduct("Grosset",                "Clare Valley, SA"),
            "Chardonnay":         WineProduct("Grosset Piccadilly",     "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Grosset Polish Hill",    "Clare Valley, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",           "Adelaide Hills, SA"),
            "Malbec":             WineProduct("Zuccardi Valle",         "Mendoza, Argentina"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
        },
        data_source="Manual_Upload",
        last_updated_hours=48.0,
    ),

    Merchant(
        name="Fassina Liquor Somerton Park",
        address="786 Anzac Highway, Somerton Park, SA 5044",
        lat=-34.9840, lng=138.5290,
        price_aud=28.99,
        commercial_group="independent",
        search_url_template="https://www.fassina.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",           "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Penfolds RWT",               "Barossa Valley, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump",  "McLaren Vale, SA"),
            "Sauvignon Blanc":    WineProduct("Wirra Wirra Mrs Wigley",     "McLaren Vale, SA"),
            "Chardonnay":         WineProduct("Petaluma Hanlin Hill",       "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Henschke",                   "Eden Valley, SA"),
            "Pinot Noir":         WineProduct("Stonier Reserve",            "Mornington Peninsula, VIC"),
            "Malbec":             WineProduct("Angove",                     "McLaren Vale, SA"),
        },
        data_source="Manual_Upload",
        last_updated_hours=48.0,
    ),

    # =========================================================================
    # ONLINE — Vinomofo (SA roots, national delivery)
    # =========================================================================

    Merchant(
        name="Vinomofo",
        address="Online — delivers Australia-wide",
        lat=-34.9285, lng=138.6007,   # Adelaide CBD centroid for distance calc
        price_aud=35.00,
        commercial_group="online",
        is_online_only=True,
        search_url_template="https://www.vinomofo.com/wines/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Penfolds Bin 407",         "Barossa Valley, SA"),
            "Syrah/Shiraz":       WineProduct("Langmeil Freedom",         "Barossa Valley, SA"),
            "Grenache":           WineProduct("Yangarra Old Vine",        "McLaren Vale, SA"),
            "Pinot Noir":         WineProduct("Yering Station",           "Yarra Valley, VIC"),
            "Chardonnay":         WineProduct("Grosset Piccadilly",       "Adelaide Hills, SA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",             "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Grosset Polish Hill",      "Clare Valley, SA"),
            "Malbec":             WineProduct("Zuccardi Valle",           "Mendoza, Argentina"),
            "Sangiovese":         WineProduct("Antinori Chianti Classico","Tuscany, Italy"),
            "Tempranillo":        WineProduct("Bodegas Muga Rioja",       "Rioja, Spain"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
        },
        data_source="Scraped_Data",
        last_updated_hours=24.0,
    ),

    # =========================================================================
    # ONLINE — The Wine Collective (absorbed Cracka Wines)
    # =========================================================================

    Merchant(
        name="The Wine Collective",
        address="Online — delivers Australia-wide",
        lat=-34.9285, lng=138.6007,
        price_aud=32.00,
        commercial_group="online",
        is_online_only=True,
        search_url_template="https://www.thewinecollective.com.au/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Wynns Black Label",       "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Turkey Flat",             "Barossa Valley, SA"),
            "Pinot Noir":         WineProduct("Grosset",                 "Clare Valley, SA"),
            "Chardonnay":         WineProduct("Petaluma",                "Adelaide Hills, SA"),
            "Sauvignon Blanc":    WineProduct("Wirra Wirra",             "McLaren Vale, SA"),
            "Riesling":           WineProduct("Jim Barry The Florita",   "Clare Valley, SA"),
            "Grenache":           WineProduct("d'Arenberg The Stump Jump","McLaren Vale, SA"),
            "Malbec":             WineProduct("Catena Zapata",           "Mendoza, Argentina"),
            "Tempranillo":        WineProduct("Torres Gran Sangre de Toro","Catalunya, Spain"),
            "Sangiovese":         WineProduct("Ruffino Chianti",         "Tuscany, Italy"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
        },
        data_source="Scraped_Data",
        last_updated_hours=24.0,
    ),

    # =========================================================================
    # ONLINE — Wine Selectors (Australia's largest independent direct marketer)
    # =========================================================================

    Merchant(
        name="Wine Selectors",
        address="Online — delivers Australia-wide",
        lat=-34.9285, lng=138.6007,
        price_aud=38.00,
        commercial_group="online",
        is_online_only=True,
        search_url_template="https://www.wineselectors.com.au/wine-shop/search?q={brand}",
        wines={
            "Cabernet Sauvignon": WineProduct("Katnook Estate",         "Coonawarra, SA"),
            "Syrah/Shiraz":       WineProduct("Langmeil Freedom",       "Barossa Valley, SA"),
            "Grenache":           WineProduct("Yangarra Old Vine",      "McLaren Vale, SA"),
            "Chardonnay":         WineProduct("Leeuwin Estate",         "Margaret River, WA"),
            "Sauvignon Blanc":    WineProduct("Shaw + Smith",           "Adelaide Hills, SA"),
            "Riesling":           WineProduct("Henschke",               "Eden Valley, SA"),
            "Pinot Noir":         WineProduct("Leeuwin Estate Art Series","Margaret River, WA"),
            "Malbec":             WineProduct("Achaval Ferrer",         "Mendoza, Argentina"),
            "Viognier (Dry)":     WineProduct("Yalumba Eden Valley Viognier","Eden Valley, SA"),
            "Chenin Blanc (Dry)": WineProduct("Domaine Huet Vouvray Sec","Loire Valley, France"),
        },
        data_source="Scraped_Data",
        last_updated_hours=24.0,
    ),
]


# ---------------------------------------------------------------------------
# Inventory Ghost — confidence scoring
# ---------------------------------------------------------------------------

_SOURCE_CONFIDENCE: dict[str, float] = {
    "Direct_API":    0.95,
    "Manual_Upload": 0.60,
    "Scraped_Data":  0.40,
}

_VERIFICATION_THRESHOLD = 0.70


def get_stock_certainty(data_source: str, last_updated_hours: float) -> tuple[float, bool]:
    """Return (confidence_score, needs_verification) for a merchant's inventory data."""
    base = _SOURCE_CONFIDENCE.get(data_source, 0.40)
    time_decay = last_updated_hours * 0.05
    score = max(0.10, base - time_decay)
    return round(score, 3), score < _VERIFICATION_THRESHOLD


# ---------------------------------------------------------------------------
# Partner boost / rival exclusion
# ---------------------------------------------------------------------------

def _apply_partner_filter(candidates: list[MerchantResult]) -> list[MerchantResult]:
    """
    When a preferred_partner is configured:
      1. Mark partner merchants with is_partner=True
      2. Exclude rival group merchants entirely (if exclude_rival_group=True)

    Independent and online groups are never excluded.
    """
    partner = PARTNER_CONFIG.get("preferred_partner")
    if not partner:
        return candidates

    rival = _RIVAL_GROUPS.get(partner)
    exclude_rival = PARTNER_CONFIG.get("exclude_rival_group", True)

    filtered = []
    for c in candidates:
        group = c.merchant.commercial_group
        if exclude_rival and rival and group == rival:
            log.info(
                "[Partner] EXCLUDED  %-35s  group=%s  (rival of partner=%s)",
                c.merchant.name, group, partner,
            )
            continue
        if group == partner:
            c.is_partner = True
        filtered.append(c)

    return filtered


def _apply_partner_boost(candidates: list[MerchantResult]) -> None:
    """Subtract rank_boost from partner merchant scores (lower = better rank)."""
    boost = PARTNER_CONFIG.get("partner_rank_boost", 0.25)
    partner = PARTNER_CONFIG.get("preferred_partner")
    if not partner:
        return
    for c in candidates:
        if c.is_partner:
            original = c.score
            c.score = max(0.0, round(c.score - boost, 2))
            log.info(
                "[Partner] BOOSTED   %-35s  score %.2f → %.2f  (-%s boost)",
                c.merchant.name, original, c.score, boost,
            )


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
    """Return merchants stocking wine_name within budget, with distance, tier,
    and partner flag populated.  Partner filter and boost are applied here
    before results reach the middleware interceptor."""
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
            "[Budget Gate] PASSED     %-35s  $%.2f  %.2f km  tier=%d  group=%s  region=%s",
            merchant.name, merchant.price_aud, d, tier,
            merchant.commercial_group, product.region,
        )
        results.append(MerchantResult(
            merchant=merchant,
            brand=product.brand,
            region=product.region,
            tier=tier,
            distance_km=round(d, 2),
        ))

    # Apply partner filter (exclude rival group) and mark partner merchants
    results = _apply_partner_filter(results)
    return results
