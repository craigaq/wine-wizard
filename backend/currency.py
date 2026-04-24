"""Currency support for Cellar Sage.

All catalog prices are stored in AUD (Australian Dollar) as the base currency.
This module handles exchange rates, lat/lng → currency detection, and
price conversion helpers.

Exchange rates are hardcoded as approximate mid-market rates (early 2026).
Update the AUD_TO table periodically, or swap in a live-rates API later.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CurrencyInfo:
    code:   str   # ISO 4217 (e.g. "AUD")
    symbol: str   # Display symbol (e.g. "A$")
    name:   str   # Human-readable (e.g. "Australian Dollar")


# ---------------------------------------------------------------------------
# Exchange rates — 1 AUD = X of target currency
# ---------------------------------------------------------------------------

AUD_TO: dict[str, float] = {
    "AUD": 1.000,
    "USD": 0.630,
    "EUR": 0.580,
    "GBP": 0.500,
    "NZD": 1.080,
    "CAD": 0.870,
    "JPY": 97.00,
    "SGD": 0.850,
    "ZAR": 11.50,
    "HKD": 4.920,
    "CNY": 4.560,
    "CHF": 0.560,
}

CURRENCY_META: dict[str, CurrencyInfo] = {
    "AUD": CurrencyInfo("AUD", "A$",   "Australian Dollar"),
    "USD": CurrencyInfo("USD", "$",    "US Dollar"),
    "EUR": CurrencyInfo("EUR", "€",    "Euro"),
    "GBP": CurrencyInfo("GBP", "£",    "British Pound"),
    "NZD": CurrencyInfo("NZD", "NZ$",  "New Zealand Dollar"),
    "CAD": CurrencyInfo("CAD", "CA$",  "Canadian Dollar"),
    "JPY": CurrencyInfo("JPY", "¥",    "Japanese Yen"),
    "SGD": CurrencyInfo("SGD", "S$",   "Singapore Dollar"),
    "ZAR": CurrencyInfo("ZAR", "R",    "South African Rand"),
    "HKD": CurrencyInfo("HKD", "HK$",  "Hong Kong Dollar"),
    "CNY": CurrencyInfo("CNY", "¥",    "Chinese Yuan"),
    "CHF": CurrencyInfo("CHF", "Fr",   "Swiss Franc"),
}

_DEFAULT = "AUD"

# ---------------------------------------------------------------------------
# Country → currency
# ---------------------------------------------------------------------------

COUNTRY_TO_CURRENCY: dict[str, str] = {
    "AU": "AUD",  "NZ": "NZD",
    "US": "USD",
    "CA": "CAD",
    "GB": "GBP",
    "IE": "EUR",  "FR": "EUR",  "DE": "EUR",  "IT": "EUR",
    "ES": "EUR",  "PT": "EUR",  "NL": "EUR",  "BE": "EUR",  "AT": "EUR",
    "CH": "CHF",
    "JP": "JPY",
    "SG": "SGD",
    "HK": "HKD",
    "CN": "CNY",
    "ZA": "ZAR",
}

# ---------------------------------------------------------------------------
# Lat/lng → country via bounding boxes  (major wine-purchasing markets)
# (lat_min, lat_max, lng_min, lng_max, ISO 3166-1 alpha-2)
# ---------------------------------------------------------------------------

_BOXES: list[tuple[float, float, float, float, str]] = [
    (-44.0, -10.0,  113.0,  154.0, "AU"),
    (-47.0, -34.0,  166.0,  178.0, "NZ"),
    ( 24.0,  49.0, -125.0,  -66.0, "US"),
    ( 42.0,  83.0, -141.0,  -52.0, "CA"),
    ( 49.0,  61.0,   -8.0,    2.0, "GB"),
    ( 51.0,  56.0,  -10.0,   -5.0, "IE"),
    ( 41.0,  51.0,   -5.0,   10.0, "FR"),
    ( 47.0,  55.0,    6.0,   15.0, "DE"),
    ( 36.0,  47.0,    6.0,   19.0, "IT"),
    ( 36.0,  44.0,   -9.0,    4.0, "ES"),
    ( 36.0,  42.0,   -9.0,   -6.0, "PT"),
    ( 46.0,  48.0,    6.0,   11.0, "CH"),
    ( 24.0,  46.0,  122.0,  146.0, "JP"),
    (  1.1,   1.5,  103.6,  104.0, "SG"),
    ( 22.0,  24.0,  113.8,  114.5, "HK"),
    ( 18.0,  53.5,   73.0,  135.0, "CN"),
    (-35.0, -22.0,   16.0,   33.0, "ZA"),
]


def lat_lng_to_currency(lat: float, lng: float) -> str:
    """Return the ISO 4217 currency code for the given GPS coordinates.

    Uses bounding-box lookup; falls back to AUD when no match is found.
    Note: the frontend passes a currency_code derived from device locale,
    so this function is used only as a server-side fallback.
    """
    for lat_min, lat_max, lng_min, lng_max, cc in _BOXES:
        if lat_min <= lat <= lat_max and lng_min <= lng <= lng_max:
            return COUNTRY_TO_CURRENCY.get(cc, _DEFAULT)
    return _DEFAULT


# ---------------------------------------------------------------------------
# Conversion helpers
# ---------------------------------------------------------------------------

def convert_from_aud(amount_aud: float, code: str) -> float:
    """Convert an AUD amount to the target currency, rounded to 2 d.p."""
    rate = AUD_TO.get(code.upper(), 1.0)
    return round(amount_aud * rate, 2)


def convert_to_aud(amount_local: float, code: str) -> float:
    """Convert a local-currency amount back to AUD, rounded to 2 d.p."""
    rate = AUD_TO.get(code.upper(), 1.0)
    return round(amount_local / rate, 2) if rate else amount_local


def get_info(code: str) -> CurrencyInfo:
    """Return CurrencyInfo for the given code; defaults to AUD."""
    return CURRENCY_META.get(code.upper(), CURRENCY_META[_DEFAULT])
