"""
Final probe: TC product prices + IGA wine pages.
Run with: .\\venv\\Scripts\\python.exe probe_retailers3.py
"""
import re, json, ssl, urllib.request, urllib.error

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "en-AU,en;q=0.9",
}
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def fetch(url, data=None, extra_headers=None, max_bytes=600000):
    h = {**HEADERS, "Accept": "text/html,application/json,*/*"}
    if extra_headers:
        h.update(extra_headers)
    req = urllib.request.Request(url, data=data, headers=h, method="POST" if data else "GET")
    with urllib.request.urlopen(req, timeout=15, context=ctx) as r:
        raw = r.read(max_bytes)
        try:
            import gzip; raw = gzip.decompress(raw)
        except Exception:
            pass
        return raw.decode("utf-8", errors="replace"), r.geturl()

# ── THIRSTY CAMEL: find prices ─────────────────────────────────────────────
print("="*60)
print("THIRSTY CAMEL -- finding prices")
print("="*60)

# 1. Single product page (Penfolds Grange from sitemap)
print("\n-- Product page (Penfolds Grange) --")
try:
    html, _ = fetch("https://www.thirstycamel.com.au/product/penfolds-grange-2001-single/64ea75a8d7")
    prices = [p for p in re.findall(r"\$(\d+\.\d{2})", html) if p != "0.00"]
    print(f"  Non-zero prices on product page: {prices[:8]}")
    nd = re.findall(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if nd:
        data = json.loads(nd[0])
        def find_price(obj, depth=0):
            if depth > 10: return
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if str(k).lower() in ("price","saleprice","currentprice","amount","retailprice","pricevalue","cost"):
                        print(f"  PRICE FIELD: .{k} = {v}")
                    else:
                        find_price(v, depth+1)
            elif isinstance(obj, list):
                for item in obj[:3]:
                    find_price(item, depth+1)
        find_price(data)
except Exception as e:
    print(f"  Error: {e}")

# 2. GraphQL query for products with prices
print("\n-- GraphQL: query products with price --")
gql_queries = [
    '{"query":"{ products { nodes { id name price } } }"}',
    '{"query":"{ products(first: 5) { nodes { id name regularPrice } } }"}',
    '{"query":"{ products { nodes { id name ... on SimpleProduct { price } } } }"}',
]
for q in gql_queries:
    try:
        body = q.encode()
        html, _ = fetch(
            "https://cms.beta.thirstycamel.com.au/wp/graphql",
            data=body,
            extra_headers={"Content-Type": "application/json", "Accept": "application/json"},
        )
        print(f"  Query: {q[:60]}")
        print(f"  Response: {html[:400]}")
        break
    except Exception as e:
        print(f"  Error: {e}")

# 3. TC red-wine page full __NEXT_DATA__ -- look specifically for price keys
print("\n-- Red-wine page: full price key search --")
try:
    html, _ = fetch("https://www.thirstycamel.com.au/red-wine")
    nd = re.findall(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if nd:
        print(f"  __NEXT_DATA__ size: {len(nd[0]):,}")
        # Regex scan for any price-like fields
        price_fields = re.findall(r'"(?:price|Price|salePrice|retailPrice|currentPrice|amount|cost)"\s*:\s*([^,}\]]+)', nd[0])
        print(f"  Price-like fields: {price_fields[:12]}")
        # Show all unique keys in first product node
        prods = re.findall(r'"products"\s*:\s*\[(\{.*?\})', nd[0], re.DOTALL)
        if prods:
            try:
                first = json.loads(prods[0])
                print(f"  All keys in first product: {list(first.keys())}")
            except Exception:
                pass
except Exception as e:
    print(f"  Error: {e}")


# ── IGA LIQUOR: wine pages ─────────────────────────────────────────────────
print("\n" + "="*60)
print("IGA LIQUOR -- wine category pages")
print("="*60)

iga_paths = [
    "/wine",
    "/c/wine",
    "/category/wine",
    "/sm/delivery/rsid/igaliquor/results?q=wine&rows=20",
    "/sm/delivery/rsid/iga/results?q=wine&rows=20",
    "/products?category=wine",
]
for path in iga_paths:
    url = f"https://www.igaliquor.com.au{path}"
    try:
        html, final = fetch(url)
        prices = [p for p in re.findall(r"\$(\d+\.\d{2})", html) if p != "0.00"]
        nd = "__NEXT_DATA__" in html
        prods_empty = '"products":[]' in html or '"products": []' in html
        subdomains = re.findall(r'https?://([a-zA-Z0-9._-]+\.igaliquor\.com\.au)', html)
        print(f"  {path}")
        print(f"    status=200  size={len(html):,}  prices={prices[:5]}  __NEXT_DATA__={nd}  products_empty={prods_empty}")
        if subdomains:
            print(f"    subdomains: {sorted(set(subdomains))}")
        api_hints = re.findall(r'"(https?://[^"]{10,100}(?:api|gateway|search)[^"]{0,60})"', html)
        seen = set()
        for a in api_hints:
            if a not in seen and len(seen) < 4:
                seen.add(a)
                print(f"    api hint: {a}")
    except urllib.error.HTTPError as e:
        print(f"  {path} -> HTTP {e.code}")
    except Exception as e:
        print(f"  {path} -> {str(e)[:80]}")

print("\n\nDone.")
