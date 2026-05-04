"""
Migration: add is_member_price column to merchant_offers.

Adds a BOOLEAN DEFAULT FALSE column so the sync engine can flag when a
scraped price is a member/loyalty-only rate rather than the standard price.

Safe to re-run: uses IF NOT EXISTS / ALTER COLUMN ... SET DEFAULT idiom
so it's a no-op if the column already exists.
"""

import os, sys, logging
from dotenv import load_dotenv
load_dotenv()
import psycopg2, psycopg2.extras

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger(__name__)


def main():
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("DATABASE_URL not set — run from the backend/ directory with .env loaded.")

    conn = psycopg2.connect(url, cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        with conn.cursor() as cur:
            # Check whether the column already exists
            cur.execute("""
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'merchant_offers'
                  AND column_name = 'is_member_price'
            """)
            if cur.fetchone():
                log.info("Column 'is_member_price' already exists — nothing to do.")
                return

            log.info("Adding is_member_price BOOLEAN DEFAULT FALSE to merchant_offers ...")
            cur.execute("""
                ALTER TABLE merchant_offers
                ADD COLUMN is_member_price BOOLEAN NOT NULL DEFAULT FALSE
            """)

            # Verify
            cur.execute("""
                SELECT column_name, data_type, column_default
                FROM information_schema.columns
                WHERE table_name = 'merchant_offers'
                  AND column_name = 'is_member_price'
            """)
            row = cur.fetchone()
            log.info("Column added: %s %s DEFAULT %s", row["column_name"], row["data_type"], row["column_default"])

        conn.commit()
        log.info("Migration complete.")
    except Exception as exc:
        conn.rollback()
        log.error("Migration failed: %s", exc)
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
