import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo(this.code, this.symbol, this.name);
}

class BudgetBracket {
  final String label;
  final double min;
  final double max;

  const BudgetBracket(this.label, this.min, this.max);
}

class CurrencyService {
  // Locale country code → ISO 4217 currency code
  static const _localeToCode = {
    'AU': 'AUD',  'NZ': 'NZD',
    'US': 'USD',
    'CA': 'CAD',
    'GB': 'GBP',
    'IE': 'EUR',  'FR': 'EUR',  'DE': 'EUR',  'IT': 'EUR',
    'ES': 'EUR',  'PT': 'EUR',  'NL': 'EUR',  'BE': 'EUR',  'AT': 'EUR',
    'CH': 'CHF',
    'JP': 'JPY',
    'SG': 'SGD',
    'HK': 'HKD',
    'CN': 'CNY',
    'ZA': 'ZAR',
  };

  static const _meta = {
    'AUD': CurrencyInfo('AUD', 'A\$',  'Australian Dollar'),
    'USD': CurrencyInfo('USD', '\$',   'US Dollar'),
    'EUR': CurrencyInfo('EUR', '€',    'Euro'),
    'GBP': CurrencyInfo('GBP', '£',    'British Pound'),
    'NZD': CurrencyInfo('NZD', 'NZ\$', 'New Zealand Dollar'),
    'CAD': CurrencyInfo('CAD', 'CA\$', 'Canadian Dollar'),
    'JPY': CurrencyInfo('JPY', '¥',    'Japanese Yen'),
    'SGD': CurrencyInfo('SGD', 'S\$',  'Singapore Dollar'),
    'ZAR': CurrencyInfo('ZAR', 'R',    'South African Rand'),
    'HKD': CurrencyInfo('HKD', 'HK\$', 'Hong Kong Dollar'),
    'CNY': CurrencyInfo('CNY', '¥',    'Chinese Yuan'),
    'CHF': CurrencyInfo('CHF', 'Fr',   'Swiss Franc'),
  };

  // Budget brackets per currency, derived from AUD base ranges:
  //   Under 20 / 20–35 / 36–60 / 61–100 / 101+
  static const _brackets = {
    'AUD': [
      BudgetBracket('Under A\$20',       0,    20),
      BudgetBracket('A\$20 – A\$35',    20,    35),
      BudgetBracket('A\$36 – A\$60',    36,    60),
      BudgetBracket('A\$61 – A\$100',   61,   100),
      BudgetBracket('Over A\$100',      101,  9999),
    ],
    'USD': [
      BudgetBracket('Under \$13',        0,    13),
      BudgetBracket('\$13 – \$22',      13,    22),
      BudgetBracket('\$23 – \$38',      23,    38),
      BudgetBracket('\$39 – \$63',      39,    63),
      BudgetBracket('Over \$63',        64,  9999),
    ],
    'EUR': [
      BudgetBracket('Under €12',         0,    12),
      BudgetBracket('€12 – €20',        12,    20),
      BudgetBracket('€21 – €35',        21,    35),
      BudgetBracket('€36 – €58',        36,    58),
      BudgetBracket('Over €58',         59,  9999),
    ],
    'GBP': [
      BudgetBracket('Under £10',         0,    10),
      BudgetBracket('£10 – £17',        10,    17),
      BudgetBracket('£18 – £30',        18,    30),
      BudgetBracket('£31 – £50',        31,    50),
      BudgetBracket('Over £50',         51,  9999),
    ],
    'NZD': [
      BudgetBracket('Under NZ\$22',      0,    22),
      BudgetBracket('NZ\$22 – NZ\$38',  22,    38),
      BudgetBracket('NZ\$39 – NZ\$65',  39,    65),
      BudgetBracket('NZ\$66 – NZ\$108', 66,   108),
      BudgetBracket('Over NZ\$108',    109,  9999),
    ],
    'CAD': [
      BudgetBracket('Under CA\$17',      0,    17),
      BudgetBracket('CA\$17 – CA\$30',  17,    30),
      BudgetBracket('CA\$31 – CA\$52',  31,    52),
      BudgetBracket('CA\$53 – CA\$87',  53,    87),
      BudgetBracket('Over CA\$87',      88,  9999),
    ],
    'JPY': [
      BudgetBracket('Under ¥1,940',       0,  1940),
      BudgetBracket('¥1,940 – ¥3,395', 1940,  3395),
      BudgetBracket('¥3,492 – ¥5,820', 3492,  5820),
      BudgetBracket('¥5,917 – ¥9,700', 5917,  9700),
      BudgetBracket('Over ¥9,700',     9701, 999999),
    ],
    'SGD': [
      BudgetBracket('Under S\$17',       0,    17),
      BudgetBracket('S\$17 – S\$30',    17,    30),
      BudgetBracket('S\$31 – S\$51',    31,    51),
      BudgetBracket('S\$52 – S\$85',    52,    85),
      BudgetBracket('Over S\$85',       86,  9999),
    ],
  };

  /// Detect currency code from the device locale (e.g. "en_AU" → "AUD").
  /// Falls back to "AUD" if the locale is unavailable or unrecognised.
  static String detectCode() {
    try {
      if (!kIsWeb) {
        final locale = Platform.localeName; // e.g. "en_AU" or "en_AU.UTF-8"
        final parts = locale.split(RegExp(r'[_\-\.]'));
        if (parts.length >= 2) {
          final country = parts[1].toUpperCase();
          return _localeToCode[country] ?? 'AUD';
        }
      }
    } catch (_) {}
    return 'AUD';
  }

  static CurrencyInfo getInfo(String code) =>
      _meta[code] ?? const CurrencyInfo('AUD', 'A\$', 'Australian Dollar');

  static List<BudgetBracket> getBrackets(String code) =>
      _brackets[code] ?? _brackets['AUD']!;
}
