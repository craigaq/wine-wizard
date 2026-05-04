import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/merchant.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}

Future<void> _openDirections(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not open directions for $address');
  }
}

// Tier colour palette
const _tierColors = {
  1: WwColors.tierLocal,
  2: WwColors.tierNational,
  3: WwColors.tierGlobal,
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
      backgroundColor: WwColors.bgDeep,
      appBar: AppBar(
        title: Text(
          widget.wineName,
          style: WwText.headlineMedium(),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: WwColors.violet),
            const SizedBox(height: 16),
            Text(
              "Consulting the Cellar Fox's map…",
              style: WwText.bodyMedium(),
            ),
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
              const Text('🦊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                "The Cellar Fox is a bit lost.",
                style: WwText.titleMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: WwText.bodySmall(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_response == null || _response!.merchants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No merchants found nearby.\nEven the Cellar Fox has limits.',
              textAlign: TextAlign.center,
              style: WwText.bodyMedium(),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Pricing Precedent banner
        if (_response!.pricingPrecedentApplied && !_showGlobalTier)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PricingPrecedentBanner(
              onShowGlobal: () {
                setState(() => _showGlobalTier = true);
                _load();
              },
            ),
          ),

        // Comparison cards — one per tier
        for (final tier in _response!.tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _WineComparisonCard(
              tier:         tier,
              color:        _tierColors[tier.tier] ?? Colors.grey.shade700,
              icon:         _tierIcons[tier.tier]  ?? Icons.place,
              onShowGlobal: () {
                setState(() => _showGlobalTier = true);
                _load();
              },
            ),
          ),

        // Unlock toggle when global tier is already shown
        if (_showGlobalTier)
          _GlobalTierToggle(
            onHide: () {
              setState(() => _showGlobalTier = false);
              _load();
            },
          ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Wine Comparison Card
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
    if (tier.suppressed) {
      return _SuppressedCard(
        tier:         tier,
        color:        color,
        icon:         icon,
        onShowGlobal: onShowGlobal,
      );
    }

    if (tier.bestMatch == null) {
      return _EmptyTierCard(tier: tier, color: color, icon: icon);
    }

    final best = tier.bestMatch!;

    return Container(
      decoration: WwDecorations.card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tier header strip ──────────────────────────────────────────
            Container(
              decoration: WwDecorations.tierHeader(color),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 12, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    tier.label.toUpperCase(),
                    style: WwText.badgeLabel(),
                  ),
                ],
              ),
            ),

            // ── Content area ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Persona tag
                  if (tier.persona != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        tier.persona!,
                        style: WwText.personaTag(
                            color: color.withValues(alpha: 0.9)),
                      ),
                    ),

                  // Wine / brand name — Cormorant serif
                  Text(
                    best.brand,
                    style: WwText.headlineMedium(),
                  ),

                  // Region
                  const SizedBox(height: 3),
                  Text(
                    best.region.isNotEmpty ? best.region : tier.regionHint,
                    style: WwText.bodyMedium()
                        .copyWith(fontStyle: FontStyle.italic),
                  ),

                  // Price — hero stat
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        best.currencyCode,
                        style: WwText.priceCurrency(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${best.currencySymbol}${best.priceLocal.toStringAsFixed(2)}',
                        style: WwText.priceHero(),
                      ),
                    ],
                  ),

                  // ── Wit callout ─────────────────────────────────────────
                  if (tier.wit != null && tier.wit!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      decoration: WwDecorations.witCallout(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Text(
                        '" ${tier.wit} "',
                        style: WwText.witQuote(),
                      ),
                    ),
                  ],

                  // ── Educational insight ─────────────────────────────────
                  if (tier.eduInsight != null &&
                      tier.eduInsight!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(
                        style: WwText.bodyMedium(),
                        children: [
                          TextSpan(
                            text: 'The Difference: ',
                            style: WwText.bodyMedium(
                                    color: WwColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: tier.eduInsight),
                        ],
                      ),
                    ),
                  ],

                  // ── Comparison note ─────────────────────────────────────
                  if (tier.comparisonNote != null &&
                      tier.comparisonNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.compare_arrows,
                            size: 14,
                            color: color.withValues(alpha: 0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tier.comparisonNote!,
                            style: WwText.bodySmall()
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Badge row
                  if (best.isPartner ||
                      best.isOnlineOnly ||
                      best.needsVerification) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (best.isPartner)
                          _SmallBadge(
                            label: 'Partner',
                            borderColor: WwColors.violet,
                            icon: Icons.verified,
                          ),
                        if (best.isOnlineOnly)
                          _SmallBadge(
                            label: 'Online Only',
                            borderColor: WwColors.tierNational,
                            icon: Icons.local_shipping_outlined,
                          ),
                        if (best.needsVerification)
                          _SmallBadge(
                            label: 'Call to Confirm Stock',
                            borderColor: WwColors.warning,
                            icon: Icons.phone,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  if (best.needsVerification) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: WwColors.warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: WwColors.warning.withValues(alpha: 0.45),
                            width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: WwColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stock not confirmed. This retailer\'s live inventory '
                              'couldn\'t be verified. Call ahead or use the search '
                              'link below before visiting.',
                              style: TextStyle(
                                color: WwColors.warning,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (best.websiteUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(best.websiteUrl),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(
                          best.needsVerification
                              ? 'Search ${best.name.split(' ').first} (stock unconfirmed)'
                              : 'Shop ${best.name.split(' ').first} Online',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: best.needsVerification
                              ? WwColors.warning
                              : color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: WwText.labelLarge(color: Colors.white),
                        ),
                      ),
                    ),
                  if (best.websiteUrl.isNotEmpty) const SizedBox(height: 8),
                  if (!best.isOnlineOnly && best.address.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openDirections(best.address),
                        icon: Icon(Icons.directions, size: 16, color: color),
                        label: Text(
                          'Get Directions',
                          style: WwText.bodyMedium(color: color),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: color.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  if (!best.isOnlineOnly && best.address.isNotEmpty)
                    const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          _showMerchantSheet(context, tier, color),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color: WwColors.borderMedium, width: 1),
                        foregroundColor: WwColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'See All Stockists',
                        style: WwText.bodyMedium(
                            color: WwColors.textSecondary),
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
      backgroundColor: WwColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MerchantBottomSheet(tier: tier, color: color),
    );
  }
}


// ---------------------------------------------------------------------------
// Merchant bottom sheet
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: WwColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Text(
              'Stockists — ${widget.tier.label}',
              style: WwText.titleMedium(color: widget.color),
            ),
            Text(
              widget.tier.regionHint,
              style: WwText.bodySmall(),
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
                  style: WwText.bodyMedium(color: WwColors.violet),
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
        color: WwColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest ? color : WwColors.borderSubtle,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Distance bubble
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isBest
                  ? color.withValues(alpha: 0.15)
                  : WwColors.bgElevated,
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
                    style: WwText.bodySmall(
                        color: isBest ? color : WwColors.textSecondary)
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                  Icon(
                    Icons.place,
                    size: 12,
                    color: isBest ? color : WwColors.textDisabled,
                  ),
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
                        style: WwText.titleMedium(),
                      ),
                    ),
                    if (isBest)
                      _SmallBadge(label: 'Closest', borderColor: color),
                    if (merchant.isPartner) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Partner',
                        borderColor: WwColors.violet,
                        icon: Icons.verified,
                      ),
                    ],
                    if (merchant.isOnlineOnly) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Online',
                        borderColor: WwColors.tierNational,
                        icon: Icons.local_shipping_outlined,
                      ),
                    ],
                    if (merchant.needsVerification) ...[
                      const SizedBox(width: 4),
                      _SmallBadge(
                        label: 'Call First',
                        borderColor: WwColors.warning,
                        icon: Icons.phone,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  merchant.address,
                  style: WwText.bodySmall(),
                ),
                if (merchant.websiteUrl.isNotEmpty ||
                    (!merchant.isOnlineOnly && merchant.address.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (merchant.websiteUrl.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openUrl(merchant.websiteUrl),
                            icon: const Icon(Icons.open_in_new, size: 13),
                            label: const Text('Online'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              side: BorderSide(color: WwColors.violet.withValues(alpha: 0.5)),
                              foregroundColor: WwColors.violet,
                              textStyle: const TextStyle(fontSize: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (merchant.websiteUrl.isNotEmpty &&
                          !merchant.isOnlineOnly &&
                          merchant.address.isNotEmpty)
                        const SizedBox(width: 8),
                      if (!merchant.isOnlineOnly && merchant.address.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openDirections(merchant.address),
                            icon: Icon(Icons.directions, size: 13, color: color),
                            label: const Text('Directions'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              side: BorderSide(color: color.withValues(alpha: 0.5)),
                              foregroundColor: color,
                              textStyle: const TextStyle(fontSize: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${merchant.currencySymbol}${merchant.priceLocal.toStringAsFixed(2)}',
            style: WwText.bodyMedium(color: color)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Small badge chip — outlined style
// ---------------------------------------------------------------------------

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color borderColor;
  final IconData? icon;

  const _SmallBadge({
    required this.label,
    required this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: borderColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: borderColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Empty tier card
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
      decoration: WwDecorations.card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              decoration: WwDecorations.tierHeader(
                  color.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Text(
                  tier.label.toUpperCase(),
                  style: WwText.badgeLabel(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.search_off,
                      color: WwColors.textDisabled),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No ${tier.label} options found for this wine.',
                      style: WwText.bodyMedium(),
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
// Suppressed tier card
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
      decoration: WwDecorations.card(
          borderColor: color.withValues(alpha: 0.25)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: WwDecorations.tierHeader(
                  color.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      tier.label.toUpperCase(),
                      style: WwText.badgeLabel(),
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
                    style: WwText.bodyMedium(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onShowGlobal,
                    icon: Icon(Icons.public, size: 16, color: color),
                    label: Text('Show international options',
                        style: WwText.bodyMedium(color: color)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                      foregroundColor: color,
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
// Pricing Precedent banner
// ---------------------------------------------------------------------------

class _PricingPrecedentBanner extends StatelessWidget {
  final VoidCallback onShowGlobal;

  const _PricingPrecedentBanner({required this.onShowGlobal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WwColors.bgSurface,
        border: Border.all(color: WwColors.violetMuted),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: WwColors.violet, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Global Icon hidden — it's significantly pricier than the local option.",
              style: WwText.bodySmall(color: WwColors.violet),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onShowGlobal,
            child: Text('Show', style: WwText.bodyMedium(color: WwColors.violet)),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Global tier toggle
// ---------------------------------------------------------------------------

class _GlobalTierToggle extends StatelessWidget {
  final VoidCallback onHide;

  const _GlobalTierToggle({required this.onHide});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.public, size: 13, color: WwColors.textDisabled),
        const SizedBox(width: 6),
        Text(
          'International options unlocked',
          style: WwText.bodySmall(),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onHide,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Hide',
              style: WwText.bodySmall(color: WwColors.violet)),
        ),
      ],
    );
  }
}
