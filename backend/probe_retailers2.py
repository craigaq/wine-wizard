"""
Follow-up probe: Thirsty Camel deep-dive + correct URLs for IGA/Duncans/Bottle-O.
Run with: .\\venv\\Scripts\\python.exe probe_retailers2.py
"""
import re
import json
import ssl
import urllib.request
import urllib.error

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/json,*/*",
    "Accept-Language": "en-AU,en;q=0.9",
}

# Skip SSL verification for sites with cert issues
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def fetch(url, max_bytes=500000, accept_json=False):
    headers = {**HEADERS}
    if accept_json:
        headers["Accept"] = "application/json, */*"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
        raw = resp.read(max_bytes)
        try:
            import gzip
            raw = gzip.decompress(raw)
        except Exception:
            pass
        return raw.decode("utf-8", errors="replace"), resp.geturl(), resp.status


def check(url, label="", max_bytes=500000, accept_json=False):
    try:
        html, final, status = fetch(url, max_bytes, accept_json)
        redir = f"  -> {final}" if final != url else ""
        print(f"  OK {status:3d}  {len(html):>9,} b  {url}{redir}")
        title = re.search(r"<title[^>]*>(.*?)</title>", html, re.DOTALL)
        if title:
            print(f"         title: {title.group(1).strip()[:80]}")
        prices = re.findall(r"\$(\d+\.\d{2})", html)
        non_zero = [p for p in prices if p != "0.00"]
        if non_zero:
            print(f"         prices (non-zero): {non_zero[:8]}")
        return html, status
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}  {url}")
        return None, e.code
    except Exception as e:
        print(f"  ERR  {str(e)[:80]}  {url}")
        return None, None


# ── THIRSTY CAMEL ─────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("THIRSTY CAMEL — deep dive")
print("="*60)

print("\n-- Product sitemap (first 4KB) --")
xml, _ = check("https://www.thirstycamel.com.au/api/sitemap-products.xml", max_bytes=4000)
if xml:
    urls = re.findall(r"<loc>(https?://[^<]+)</loc>", xml)
    print(f"   Product URLs in sitemap: {len(urls)}  samples:")
    for u in urls[:6]:
        print(f"     {u}")

print("\n-- Category sitemap (first 4KB) --")
xml, _ = check("https://www.thirstycamel.com.au/api/sitemap-categories.xml", max_bytes=4000)
if xml:
    urls = re.findall(r"<loc>(https?://[^<]+)</loc>", xml)
    print(f"   Category URLs: {len(urls)}  samples:")
    for u in urls[:8]:
        print(f"     {u}")

print("\n-- GraphQL endpoint (introspect) --")
gql_url = "https://cms.beta.thirstycamel.com.au/wp/graphql"
gql_body = b'{"query":"{ __typename }"}'
req = urllib.request.Request(
    gql_url,
    data=gql_body,
    headers={**HEADERS, "Content-Type": "application/json", "Accept": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        print(f"   GraphQL response ({len(raw)} bytes): {raw[:300]}")
except Exception as e:
    print(f"   GraphQL: {e}")

print("\n-- Wine/red-wine category page --")
html, _ = check("https://www.thirstycamel.com.au/red-wine")
if html:
    # Try to extract __NEXT_DATA__
    nd = re.findall(r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
    if nd:
        print(f"   __NEXT_DATA__: {len(nd[0]):,} chars")
        try:
            data = json.loads(nd[0])
            # Walk for product data
            def find_products(obj, depth=0):
                if depth > 8:
                    return
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if str(k).lower() in ("products", "items", "nodes", "edges", "results"):
                            if isinstance(v, list) and len(v) > 0:
                                print(f"   {'  '*depth}FOUND: .{k}  list[{len(v)}]")
                                if isinstance(v[0], dict):
                                    print(f"   {'  '*depth}  keys: {list(v[0].keys())[:12]}")
                                    for fk, fv in list(v[0].items())[:8]:
                                        print(f"   {'  '*depth}    {fk}: {str(fv)[:60]}")
                            elif isinstance(v, dict):
                                find_products(v, depth+1)
                        else:
                            find_products(v, depth+1)
                elif isinstance(obj, list):
                    for item in obj[:2]:
                        find_products(item, depth+1)
            find_products(data)
        except Exception as e:
            print(f"   Parse error: {e}")

print("\n-- TC internal API probe --")
for path in [
    "/api/products?category=wine",
    "/api/products?q=wine",
    "/api/v1/products/wine",
    "/api/categories/wine/products",
    "/_next/data/buildid/red-wine.json",
]:
    check(f"https://www.thirstycamel.com.au{path}", accept_json=True)


# ── IGA LIQUOR ────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("IGA LIQUOR — URL discovery")
print("="*60)
for url in [
    "https://liquor.iga.com.au/",
    "https://www.igaliquor.com.au/",
    "https://igaliquor.com.au/",
    "https://www.iga.com.au/liquor/",
    "https://shop.liquorland.com.au/",   # IGA sometimes redirects here
]:
    check(url)


# ── DUNCANS LIQUOR ────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("DUNCANS LIQUOR — URL discovery")
print("="*60)
for url in [
    "https://duncans.com.au/",
    "https://www.duncansliquor.com.au/",
    "https://duncansliquor.com.au/",
    "https://www.theduncans.com.au/",
    "https://www.duncanscellar.com.au/",
]:
    check(url)


# ── BOTTLE-O ──────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("THE BOTTLE-O — is there a real online shop?")
print("="*60)
for url in [
    "https://www.bottleo.com.au/",
    "https://bottleo.com.au/",
    "https://www.thebottleo.com.au/",
    "https://shop.bottleo.com.au/",
    "https://www.bottleo.com.au/wine",
]:
    check(url)

print("\n\nDone.")
