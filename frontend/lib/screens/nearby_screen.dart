import 'package:flutter/material.dart';

import '../models/merchant.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

enum _SortMode { distance, price }

class NearbyScreen extends StatefulWidget {
  final String wineName;
  final double budgetMin;
  final double budgetMax;

  const NearbyScreen({
    super.key,
    required this.wineName,
    required this.budgetMin,
    required this.budgetMax,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  List<Merchant>? _merchants;
  bool _loading = true;
  String? _error;
  _SortMode _sortMode = _SortMode.distance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await LocationService().getCurrentPosition();
      final merchants = await ApiService().nearby(
        wineName: widget.wineName,
        userLat: position.latitude,
        userLng: position.longitude,
        budgetMin: widget.budgetMin,
        budgetMax: widget.budgetMax,
      );
      setState(() {
        _merchants = merchants;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Merchant> get _sorted {
    if (_merchants == null) return [];
    final list = List<Merchant>.from(_merchants!);
    if (_sortMode == _SortMode.price) {
      list.sort((a, b) => a.priceUsd.compareTo(b.priceUsd));
    } else {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
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

    if (_merchants == null || _merchants!.isEmpty) {
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

    final sorted = _sorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Sort toggle ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                '${sorted.length} merchants found  ·  Sort by:',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(width: 8),
              SegmentedButton<_SortMode>(
                segments: const [
                  ButtonSegment(
                    value: _SortMode.distance,
                    label: Text('Distance'),
                    icon: Icon(Icons.near_me, size: 14),
                  ),
                  ButtonSegment(
                    value: _SortMode.price,
                    label: Text('Price'),
                    icon: Icon(Icons.attach_money, size: 14),
                  ),
                ],
                selected: {_sortMode},
                onSelectionChanged: (s) =>
                    setState(() => _sortMode = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final m = sorted[index];
              final isBest = index == 0;
              return _MerchantCard(
                merchant: m,
                isBest: isBest,
                sortMode: _sortMode,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MerchantCard extends StatelessWidget {
  final Merchant merchant;
  final bool isBest;
  final _SortMode sortMode;

  const _MerchantCard({
    required this.merchant,
    required this.isBest,
    required this.sortMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final badgeLabel =
        sortMode == _SortMode.distance ? 'Closest' : 'Best Price';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isBest
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distance badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isBest
                    ? color.withValues(alpha: 0.12)
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBest ? color : Colors.grey.shade700,
                      ),
                    ),
                    Icon(Icons.place,
                        size: 14,
                        color: isBest ? color : Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
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
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    merchant.brand,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    merchant.address,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${merchant.priceUsd.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
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
