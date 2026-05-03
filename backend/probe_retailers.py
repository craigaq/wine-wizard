"""
Proof-of-scrape recon against target AU liquor retailers.
Run with: .\\venv\\Scripts\\python.exe probe_retailers.py
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
    "Accept-Encoding": "gzip, deflate",
}


def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read()
            # handle gzip
            try:
                import gzip
                raw = gzip.decompress(raw)
            except Exception:
                pass
            return raw.decode("utf-8", errors="replace"), resp.geturl(), resp.status
    except urllib.error.HTTPError as e:
        return None, url, e.code
    except Exception as e:
        return None, url, str(e)


def probe_retailer(name, base_url, wine_paths):
    print(f"\n{'#'*60}")
    print(f"  {name.upper()}")
    print(f"  {base_url}")
    print(f"{'#'*60}")

    # 1. robots.txt
    robots_html, _, status = fetch(f"{base_url}/robots.txt")
    print(f"\n[robots.txt]  status={status}")
    if robots_html:
        # Print first 30 lines
        lines = [l for l in robots_html.splitlines() if l.strip()][:30]
        for l in lines:
            print(f"  {l}")
        # Flag key directives
        if "Disallow: /" in robots_html and "Allow: /" not in robots_html:
            print("  *** Blanket Disallow detected ***")
        cloudflare = "cloudflare" in robots_html.lower() or "cf-ray" in robots_html.lower()
        if cloudflare:
            print("  *** Cloudflare block page in robots.txt ***")
    else:
        print("  (no response)")

    # 2. Homepage
    home_html, final_url, status = fetch(base_url + "/")
    print(f"\n[Homepage]  status={status}  size={len(home_html or ''):,} bytes")
    if final_url != base_url + "/":
        print(f"  Redirected to: {final_url}")

    if not home_html:
        print("  BLOCKED or unreachable")
        return

    cloudflare_block = (
        "cloudflare" in home_html.lower() and
        ("sorry, you have been blocked" in home_html.lower() or "cf-ray" in home_html.lower())
    )
    if cloudflare_block:
        print("  *** CLOUDFLARE BLOCK PAGE ***")
        return

    # Platform fingerprinting
    platform = detect_platform(home_html)
    print(f"  Platform: {platform}")

    # Subdomains
    domain = base_url.replace("https://www.", "").replace("https://", "")
    hosts = re.findall(rf'https?://([a-zA-Z0-9._-]+\.{re.escape(domain)})[/"\'\\]', home_html)
    if hosts:
        print(f"  Subdomains: {sorted(set(hosts))}")

    # API hints
    api_urls = re.findall(r'"(https?://[^"]{10,120}(?:api|graphql|search|product|catalogue)[^"]{0,60})"', home_html)
    seen = set()
    if api_urls:
        print(f"  API hints:")
        for u in api_urls:
            if u not in seen and len(seen) < 6:
                seen.add(u)
                print(f"    {u}")

    # 3. Wine category page
    print(f"\n[Wine pages]")
    for path in wine_paths:
        html, final, status = fetch(base_url + path)
        size = len(html or "")
        redirected = f" -> {final}" if html and final != base_url + path else ""
        print(f"  {path}  status={status}  size={size:,}{redirected}")

        if html and status == 200:
            prices = re.findall(r'\$(\d+\.\d{2})', html)
            names_json = re.findall(r'"(?:name|productName|title)"\s*:\s*"([A-Z][^"]{8,60})"', html)
            has_next_data = '__NEXT_DATA__' in html
            products_in_html = len(prices) > 5 and any(p != "0.00" for p in prices)

            print(f"    Prices: {len(prices)} found  non-zero: {[p for p in prices if p != '0.00'][:6]}")
            print(f"    Product names in JSON: {len(names_json)}  samples: {names_json[:3]}")
            print(f"    __NEXT_DATA__: {has_next_data}")
            print(f"    Products in SSR HTML: {'YES' if products_in_html else 'NO -- JS-rendered'}")

            # Check for wine-related nav links
            wine_links = re.findall(r'href="(/[^"]{3,60})"', html)
            wine_links = [l for l in set(wine_links) if any(w in l.lower() for w in ["wine","red","white","spark"])]
            if wine_links:
                print(f"    Wine nav paths: {sorted(wine_links)[:6]}")

            # Pagination
            total = re.findall(r'"(?:total|totalResults|numFound|count)"\s*:\s*(\d+)', html)
            if total:
                print(f"    Total results: {total[:3]}")


def detect_platform(html):
    checks = [
        ("mi9cloud",        "mi9cloud"),
        ("Next.js",         "__NEXT_DATA__"),
        ("Shopify",         "Shopify.shop"),
        ("Magento",         "Mage.Cookies"),
        ("WooCommerce",     "woocommerce"),
        ("Cloudflare",      "cf-ray"),
        ("BigCommerce",     "bigcommerce"),
        ("Salesforce",      "salesforce"),
        ("SAP",             "sap-commerce"),
        ("Hybris",          "hybris"),
    ]
    found = [name for name, marker in checks if marker.lower() in html.lower()]
    return ", ".join(found) if found else "Unknown"


if __name__ == "__main__":
    retailers = [
        (
            "The Bottle-O",
            "https://www.bottleo.com.au",
            ["/wine", "/c/wine", "/category/wine", "/sm/delivery/rsid/bottleo/results?q=wine"],
        ),
        (
            "IGA Liquor",
            "https://www.liquor.iga.com.au",
            ["/wine", "/c/wine", "/category/wine", "/sm/delivery/rsid/igaliquor/results?q=wine"],
        ),
        (
            "Duncans Liquor",
            "https://www.duncans.com.au",
            ["/wine", "/wines", "/category/wine", "/c/wine"],
        ),
        (
            "Thirsty Camel",
            "https://www.thirstycamel.com.au",
            ["/wine", "/c/wine", "/category/wine", "/wines"],
        ),
    ]

    for name, base, paths in retailers:
        probe_retailer(name, base, paths)

    print("\n\n=== SUMMARY ===")
    print("Check output above for each retailer.")
