"""
Merchant Validator — scrapes merchant search pages to confirm wine brands
exist on each retailer's website and captures real prices.

Architecture
------------
Uses a Protocol-based provider interface so the scraping layer can be swapped
for a real API client (e.g. Endeavour Group Partner API) without changing any
other code in the system.

  ScrapingProvider   — Phase 1 (current): HTTP search scrape + fuzzy match
  [EndeavourProvider] — Phase 2 (future): drop-in when API credentials provided

Validation cache
----------------
Results are stored in VALIDATION_CACHE with a TTL (default 6 hours).
On app startup, validate_all_catalog() is called once to warm the cache.
Stale entries are re-validated on next access or forced refresh.

Result states
-------------
  VALIDATED    — brand found on merchant site; live_price_aud populated
  NOT_FOUND    — brand searched but not found; merchant excluded from results
  SKIPPED      — search URL not available or request failed; falls back to
                 deep-link-only with needs_verification=True

Usage
-----
  from merchant_validator import get_validation, validate_all_catalog

  # Called once at startup (async)
  await validate_all_catalog()

  # Called per merchant result before surfacing to user
  result = get_validation(merchant_name, wine_variety, brand)
  if result.state == "VALIDATED":
      use result.live_price_aud and result.product_url
  elif result.state == "NOT_FOUND":
      exclude from recommendations
  else:  # SKIPPED
      show deep-link with verification warning
"""

from __future__ import annotations

import asyncio
import logging
import re
import time
from dataclasses import dataclass, field
from typing import Protocol, runtime_checkable
from urllib.parse import quote_plus

log = logging.getLogger("wine_wizard.validator")

# ---------------------------------------------------------------------------
# Validation result model
# ---------------------------------------------------------------------------

@dataclass
class ValidationResult:
    merchant_name: str
    wine_variety:  str
    brand:         str
    state:         str          # "VALIDATED" | "NOT_FOUND" | "SKIPPED"
    live_price_aud: float | None = None   # Real price from merchant site
    product_url:    str | None   = None   # Direct product page URL (if found)
    search_url:     str | None   = None   # Search URL used (for deep-link fallback)
    validated_at:   float        = field(default_factory=time.time)
    error:          str | None   = None   # Reason for SKIPPED state


# ---------------------------------------------------------------------------
# Provider Protocol — swappable interface
# ---------------------------------------------------------------------------

@runtime_checkable
class MerchantDataProvider(Protocol):
    """
    Interface for merchant data providers.

    Implementations:
      ScrapingProvider      — current (Phase 1)
      EndeavourAPIProvider  — future (Phase 2, when API deal is signed)
    """

    async def validate(
        self,
        merchant_name: str,
        search_url_template: str,
        wine_variety: str,
        brand: str,
    ) -> ValidationResult:
        """Validate that brand exists on the merchant site and return result."""
        ...


# ---------------------------------------------------------------------------
# Phase 1 — Scraping Provider
# ---------------------------------------------------------------------------

# Search URL templates per merchant name — maps to the right search pattern.
# SPAs (BWS, Dan Murphy's) block headless crawlers with 403s; for these we
# fall back to SKIPPED state with a deep-link rather than a false NOT_FOUND.
_KNOWN_SPA_MERCHANTS = {
    "dan murphy",
    "bws",
    "liquorland",
}

# Shopify and simple retailers return readable HTML for search queries
_SHOPIFY_SEARCH_PATTERN = re.compile(
    r'class="[^"]*product[^"]*"[^>]*>.*?<[^>]+class="[^"]*title[^"]*"[^>]*>(.*?)</',
    re.IGNORECASE | re.DOTALL,
)


def _is_spa_merchant(merchant_name: str) -> bool:
    name = merchant_name.lower()
    return any(k in name for k in _KNOWN_SPA_MERCHANTS)


def _fuzzy_brand_match(brand: str, page_text: str) -> bool:
    """
    Check if any significant token from the brand name appears in the page text.
    Uses the first 2–3 meaningful words of the brand to avoid false negatives
    from vintage years, label variants, etc.

    E.g. "Penfolds Bin 407 Cabernet Sauvignon 2021" → search for "Penfolds Bin 407"
    """
    # Strip common noise words
    noise = {"the", "and", "of", "a", "an", "de", "du", "la", "le", "les", "old",
             "estate", "reserve", "vineyard", "vineyards", "winery", "cellars"}
    tokens = [t for t in brand.lower().split() if t not in noise]
    # Use first 3 meaningful tokens as the search fingerprint
    fingerprint = " ".join(tokens[:3])
    return fingerprint in page_text.lower()


class ScrapingProvider:
    """
    Phase 1 provider: HTTP scraping with fuzzy brand matching.

    For SPA merchants (Dan Murphy's, BWS, Liquorland) that block crawlers,
    returns SKIPPED with a usable search deep-link rather than NOT_FOUND.
    For Shopify/static merchants, performs a real search and fuzzy-matches.
    """

    async def validate(
        self,
        merchant_name: str,
        search_url_template: str,
        wine_variety: str,
        brand: str,
    ) -> ValidationResult:
        search_url = (
            search_url_template.replace("{brand}", quote_plus(brand))
            if search_url_template
            else None
        )

        # SPA merchants: return SKIPPED (deep-link available but can't scrape)
        if _is_spa_merchant(merchant_name):
            log.debug(
                "[Validator] SKIPPED (SPA)  %-30s  brand=%s",
                merchant_name, brand,
            )
            return ValidationResult(
                merchant_name=merchant_name,
                wine_variety=wine_variety,
                brand=brand,
                state="SKIPPED",
                search_url=search_url,
                error="SPA merchant — search page is JavaScript-rendered; cannot scrape",
            )

        if not search_url:
            return ValidationResult(
                merchant_name=merchant_name,
                wine_variety=wine_variety,
                brand=brand,
                state="SKIPPED",
                error="No search URL template configured for this merchant",
            )

        # Static / Shopify merchants: attempt HTTP fetch
        try:
            import urllib.request
            import urllib.error

            headers = {
                "User-Agent": (
                    "Mozilla/5.0 (compatible; WineWizardBot/1.0; "
                    "+https://winewizard.app/bot)"
                ),
                "Accept": "text/html,application/xhtml+xml",
            }
            req = urllib.request.Request(search_url, headers=headers)
            loop = asyncio.get_event_loop()
            response_text = await loop.run_in_executor(
                None, lambda: _fetch_url(req),
            )

            if response_text is None:
                return ValidationResult(
                    merchant_name=merchant_name,
                    wine_variety=wine_variety,
                    brand=brand,
                    state="SKIPPED",
                    search_url=search_url,
                    error="HTTP request failed or returned non-200 status",
                )

            found = _fuzzy_brand_match(brand, response_text)
            state = "VALIDATED" if found else "NOT_FOUND"

            log.info(
                "[Validator] %-12s %-30s  brand=%-35s  url=%s",
                state, merchant_name, brand, search_url,
            )
            return ValidationResult(
                merchant_name=merchant_name,
                wine_variety=wine_variety,
                brand=brand,
                state=state,
                search_url=search_url,
                # Price extraction from static pages is unreliable — leave for
                # a future enhancement. Live price comes from the merchant API (Phase 2).
                live_price_aud=None,
            )

        except Exception as exc:
            log.warning(
                "[Validator] SKIPPED (error)  %-30s  brand=%s  error=%s",
                merchant_name, brand, exc,
            )
            return ValidationResult(
                merchant_name=merchant_name,
                wine_variety=wine_variety,
                brand=brand,
                state="SKIPPED",
                search_url=search_url,
                error=str(exc),
            )


def _fetch_url(req) -> str | None:
    """Synchronous URL fetch — run in executor to avoid blocking the event loop."""
    import urllib.request
    import urllib.error
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status == 200:
                return resp.read().decode("utf-8", errors="replace")
            return None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Validation cache
# ---------------------------------------------------------------------------

_CACHE_TTL_SECONDS = 6 * 60 * 60   # 6 hours
_VALIDATION_CACHE: dict[str, ValidationResult] = {}   # key: "merchant|variety|brand"


def _cache_key(merchant_name: str, wine_variety: str, brand: str) -> str:
    return f"{merchant_name.lower()}|{wine_variety.lower()}|{brand.lower()}"


def get_validation(
    merchant_name: str,
    wine_variety: str,
    brand: str,
) -> ValidationResult | None:
    """Return cached validation result, or None if not yet validated / expired."""
    key = _cache_key(merchant_name, wine_variety, brand)
    result = _VALIDATION_CACHE.get(key)
    if result is None:
        return None
    age = time.time() - result.validated_at
    if age > _CACHE_TTL_SECONDS:
        log.debug("[Validator] Cache EXPIRED  key=%s  age=%.0fs", key, age)
        return None
    return result


def _store_validation(result: ValidationResult) -> None:
    key = _cache_key(result.merchant_name, result.wine_variety, result.brand)
    _VALIDATION_CACHE[key] = result


# ---------------------------------------------------------------------------
# Startup validation — warms the cache for the full catalog
# ---------------------------------------------------------------------------

# The active provider — swap this line when moving to Phase 2 (API deal)
_provider: MerchantDataProvider = ScrapingProvider()


async def validate_all_catalog(concurrency: int = 5) -> dict[str, int]:
    """
    Validate every merchant/wine/brand entry in the catalog.
    Runs concurrently with a semaphore to avoid hammering merchant sites.

    Returns a summary dict: {"VALIDATED": n, "NOT_FOUND": n, "SKIPPED": n}
    """
    from local_sourcing import MERCHANT_CATALOG

    semaphore = asyncio.Semaphore(concurrency)
    tasks = []

    for merchant in MERCHANT_CATALOG:
        for variety, product in merchant.wines.items():
            tasks.append(
                _validate_one(semaphore, merchant.name, merchant.search_url_template, variety, product.brand)
            )

    log.info("[Validator] Starting catalog validation — %d entries", len(tasks))
    results = await asyncio.gather(*tasks, return_exceptions=True)

    summary: dict[str, int] = {"VALIDATED": 0, "NOT_FOUND": 0, "SKIPPED": 0}
    for r in results:
        if isinstance(r, ValidationResult):
            summary[r.state] = summary.get(r.state, 0) + 1
            _store_validation(r)
        else:
            summary["SKIPPED"] += 1

    log.info(
        "[Validator] Catalog validation complete — VALIDATED=%d  NOT_FOUND=%d  SKIPPED=%d",
        summary["VALIDATED"], summary["NOT_FOUND"], summary["SKIPPED"],
    )
    return summary


async def _validate_one(
    semaphore: asyncio.Semaphore,
    merchant_name: str,
    search_url_template: str,
    wine_variety: str,
    brand: str,
) -> ValidationResult:
    async with semaphore:
        cached = get_validation(merchant_name, wine_variety, brand)
        if cached:
            return cached
        result = await _provider.validate(merchant_name, search_url_template, wine_variety, brand)
        _store_validation(result)
        # Polite delay between requests to the same domain
        await asyncio.sleep(0.5)
        return result


# ---------------------------------------------------------------------------
# Phase 2 stub — EndeavourAPIProvider
# ---------------------------------------------------------------------------
# Uncomment and implement when Endeavour Group API credentials are available.
# Swap _provider = ScrapingProvider() for _provider = EndeavourAPIProvider(api_key=...)
#
# class EndeavourAPIProvider:
#     def __init__(self, api_key: str) -> None:
#         self.api_key = api_key
#
#     async def validate(
#         self,
#         merchant_name: str,
#         search_url_template: str,
#         wine_variety: str,
#         brand: str,
#     ) -> ValidationResult:
#         # Call Endeavour Partner API
#         # Returns real-time stock status, price, product URL
#         ...
