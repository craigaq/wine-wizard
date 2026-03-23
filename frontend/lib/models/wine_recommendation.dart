class ConflictAlert {
  final String title;
  final String message;
  final String field;
  final int suggestedValue;

  ConflictAlert({
    required this.title,
    required this.message,
    required this.field,
    required this.suggestedValue,
  });

  factory ConflictAlert.fromJson(Map<String, dynamic> json) {
    return ConflictAlert(
      title: json['title'] as String,
      message: json['message'] as String,
      field: json['field'] as String,
      suggestedValue: json['suggested_value'] as int,
    );
  }
}

class GastroClash {
  final String id;
  final String title;
  final String message;
  final String actionType;
  final Map<String, int> newValues;

  GastroClash({
    required this.id,
    required this.title,
    required this.message,
    required this.actionType,
    required this.newValues,
  });

  factory GastroClash.fromJson(Map<String, dynamic> json) {
    return GastroClash(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      actionType: json['action_type'] as String,
      newValues: (json['new_values'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}

class PalateParadox {
  final String status;
  final String message;
  final List<Map<String, String>> options;

  PalateParadox({
    required this.status,
    required this.message,
    required this.options,
  });

  factory PalateParadox.fromJson(Map<String, dynamic> json) {
    return PalateParadox(
      status: json['status'] as String,
      message: json['message'] as String,
      options: (json['options'] as List)
          .map((o) => Map<String, String>.from(o as Map))
          .toList(),
    );
  }
}

class WineRecommendation {
  final String name;
  final String skuId;
  final double score;
  final Map<String, double> attributeScores;
  final Map<String, double> wineProfile;
  final Map<String, dynamic> rawMetrics;

  WineRecommendation({
    required this.name,
    required this.skuId,
    required this.score,
    required this.attributeScores,
    required this.wineProfile,
    required this.rawMetrics,
  });

  factory WineRecommendation.fromJson(Map<String, dynamic> json) {
    return WineRecommendation(
      name:    json['name']    as String,
      skuId:   (json['sku_id'] as String?) ?? '',
      score:   (json['score']  as num).toDouble(),
      attributeScores: (json['attribute_scores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      wineProfile: ((json['wine_profile'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      rawMetrics: (json['raw_metrics'] as Map<String, dynamic>?) ?? {},
    );
  }
}
