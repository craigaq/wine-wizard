"""
Food pairing modifiers applied to attribute scores.

Keys are backend IDs (snake_case). The frontend maps UI labels → backend IDs
before sending them to the API.

Structure per pairing:
  multipliers  - multiply the base score for that attribute (0.0 suppresses it)
  boosts       - additive bonus applied after the multiplier

Formula applied per attribute:
  final_attribute = (base_score * multiplier) + boost

Wizard's Secret (the logic behind each entry):
  red_meat     — High Tannin allowed. Needs structure to cut through fat.
  poultry      — Medium Body. High acidity or medium-weight reds/whites.
  white_fish   — Tannin-Free Zone. High acidity is a must.
  rich_fish    — Rosé/Light Red Territory. Can handle a tiny bit of texture.
  spicy_food   — Low Alcohol. High sugar/fruit to put out the fire.
  tomato_sauce — High Acidity. Needs to match the acid in the tomatoes.
  creamy_sauce — Full-bodied Whites. Needs "Weight" to match the dairy.
  greens       — Crisp & Herbaceous. Matches the "green" notes in wine.
  charcuterie  — The All-Rounder. Usually favors high-acid, medium-body.
  none         — The Palate Dial stays exactly where the user set it.
"""

FOOD_PAIRING: dict[str, dict] = {
    # Red Meat — fat tames tannin; body provides structure
    "red_meat": {
        "is_sweet_pairing": False,
        "multipliers": {
            "tannin": 1.5,   # Fat from steak/lamb cuts through grippy tannins
            "body":   1.2,   # Full body matches the richness of the protein
        },
        "boosts": {},
    },

    # White Meat — light to medium; acidity lifts delicate flavours
    "poultry": {
        "is_sweet_pairing": False,
        "multipliers": {
            "tannin": 0.7,   # Moderate grip only — chicken can't hold heavy tannin
        },
        "boosts": {
            "acidity": 0.5,  # Crispness cuts through poultry fat cleanly
        },
    },

    # Seafood: White Fish / Shellfish — tannin destroys delicate fish oils
    "white_fish": {
        "is_sweet_pairing": False,
        "multipliers": {
            "tannin": 0.0,   # Tannin-Free Zone — metallic clash with fish oils
        },
        "boosts": {
            "acidity": 1.5,  # High crispness is essential to complement the brine
        },
    },

    # Seafood: Salmon / Tuna — richer flesh; can handle a whisper of texture
    "rich_fish": {
        "is_sweet_pairing": False,
        "multipliers": {
            "tannin": 0.5,   # Small amount of grip OK — rosé/light red territory
        },
        "boosts": {
            "acidity": 0.5,  # Still want freshness to balance the oily flesh
        },
    },

    # Spicy Food — off-dry wines (Riesling, Gewürztraminer) cool the heat best.
    # is_sweet_pairing=True triggers the Palate Paradox check for dry-preferring users.
    "spicy_food": {
        "is_sweet_pairing": True,
        "multipliers": {
            "tannin": 0.0,   # Tannin + capsaicin = burning finish — suppress entirely
            "body":   0.5,   # High alcohol fans the flames — dampen body
        },
        "boosts": {
            "aromatics": 1.0,  # Residual fruit/sweetness puts out the fire
        },
    },

    # Tomato-based Pasta / Pizza — tomato acid demands a wine that matches it
    "tomato_sauce": {
        "is_sweet_pairing": False,
        "multipliers": {},
        "boosts": {
            "acidity": 1.5,  # High acidity matches the tomato's natural tartness
        },
    },

    # Creamy / Cheesy Pasta — dairy richness needs body and a touch of acid to cut through
    "creamy_sauce": {
        "is_sweet_pairing": False,
        "multipliers": {
            "tannin": 0.5,   # Grippy tannin clashes with cream — soften it
        },
        "boosts": {
            "body":   1.0,   # Full body matches the dairy richness
            "acidity": 0.3,  # Light crispness cuts through the fat
        },
    },

    # Salads / Green Veggies — crisp, herbaceous; light is right
    "greens": {
        "is_sweet_pairing": False,
        "multipliers": {
            "body":   0.7,   # Heavy reds overwhelm delicate greens
            "tannin": 0.5,   # Grippy tannin clashes with bitter vegetables
        },
        "boosts": {
            "acidity":   1.0,  # Crispness mirrors the freshness of the dish
            "aromatics": 0.5,  # Herbaceous notes complement green flavours
        },
    },

    # Cheese & Charcuterie — the all-rounder; acid cuts through salt and fat
    "charcuterie": {
        "is_sweet_pairing": False,
        "multipliers": {},
        "boosts": {
            "acidity": 0.5,  # Crispness cuts through cured-meat fat and salt
            "body":    0.3,  # Medium body rounds out the board nicely
        },
    },

    # No food — palate dial stays exactly where the user set it
    "none": {
        "is_sweet_pairing": False,
        "multipliers": {},
        "boosts": {},
    },
}
