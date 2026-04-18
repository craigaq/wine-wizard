"""
Affiliate tracking configuration for Wine Wizard.

UTM tracking is applied to all deep-links immediately — merchants can see
Wine Wizard referral traffic in their own analytics from day one.

Affiliate network URLs replace the direct search link once credentials
are obtained from the merchant's affiliate program.  Set the relevant
environment variables to activate:

  AFFILIATE_ID_ENDEAVOUR     — Commission Factory ID for BWS + Dan Murphy's
  AFFILIATE_ID_COLES_LIQUOR  — Commission Factory ID for Liquorland group
  AFFILIATE_ID_VINOMOFO      — Vinomofo referral / affiliate ID
  AFFILIATE_ID_TWC           — The Wine Collective affiliate ID
  AFFILIATE_ID_WINE_SELECTORS — Wine Selectors affiliate ID

Commission Factory URL format (Australian network used by Endeavour & Coles):
  https://t.cfjump.com/s/{affiliate_id}/{merchant_tracking_id}?Url={encoded_destination}

When an affiliate_id env var is set for a commercial group, _merchant_response()
in main.py will build the Commission Factory tracking URL automatically and
stamp it into website_url.  The search_url_template is used as the destination.
"""

import os
from urllib.parse import quote

# ---------------------------------------------------------------------------
# UTM parameters — applied to all deep-links (no credentials needed)
# ---------------------------------------------------------------------------

UTM_PARAMS = {
    "utm_source":   "winewizard",
    "utm_medium":   "referral",
    "utm_campaign": "wine_recommendation",
}


def append_utm(url: str) -> str:
    """Append Wine Wizard UTM parameters to any URL."""
    if not url:
        return url
    separator = "&" if "?" in url else "?"
    params = "&".join(f"{k}={v}" for k, v in UTM_PARAMS.items())
    return f"{url}{separator}{params}"


# ---------------------------------------------------------------------------
# Affiliate IDs — loaded from environment variables
# ---------------------------------------------------------------------------

AFFILIATE_IDS: dict[str, str] = {
    group: os.environ.get(env_var, "")
    for group, env_var in {
        "endeavour":    "AFFILIATE_ID_ENDEAVOUR",
        "coles_liquor": "AFFILIATE_ID_COLES_LIQUOR",
        "vinomofo":     "AFFILIATE_ID_VINOMOFO",
        "twc":          "AFFILIATE_ID_TWC",
        "wine_selectors": "AFFILIATE_ID_WINE_SELECTORS",
    }.items()
}

# Commission Factory merchant tracking IDs (assigned when affiliate account is approved)
CF_MERCHANT_IDS: dict[str, str] = {
    "endeavour":    os.environ.get("CF_MERCHANT_ID_ENDEAVOUR", ""),
    "coles_liquor": os.environ.get("CF_MERCHANT_ID_COLES_LIQUOR", ""),
}

# Commission Factory base URL
_CF_BASE = "https://t.cfjump.com/s"


def build_affiliate_url(
    commercial_group: str,
    destination_url: str,
    affiliate_url_template: str = "",
) -> str:
    """
    Return the best available URL for a merchant, in priority order:

    1. affiliate_url_template on the Merchant object (fully custom — set per merchant)
    2. Commission Factory tracking URL (built automatically when env vars are set)
    3. Direct destination URL + UTM params (always available as fallback)
    """
    # Priority 1: explicit affiliate URL on the merchant record
    if affiliate_url_template:
        return append_utm(affiliate_url_template)

    # Priority 2: Commission Factory — build tracking URL if credentials are present
    aff_id = AFFILIATE_IDS.get(commercial_group, "")
    cf_mid  = CF_MERCHANT_IDS.get(commercial_group, "")
    if aff_id and cf_mid:
        encoded_dest = quote(destination_url, safe="")
        cf_url = f"{_CF_BASE}/{aff_id}/{cf_mid}?Url={encoded_dest}"
        return append_utm(cf_url)

    # Priority 3: direct deep-link + UTM
    return append_utm(destination_url)
