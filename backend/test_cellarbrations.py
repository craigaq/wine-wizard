"""
Quick end-to-end test of the Cellarbrations scraper + normalizer.
Run with: .\\venv\\Scripts\\python.exe test_cellarbrations.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
os.chdir(os.path.dirname(__file__))

from dotenv import load_dotenv
load_dotenv()

import logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s — %(message)s")

from sync.scraper_cellarbrations import scrape_cellarbrations
from sync.normalizer import normalize

print("=" * 60)
print("Scraping Cellarbrations...")
print("=" * 60)
raw = scrape_cellarbrations()
print(f"\nRaw products: {len(raw)}")

if raw:
    sample = raw[0]
    print(f"Sample raw product:")
    for k in ("productId", "name", "priceNumeric", "brand", "url"):
        print(f"  {k}: {str(sample.get(k, ''))[:80]}")

print("\n" + "=" * 60)
print("Normalizing...")
print("=" * 60)
pairs = normalize(raw, "cellarbrations")
print(f"\nNormalised: {len(pairs)} / {len(raw)} ({len(pairs)/len(raw)*100:.1f}% match rate)")

if pairs:
    print("\nSample normalized wines:")
    for wine, offer in pairs[:10]:
        print(f"  [{wine.varietal}] {wine.name} {wine.vintage or ''} — ${offer.price:.2f}")
        print(f"    country={wine.country}  state={wine.state}")
        print(f"    url={offer.url}")

print("\n" + "=" * 60)
print("Upserting to database...")
print("=" * 60)
from sync.upsert import upsert_batch
wines_count, offers_count = upsert_batch(pairs)
print(f"Wines upserted: {wines_count}")
print(f"Offers upserted: {offers_count}")
print("\nDone.")
