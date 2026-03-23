class Merchant {
  final String name;
  final String address;
  final String brand;
  final String region;
  final int tier;
  final String tierLabel;
  final double distanceKm;
  final double priceUsd;
  final double score;
  final double confidenceScore;
  final bool needsVerification;

  Merchant({
    required this.name,
    required this.address,
    required this.brand,
    required this.region,
    required this.tier,
    required this.tierLabel,
    required this.distanceKm,
    required this.priceUsd,
    required this.score,
    required this.confidenceScore,
    required this.needsVerification,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      name:             json['name']             as String,
      address:          json['address']          as String,
      brand:            json['brand']            as String,
      region:           (json['region']          as String?) ?? '',
      tier:             (json['tier']            as int?)    ?? 0,
      tierLabel:        (json['tier_label']      as String?) ?? '',
      distanceKm:       (json['distance_km']     as num).toDouble(),
      priceUsd:         (json['price_usd']       as num).toDouble(),
      score:            (json['score']           as num).toDouble(),
      confidenceScore:  (json['confidence_score'] as num).toDouble(),
      needsVerification: json['needs_verification'] as bool,
    );
  }
}


class TierResult {
  final int tier;
  final String label;
  final String regionHint;
  final Merchant? bestMatch;
  final List<Merchant> allMatches;
  final bool suppressed;
  final String? suppressionReason;
  final String? persona;
  final String? wit;
  final String? eduInsight;
  final String? comparisonNote;

  TierResult({
    required this.tier,
    required this.label,
    required this.regionHint,
    required this.bestMatch,
    required this.allMatches,
    required this.suppressed,
    this.suppressionReason,
    this.persona,
    this.wit,
    this.eduInsight,
    this.comparisonNote,
  });

  factory TierResult.fromJson(Map<String, dynamic> json) {
    final bestJson = json['best_match'] as Map<String, dynamic>?;
    return TierResult(
      tier:              json['tier']              as int,
      label:             json['label']             as String,
      regionHint:        json['region_hint']       as String,
      bestMatch:         bestJson != null ? Merchant.fromJson(bestJson) : null,
      allMatches:        (json['all_matches'] as List)
                             .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
                             .toList(),
      suppressed:        (json['suppressed'] as bool?) ?? false,
      suppressionReason: json['suppression_reason'] as String?,
      persona:           json['persona']           as String?,
      wit:               json['wit']               as String?,
      eduInsight:        json['edu_insight']        as String?,
      comparisonNote:    json['comparison_note']    as String?,
    );
  }
}


class NearbyResponse {
  final String wineName;
  final List<Merchant> merchants;    // flat sorted list (backward compat)
  final List<TierResult> tiers;      // three geographic buckets
  final bool pricingPrecedentApplied;

  NearbyResponse({
    required this.wineName,
    required this.merchants,
    required this.tiers,
    required this.pricingPrecedentApplied,
  });

  factory NearbyResponse.fromJson(Map<String, dynamic> json) {
    return NearbyResponse(
      wineName: json['wine_name'] as String,
      merchants: (json['merchants'] as List)
          .map((m) => Merchant.fromJson(m as Map<String, dynamic>))
          .toList(),
      tiers: (json['tiers'] as List)
          .map((t) => TierResult.fromJson(t as Map<String, dynamic>))
          .toList(),
      pricingPrecedentApplied: (json['pricing_precedent_applied'] as bool?) ?? false,
    );
  }
}
