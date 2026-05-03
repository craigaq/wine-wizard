import os
from dotenv import load_dotenv
load_dotenv()
import psycopg2, psycopg2.extras

conn = psycopg2.connect(os.environ["DATABASE_URL"], cursor_factory=psycopg2.extras.RealDictCursor)
cur = conn.cursor()

cur.execute("SELECT COUNT(*) as n FROM merchant_offers WHERE retailer='cellarbrations'")
print(f"Cellarbrations offers: {cur.fetchone()['n']}")

cur.execute("""
    SELECT mo.price, w.name, w.varietal, w.country, mo.url
    FROM merchant_offers mo
    JOIN wines w ON w.id = mo.wine_id
    WHERE mo.retailer='cellarbrations'
    ORDER BY mo.price DESC
    LIMIT 10
""")
print("\nTop 10 by price:")
for r in cur.fetchall():
    print(f"  ${r['price']:.2f}  [{r['varietal']}] {r['name']}  ({r['country']})")

cur.execute("""
    SELECT DISTINCT mo.retailer, COUNT(*) as n
    FROM merchant_offers mo
    GROUP BY mo.retailer
    ORDER BY n DESC
""")
print("\nAll retailer offer counts:")
for r in cur.fetchall():
    print(f"  {r['retailer']}: {r['n']}")

cur.close()
conn.close()
