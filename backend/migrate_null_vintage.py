"""
Migration: fix (name, vintage) NULL unique constraint.

PostgreSQL treats NULL as distinct in unique constraints, so
ON CONFLICT (name, vintage) never fires for non-vintage wines —
each sync creates duplicate rows. This migration:

  1. Deduplicates existing null-vintage wines (keep lowest id per name).
     - Reroutes merchant_offers from duplicate wine_ids to the canonical one.
     - Deletes conflicting dupe offers (canonical already has a record for
       that retailer; we keep the canonical's version).
     - Deletes the now-empty duplicate wine rows.
  2. Drops the old wines_name_vintage_key constraint and idx_wines_name_vintage index.
  3. Creates two partial unique indexes:
       - (name, vintage) WHERE vintage IS NOT NULL  — vintaged wines
       - (name)          WHERE vintage IS NULL       — non-vintage wines

Safe to re-run: index creation uses IF NOT EXISTS; dedup is idempotent.
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
        sys.exit("DATABASE_URL not set")

    conn = psycopg2.connect(url, cursor_factory=psycopg2.extras.RealDictCursor)
    conn.autocommit = False

    with conn.cursor() as cur:

        # ── Step 1a: Find null-vintage duplicates ─────────────────────────────
        cur.execute("""
            SELECT name, MIN(id) AS keep_id, array_agg(id ORDER BY id) AS all_ids
            FROM wines
            WHERE vintage IS NULL
            GROUP BY name
            HAVING COUNT(*) > 1
        """)
        groups = cur.fetchall()
        log.info("Null-vintage name groups with duplicates: %d", len(groups))

        for g in groups:
            keep_id  = g["keep_id"]
            dupe_ids = [i for i in g["all_ids"] if i != keep_id]
            name     = g["name"]
            log.info("  %r — keep id=%d, removing ids=%s", name, keep_id, dupe_ids)

            # ── Step 1b: For each dupe, reroute offers that don't conflict ────
            # An offer conflicts if the canonical wine already has an offer
            # from the same retailer.
            for dupe_id in dupe_ids:
                cur.execute("""
                    UPDATE merchant_offers mo
                    SET wine_id = %s
                    WHERE mo.wine_id = %s
                      AND mo.retailer NOT IN (
                          SELECT retailer FROM merchant_offers WHERE wine_id = %s
                      )
                """, (keep_id, dupe_id, keep_id))
                rerouted = cur.rowcount
                log.info("    id=%d: rerouted %d offers to canonical", dupe_id, rerouted)

                # ── Step 1c: Delete remaining offers on this dupe (conflicts) ─
                cur.execute("DELETE FROM merchant_offers WHERE wine_id = %s", (dupe_id,))
                deleted_offers = cur.rowcount
                if deleted_offers:
                    log.info("    id=%d: deleted %d conflicting offers", dupe_id, deleted_offers)

            # ── Step 1d: Delete the now-orphaned dupe wine rows ───────────────
            cur.execute("DELETE FROM wines WHERE id = ANY(%s)", (dupe_ids,))
            log.info("  Deleted %d duplicate wine rows for %r", cur.rowcount, name)

        # ── Step 2: Drop the old constraint and composite index ───────────────
        cur.execute("""
            ALTER TABLE wines
            DROP CONSTRAINT IF EXISTS wines_name_vintage_key
        """)
        log.info("Dropped constraint wines_name_vintage_key (if existed)")

        cur.execute("DROP INDEX IF EXISTS idx_wines_name_vintage")
        log.info("Dropped index idx_wines_name_vintage (if existed)")

        # ── Step 3: Create partial unique indexes ─────────────────────────────
        cur.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS wines_name_vintage_idx
            ON wines (name, vintage)
            WHERE vintage IS NOT NULL
        """)
        log.info("Created wines_name_vintage_idx (vintaged wines)")

        cur.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS wines_name_null_vintage_idx
            ON wines (name)
            WHERE vintage IS NULL
        """)
        log.info("Created wines_name_null_vintage_idx (non-vintage wines)")

    conn.commit()
    conn.close()
    log.info("Migration complete.")


if __name__ == "__main__":
    main()
