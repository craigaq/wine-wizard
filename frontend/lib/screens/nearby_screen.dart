import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/merchant.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}

// Tier colour palette — matches the React badge colours
const _tierColors = {
  1: Color(0xFF059669),   // emerald-600  — Local Hero
  2: Color(0xFF2563EB),   // blue-600     — National Rival
  3: Color(0xFF7C3AED),   // purple-700   — Global Icon
};

const _tierIcons = {
  1: Icons.home_outlined,
  2: Icons.flag_outlined,
  3: Icons.public,
};

class NearbyScreen extends StatefulWidget {
  final String wineName;
  final double budgetMin;
  final double budgetMax;
  final String currencyCode;

  const NearbyScreen({
    super.key,
    required this.wineName,
    required this.budgetMin,
    required this.budgetMax,
    this.currencyCode = 'AUD',
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  NearbyResponse? _response;
  bool _loading = true;
  String? _error;
  bool _showGlobalTier = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final position = await LocationService().getCurrentPosition();
      final response = await ApiService().nearby(
        wineName:       widget.wineName,
        userLat:        position.latitude,
        userLng:        position.longitude,
        budgetMin:      widget.budgetMin,
        budgetMax:      widget.budgetMax,
        showGlobalTier: _showGlobalTier,
        currencyCode:   widget.currencyCode,
      );
      setState(() {
        _response = response;
        _loading  = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),   // slate-50
      appBar: AppBar(
        title: Text('Where to find ${widget.wineName}'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Consulting the Wizard\'s map...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧙‍♂️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'The Wizard\'s crystal ball is foggy.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_response == null || _response!.merchants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('😬', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'No merchants found nearby.\nEven the Wizard has limits.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pricing Precedent banner
        if (_response!.pricingPrecedentApplied && !_showGlobalTier)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PricingPrecedentBanner(
              onShowGlobal: () { setState(() => _showGlobalTier = true); _load(); },
            ),
          ),

        // Comparison cards — one per tier
        for (final tier in _response!.tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _WineComparisonCard(
              tier:          tier,
              color:         _tierColors[tier.tier] ?? Colors.grey.shade700,
              icon:          _tierIcons[tier.tier]  ?? Icons.place,
              onShowGlobal:  () { setState(() => _showGlobalTier = true); _load(); },
            ),
          ),

        // Unlock toggle when global tier is already shown
        if (_showGlobalTier)
          _GlobalTierToggle(
            onHide: () { setState(() => _showGlobalTier = false); _load(); },
          ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Wine Comparison Card
// Mirrors the React <WineComparisonUI> card design.
// ---------------------------------------------------------------------------

class _WineComparisonCard extends StatelessWidget {
  final TierResult tier;
  final Color color;
  final IconData icon;
  final VoidCallback onShowGlobal;

  const _WineComparisonCard({
    required this.tier,
    required this.color,
    required this.icon,
    required this.onShowGlobal,
  });

  @override
  Widget build(BuildContext context) {
    // Suppressed tier — show locked state instead
    if (tier.suppressed) {
      return _SuppressedCard(
        tier:         tier,
        color:        color,
        icon:         icon,
        onShowGlobal: onShowGlobal,
      );
    }

    // No results for this tier
    if (tier.bestMatch == null) {
      return _EmptyTierCard(tier: tier, color: color, icon: icon);
    }

    final best = tier.bestMatch!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),  // slate-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Regional Badge ──────────────────────────────────────────
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 12, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    tier.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content area ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Persona tag
                  if (tier.persona != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        tier.persona!,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: color.withValues(alpha: 0.8),
                        ),
                      ),
                    ),

                  // Wine / brand name
                  Text(
                    best.brand,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),  // slate-800
                    ),
                  ),

                  // Region
                  const SizedBox(height: 2),
                  Text(
                    best.region.isNotEmpty ? best.region : tier.regionHint,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF64748B),  // slate-500
                    ),
                  ),

                  // Price
                  const SizedBox(height: 10),
                  Text(
                    '${best.currencySymbol}${best.priceLocal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),  // slate-900
                    ),
                  ),

                  // ── Witty Statement callout ──────────────────────────
                  if (tier.wit != null && tier.wit!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),   // amber-50
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(
                          left: BorderSide(color: Color(0xFFFBBF24), width: 4),  // amber-400
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '" ${tier.wit} "',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF78350F),  // amber-900
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // ── Educational insight ──────────────────────────────
                  if (tier.eduInsight != null && tier.eduInsight!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),  // slate-600
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(
                            text: 'The Difference: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),  // slate-800
                            ),
                          ),
                          TextSpan(text: tier.eduInsight),
                        ],
                      ),
                    ),
                  ],

                  // ── Comparison note ──────────────────────────────────
                  if (tier.comparisonNote != null && tier.comparisonNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.compare_arrows,
                            size: 14, color: color.withValues(alpha: 0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tier.comparisonNote!,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: color.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Badge row: Partner, Online Only, Call to Confirm
                  if (best.isPartner || best.isOnlineOnly || best.needsVerification) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (best.isPartner)
                          _SmallBadge(
                            label: 'Partner',
                            color: Colors.deepPurple.shade600,
                            icon: Icons.verified,
                          ),
                        if (best.isOnlineOnly)
                          _SmallBadge(
                            label: 'Online Only',
                            color: Colors.blueGrey.shade600,
                            icon: Icons.local_shipping_outlined,
                          ),
                        if (best.needsVerification)
                          _SmallBadge(
                            label: 'Call to Confirm Stock',
                            color: Colors.orange.shade700,
                            icon: Icons.phone,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Action buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Primary: deep-link to retailer's search page for this wine
                  if (best.websiteUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(best.websiteUrl),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(
                          'Shop ${best.name.split(' ').first} Online',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (best.websiteUrl.isNotEmpty) const SizedBox(height: 8),
                  // Secondary: show all stockists for this tier
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showMerchantSheet(context, tier, color),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'See All Stockists',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMerchantSheet(
      BuildContext context, TierResult tier, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MerchantBottomSheet(tier: tier, color: color),
    );
  }
}


// ---------------------------------------------------------------------------
// Merchant bottom sheet — shown when user taps "Select this Bottle"
// ---------------------------------------------------------------------------

class _MerchantBottomSheet extends StatefulWidget {
  final TierResult tier;
  final Color color;

  const _MerchantBottomSheet({required this.tier, required this.color});

  @override
  State<_MerchantBottomSheet> createState() => _MerchantBottomSheetState();
}

class _MerchantBottomSheetState extends State<_MerchantBottomSheet> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final matches = widget.tier.allMatches;
    final visible = _showAll ? matches : matches.take(1).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ListView(
          controller: controller,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Text(
              'Stockists — ${widget.tier.label}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
            Text(
              widget.tier.regionHint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),

            // Merchant rows
            for (int i = 0; i < visible.length; i++)
              _MerchantRow(
                merchant: visible[i],
                color:    widget.color,
                isBest:   i == 0,
              ),

            // Show more
            if (!_showAll && matches.length > 1)
              TextButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.expand_more, size: 16),
                label: Text(
                  '${matches.length - 1} more stockist${matches.length - 1 == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Merchant row (compact — for bottom sheet list)
// ---------------------------------------------------------------------------

class _MerchantRow extends StatelessWidget {
  final Merchant merchant;
  final Color color;
  final bool isBest;

  const _MerchantRow({
    required this.merchant,
    required this.color,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest ? color : Colors.grey.shade200,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Distance bubble
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isBest
                  ? color.withValues(alpha: 0.10)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    merchant.distanceKm < 1
                        ? '${(merchant.distanceKm * 1000).toStringAsFixed(0)}m'
                        : '${merchant.distanceKm.toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isBest ? color : Colors.grey.shade700,
                    ),
                  ),
                  Icon(Icons.place,
                      size: 12,
                      color: isBest ? color : Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (isBest)
                      _SmallBadge(label: 'Closest', color: color),
                    if (merchant.isPartner) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Partner',
                        color: Colors.deepPurple.shade600,
                        icon: Icons.verified,
                      ),
                    ],
                    if (merchant.isOnlineOnly) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Online',
                        color: Colors.blueGrey.shade600,
                        icon: Icons.local_shipping_outlined,
                      ),
                    ],
                    if (merchant.needsVerification) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Call First',
                        color: Colors.orange.shade700,
                        icon: Icons.phone,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  merchant.address,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (merchant.websiteUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _openUrl(merchant.websiteUrl),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new,
                            size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 3),
                        Text(
                          'Shop online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${merchant.currencySymbol}${merchant.priceLocal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Small badge chip
// ---------------------------------------------------------------------------

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _SmallBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Empty tier card (no results in this tier)
// ---------------------------------------------------------------------------

class _EmptyTierCard extends StatelessWidget {
  final TierResult tier;
  final Color color;
  final IconData icon;

  const _EmptyTierCard(
      {required this.tier, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              color: color.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  tier.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No ${tier.label} options found for this wine.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Suppressed tier card  (Pricing Precedent applied to Tier 3)
// ---------------------------------------------------------------------------

class _SuppressedCard extends StatelessWidget {
  final TierResult tier;
  final Color color;
  final IconData icon;
  final VoidCallback onShowGlobal;

  const _SuppressedCard({
    required this.tier,
    required this.color,
    required this.icon,
    required this.onShowGlobal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      tier.label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.suppressionReason ??
                        'International option hidden — significantly pricier than local.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onShowGlobal,
                    icon: Icon(Icons.public, size: 16, color: color),
                    label: Text('Show international options',
                        style: TextStyle(color: color)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Pricing Precedent banner (top of list)
// ---------------------------------------------------------------------------

class _PricingPrecedentBanner extends StatelessWidget {
  final VoidCallback onShowGlobal;

  const _PricingPrecedentBanner({required this.onShowGlobal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),   // amber-50
        border: Border.all(color: const Color(0xFFFDE68A)),  // amber-300
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFFB45309), size: 18),  // amber-700
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Global Icon hidden — it\'s significantly pricier than the local option.',
              style: TextStyle(
                  fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onShowGlobal,
            child: const Text('Show'),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Global tier toggle (shown when Tier 3 is unlocked)
// ---------------------------------------------------------------------------

class _GlobalTierToggle extends StatelessWidget {
  final VoidCallback onHide;

  const _GlobalTierToggle({required this.onHide});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.public, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(
          'International options unlocked',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onHide,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Hide', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
