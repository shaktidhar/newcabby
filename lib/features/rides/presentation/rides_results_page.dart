// lib/features/rides/presentation/rides_results_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../rides/state/ride_search_state.dart';
import '../../../core/services/distance_matrix_service.dart';
import '../../../core/services/booking_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe; // OK to import; we just won't call on web.

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    try {
      final res = await supa.from('vehicle_types').select().eq('active', true);
      _types = (res as List).cast<Map<String, dynamic>>();

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

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vehicle types: $e';
        _loading = false;
      });
    }
  }

  Future<void> _onBookPressed(String vehicleTypeId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = ref.read(rideSearchProvider);

      // Create booking in "pending_payment" (mobile) or "pending" (web fallback)
      final result = await BookingService().createBooking(
        pickupAddress: s.pickupAddress,
        pickupLat: s.pickupLat!,
        pickupLng: s.pickupLng!,
        dropoffAddress: s.dropoffAddress,
        dropoffLat: s.dropoffLat!,
        dropoffLng: s.dropoffLng!,
        when: s.when,
        vehicleTypeId: vehicleTypeId,
        pax: s.pax,
        luggage: s.luggage,
        currency: 'EUR',
        paymentMethod: BookingPaymentMethod.card,
      );

      if (kIsWeb) {
        // Web: we didn’t init Stripe to avoid the Platform crash.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking created. Card payment is disabled on web dev build — use Cash for now.'),
          ),
        );
        return;
      }

      // Mobile: present Stripe Payment Sheet if we got a client secret
      final clientSecret = result.clientSecret;
      if (clientSecret != null && clientSecret.isNotEmpty) {
        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'NewCabby',
            allowsDelayedPaymentMethods: true,
          ),
        );
        await stripe.Stripe.instance.presentPaymentSheet();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful. Booking confirmed.')),
        );
        // TODO: navigate to confirmation screen with result.booking['id']
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created. Awaiting payment.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onBookCashPressed(String vehicleTypeId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = ref.read(rideSearchProvider);

      final result = await BookingService().createBooking(
        pickupAddress: s.pickupAddress,
        pickupLat: s.pickupLat!,
        pickupLng: s.pickupLng!,
        dropoffAddress: s.dropoffAddress,
        dropoffLat: s.dropoffLat!,
        dropoffLng: s.dropoffLng!,
        when: s.when,
        vehicleTypeId: vehicleTypeId,
        pax: s.pax,
        luggage: s.luggage,
        currency: 'EUR',
        paymentMethod: BookingPaymentMethod.cash,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cash booking created. Ref: ${result.booking['id']}')),
      );
      // TODO: navigate to a "cash booking pending" screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cash booking failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(rideSearchProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: _types.isEmpty
          ? const Center(child: Text('No vehicle types configured.'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _types.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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

          final vehicleTypeId = (t['id'] as String?) ?? '';

          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car),
                    title: Text((t['label'] ?? t['code'] ?? '').toString()),
                    subtitle: Text(
                      hasTrip
                          ? '${_km!.toStringAsFixed(1)} km • ${_minutes!.toStringAsFixed(0)} min'
                          : 'Distance N/A',
                    ),
                    trailing: Text(
                      est != null ? '€${est.toStringAsFixed(2)}' : '—',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: (_busy || vehicleTypeId.isEmpty)
                            ? null
                            : () => _onBookCashPressed(vehicleTypeId),
                        child: const Text('Cash'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_busy || vehicleTypeId.isEmpty)
                            ? null
                            : () => _onBookPressed(vehicleTypeId),
                        child: _busy
                            ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(kIsWeb ? 'Book (Card: mobile only)' : 'Book & Pay'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
