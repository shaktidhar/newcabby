import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../rides/state/ride_search_state.dart';
import '../../../core/services/distance_matrix_service.dart';

double estimateLocal({
  required double km,
  required double minutes,
  required double basePerKm,
  required double basePerMin,
  required double baseStartFee,
  required bool isPremium,
  required int pax,
  required int luggage,
}) {
  double price = baseStartFee + km * basePerKm + minutes * basePerMin;
  if (isPremium) price *= 1.20;
  if (pax > 4) price *= 1.10;
  if (luggage > 4) price += 5.0;
  if (price < 6.0) price = 6.0;
  return double.parse(price.toStringAsFixed(2));
}

class RidesResultsPage extends ConsumerStatefulWidget {
  const RidesResultsPage({super.key});
  @override
  ConsumerState<RidesResultsPage> createState() => _RidesResultsPageState();
}

class _RidesResultsPageState extends ConsumerState<RidesResultsPage> {
  List<Map<String, dynamic>> _types = [];
  double? _km;
  double? _minutes;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    try {
      // 1) Always load vehicle types first so UI can render even if distance fails
      final res = await supa.from('vehicle_types').select().eq('active', true);
      _types = (res as List).cast<Map<String, dynamic>>();

      // 2) Then try Distance Matrix through the Edge Function (non-blocking)
      try {
        final s = ref.read(rideSearchProvider);
        if (s.pickupLat != null && s.dropoffLat != null) {
          final dm = DistanceMatrixService();
          final t = await dm.compute(
            fromLat: s.pickupLat!, fromLng: s.pickupLng!,
            toLat: s.dropoffLat!, toLng: s.dropoffLng!,
          );
          _km = t.km;
          _minutes = t.minutes;
        }
      } catch (e) {
        debugPrint('DistanceMatrix failed: $e');
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load vehicle types: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(rideSearchProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Results')),
          body: Center(child: Text(_error!)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: _types.isEmpty
          ? const Center(child: Text('No vehicle types configured.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final t = _types[i];
          final hasTrip = _km != null && _minutes != null;

          final est = hasTrip
              ? estimateLocal(
            km: _km!,
            minutes: _minutes!,
            basePerKm: (t['base_per_km'] as num).toDouble(),
            basePerMin: (t['base_per_min'] as num).toDouble(),
            baseStartFee: (t['base_start_fee'] as num).toDouble(),
            isPremium: (t['is_premium'] as bool?) ?? false,
            pax: s.pax,
            luggage: s.luggage,
          )
              : null;

          return Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text((t['label'] ?? t['code'] ?? '').toString()),
              subtitle: Text(hasTrip
                  ? '${_km!.toStringAsFixed(1)} km • ${_minutes!.toStringAsFixed(0)} min'
                  : 'Distance N/A'),
              trailing: Text(
                est != null ? '€${est.toStringAsFixed(2)}' : '—',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected ${t['label'] ?? t['code']}')),
                );
                // TODO: context.go('/rides/checkout', extra: {...});
              },
            ),
          );
        },
      ),
    );
  }
}
