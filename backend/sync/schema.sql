-- Run once in Supabase SQL Editor (or any PostgreSQL client) to initialise the sync tables.

CREATE TABLE IF NOT EXISTS wines (
    id         SERIAL PRIMARY KEY,
    name       TEXT    NOT NULL,
    vintage    INTEGER,
    region     TEXT,
    varietal   TEXT,
    country    TEXT,
    state      TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS merchant_offers (
    id           SERIAL PRIMARY KEY,
    wine_id      INTEGER REFERENCES wines (id) ON DELETE CASCADE,
    retailer     TEXT    NOT NULL,
    price        NUMERIC(10, 2),
    url          TEXT,
    rating           NUMERIC(3, 1),
    review_count     INTEGER DEFAULT 0,
    is_member_price  BOOLEAN DEFAULT FALSE,
    last_updated     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (wine_id, retailer)
);

-- Two partial unique indexes handle both vintaged and non-vintage wines.
-- PostgreSQL treats NULL as distinct in regular unique constraints, so a plain
-- UNIQUE (name, vintage) would create duplicate rows on every sync for
-- wines without a vintage year. The partial index approach solves this cleanly.
CREATE UNIQUE INDEX IF NOT EXISTS wines_name_vintage_idx
    ON wines (name, vintage) WHERE vintage IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS wines_name_null_vintage_idx
    ON wines (name) WHERE vintage IS NULL;
