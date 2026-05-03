"""
Probe Cellarbrations -- discover URL structure then map product fields.
Run with: .\\venv\\Scripts\\python.exe probe_cellarbrations.py
"""
import re
import json
import urllib.request
import urllib.error

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-AU,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

HEADERS_JSON = {
    **HEADERS,
    "Origin": "https://www.cellarbrations.com.au",
    "Referer": "https://www.cellarbrations.com.au/",
    "Accept": "application/json, text/plain, */*",
}


def fetch(url, headers=None):
    req = urllib.request.Request(url, headers=headers or HEADERS)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace"), resp.geturl()


def probe(url, label, headers=None):
    print(f"\n{'='*60}")
    print(f"{label}")
    print(f"URL: {url}")
    print('='*60)
    try:
        html, final_url = fetch(url, headers)
        if final_url != url:
            print(f"Redirected to: {final_url}")
        print(f"Response size: {len(html):,} bytes")
        return html, final_url
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.reason}")
    except Exception as e:
        print(f"Error: {e}")
    return "", url


def analyse(html, label):
    if not html:
        return

    # __NEXT_DATA__ (Next.js SSR)
    next_data = re.findall(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if next_data:
        print(f"\n[OK] __NEXT_DATA__ found ({len(next_data[0]):,} chars)")
        try:
            data = json.loads(next_data[0])
            _walk(data, depth=0, max_depth=6)
        except Exception as e:
            print(f"  Parse error: {e}")
    else:
        print("\n[--] No __NEXT_DATA__ -- checking for other data patterns")

    # Prices
    prices = re.findall(r'\$(\d+\.\d{2})', html)
    print(f"\nPrice patterns found: {len(prices)}  samples: {prices[:8]}")

    # wine/product name JSON fields
    names = re.findall(r'"name"\s*:\s*"([^"]{10,80})"', html)
    if names:
        print(f"\n'name' JSON fields: {len(names)}  samples:")
        for n in names[:6]:
            print(f"  {n}")

    # Navigation / category links
    nav_links = re.findall(r'href="(/[^"]{3,60})"', html)
    wine_links = [l for l in set(nav_links) if any(w in l.lower() for w in ["wine","red","white","spark","spirit","beer"])]
    if wine_links:
        print(f"\nWine-related href paths found:")
        for l in sorted(wine_links)[:20]:
            print(f"  {l}")

    # Pagination
    for pat, lbl in [
        (r'"totalPages"\s*:\s*(\d+)', 'totalPages'),
        (r'"pageCount"\s*:\s*(\d+)', 'pageCount'),
        (r'"total"\s*:\s*(\d+)', 'total'),
        (r'page=(\d+)', '?page= param'),
        (r'"perPage"\s*:\s*(\d+)', 'perPage'),
    ]:
        m = re.findall(pat, html)
        if m:
            print(f"Pagination -- {lbl}: {m[:5]}")

    # All cellarbrations subdomains referenced
    hosts = re.findall(r'https?://([a-zA-Z0-9._-]+\.cellarbrations\.com\.au)[/"\'\\]', html)
    if hosts:
        print(f"\nSubdomains referenced:")
        for h in sorted(set(hosts)):
            print(f"  {h}")

    # API config values
    api_configs = re.findall(r'"(?:apiUrl|baseUrl|endpoint|apiBase|storeUrl|graphqlUrl|apiEndpoint)"\s*:\s*"([^"]+)"', html)
    if api_configs:
        print(f"\nAPI config values:")
        for c in api_configs[:10]:
            print(f"  {c}")

    # Full API URLs
    api_urls = re.findall(r'"(https://[^"]{10,150}(?:api|graphql|search|product)[^"]{0,80})"', html)
    seen = set()
    if api_urls:
        print(f"\nAPI URL hints:")
        for u in api_urls:
            if u not in seen and len(seen) < 15:
                seen.add(u)
                print(f"  {u}")


def _walk(obj, depth, max_depth, path="root"):
    if depth > max_depth:
        return
    indent = "  " * depth
    if isinstance(obj, dict):
        for k, v in obj.items():
            key_lower = str(k).lower()
            interesting = any(w in key_lower for w in [
                "product","price","item","wine","catalog","node","edge",
                "name","sku","slug","url","image","category","page",
            ])
            if interesting:
                if isinstance(v, list):
                    print(f"{indent}{path}.{k}  ->  list[{len(v)}]")
                    if v and isinstance(v[0], dict):
                        print(f"{indent}  first item keys: {list(v[0].keys())[:15]}")
                        _walk(v[0], depth+1, max_depth, f"{path}.{k}[0]")
                elif isinstance(v, dict):
                    print(f"{indent}{path}.{k}  ->  dict  keys: {list(v.keys())[:12]}")
                    _walk(v, depth+1, max_depth, f"{path}.{k}")
                else:
                    print(f"{indent}{path}.{k}  =  {str(v)[:100]}")
            elif isinstance(v, (dict, list)):
                _walk(v, depth, max_depth, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, item in enumerate(obj[:2]):
            _walk(item, depth, max_depth, f"{path}[{i}]")


def analyse_search_results(html):
    """Deep-parse the /sm/delivery search results page for product fields."""
    print(f"\nResponse size: {len(html):,} bytes")

    # Is there a __NEXT_DATA__ or inline JSON with products?
    next_data = re.findall(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if next_data:
        print(f"[OK] __NEXT_DATA__ found ({len(next_data[0]):,} chars)")
        try:
            data = json.loads(next_data[0])
            _walk(data, 0, 6)
        except Exception as e:
            print(f"  Parse error: {e}")

    # Look for inline product JSON arrays
    product_arrays = re.findall(r'"products"\s*:\s*(\[.*?\])', html[:500000], re.DOTALL)
    if product_arrays:
        print(f"\nInline 'products' arrays found: {len(product_arrays)}")
        try:
            prods = json.loads(product_arrays[0])
            print(f"  Count: {len(prods)}")
            if prods:
                print(f"  First product keys: {list(prods[0].keys())}")
                for k, v in list(prods[0].items())[:12]:
                    print(f"    {k}: {str(v)[:80]}")
        except Exception as e:
            print(f"  Parse error: {e}")

    # Price patterns
    prices = re.findall(r'\$(\d+\.\d{2})', html)
    print(f"\nPrices found: {len(prices)}  samples: {prices[:12]}")

    # Product name patterns in data attributes or JSON
    names_json = re.findall(r'"(?:name|productName|title)"\s*:\s*"([A-Z][^"]{8,70})"', html)
    if names_json:
        print(f"\nProduct name fields: {len(names_json)}  samples:")
        for n in names_json[:10]:
            print(f"  {n}")

    # SKU / product ID patterns
    skus = re.findall(r'"(?:sku|productId|id|itemId)"\s*:\s*"?(\w{4,20})"?', html)
    if skus:
        print(f"\nSKU/ID fields: {len(skus)}  samples: {skus[:8]}")

    # data-* attributes (common in product cards)
    data_attrs = re.findall(r'data-(?:product|sku|price|name|id)="([^"]{2,80})"', html)
    if data_attrs:
        print(f"\ndata-* attributes: {len(data_attrs)}  samples: {data_attrs[:8]}")

    # Pagination
    total = re.findall(r'"(?:total|totalResults|count|numFound)"\s*:\s*(\d+)', html)
    per_page = re.findall(r'"(?:rows|perPage|pageSize|hitsPerPage)"\s*:\s*(\d+)', html)
    if total:
        print(f"\nTotal results field: {total[:3]}")
    if per_page:
        print(f"Per-page field: {per_page[:3]}")


if __name__ == "__main__":
    # Step 1: Mine homepage for API config and subdomains
    print("=== Step 1: Mine homepage for API config ===")
    html, _ = probe("https://www.cellarbrations.com.au/", "Homepage")
    if html:
        analyse(html, "Homepage")

        # Find all script src URLs
        scripts = re.findall(r'src="(/[^"]*\.js[^"]*)"', html)
        print(f"\nJS bundle URLs (first 5):")
        for s in scripts[:5]:
            print(f"  {s}")

    # Deep-parse the confirmed search results endpoint
    print("\n=== Parsing search results page ===")
    url = "https://www.cellarbrations.com.au/sm/delivery/rsid/cellarbrations/results?q=wine&rows=50"
    try:
        raw, _ = fetch(url, HEADERS_JSON)
        analyse_search_results(raw)
    except Exception as e:
        print(f"Error: {e}")

    # Try fetching with Accept: application/json to see if API mode exists
    print("\n=== Try JSON response mode ===")
    url_json = "https://www.cellarbrations.com.au/sm/delivery/rsid/cellarbrations/results?q=wine&rows=20&format=json"
    url_json2 = "https://www.cellarbrations.com.au/sm/api/rsid/cellarbrations/results?q=wine&rows=20"
    for u in [url_json, url_json2]:
        try:
            raw, _ = fetch(u, HEADERS_JSON)
            print(f"\nURL: {u}")
            print(f"Size: {len(raw):,}  preview: {raw[:400]}")
        except urllib.error.HTTPError as e:
            print(f"  {u.split('com.au')[1][:60]} -> HTTP {e.code}")
        except Exception as e:
            print(f"  Error: {e}")

    print("\n\nDone.")
