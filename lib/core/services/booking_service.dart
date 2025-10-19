// lib/core/services/booking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

enum BookingPaymentMethod { card, cash }

class BookingResult {
  final Map<String, dynamic> booking;
  final String? clientSecret;
  BookingResult(this.booking, this.clientSecret);
}

class BookingService {
  final _fx = Supabase.instance.client.functions;
  final _auth = Supabase.instance.client.auth;

  Future<BookingResult> createBooking({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required DateTime when,
    required String vehicleTypeId,
    int pax = 1,
    int luggage = 0,
    String currency = 'EUR',
    BookingPaymentMethod paymentMethod = BookingPaymentMethod.card,
  }) async {
    final body = {
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_address': dropoffAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'when': when.toIso8601String(),
      'vehicle_type_id': vehicleTypeId,
      'pax': pax,
      'luggage': luggage,
      'currency': currency,
      'payment_method': paymentMethod == BookingPaymentMethod.cash ? 'cash' : 'card',
    };

    // You must be logged in: our edge function requires Authorization: Bearer <access token>
    final accessToken = _auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw 'You must sign in before booking.';
    }

    // 1) Preferred path: functions.invoke
    try {
      final res = await _fx.invoke(
        'book',
        method: HttpMethod.post,
        body: body,
      );

      final data = _normalize(res.data);
      _throwIfEdgeError(data);

      return BookingResult(
        Map<String, dynamic>.from(data['booking'] as Map),
        data['client_secret'] as String?,
      );
    } catch (e) {
      // If the error smells like “couldn’t resolve functions URL” or similar, try fallback.
      final msg = e.toString().toLowerCase();
      final looksLikeUrlProblem = msg.contains('functions') &&
          (msg.contains('url') || msg.contains('{{') || msg.contains('failed to fetch'));

      if (!looksLikeUrlProblem) rethrow;
      // Fall through to direct HTTP.
    }

    // 2) Fallback path: direct POST to functions endpoint
    final uri = Uri.parse('$kSupabaseFunctionsBase/book');
    final r = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // IMPORTANT: forward the user’s access token — the function expects a logged-in user
        'Authorization': 'Bearer $accessToken',
        // Some Edge setups also like to see the anon key (not required for auth, but harmless):
        'apikey': Supabase.instance.client.auth.currentSession?.providerToken ?? '',
      },
      body: jsonEncode(body),
    );

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw 'book ${r.statusCode}: ${r.body}';
    }

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    _throwIfEdgeError(data);

    return BookingResult(
      Map<String, dynamic>.from(data['booking'] as Map),
      data['client_secret'] as String?,
    );
  }

  Map<String, dynamic> _normalize(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    return Map<String, dynamic>.from(raw as Map);
  }

  void _throwIfEdgeError(Map<String, dynamic> data) {
    if (data['error'] != null) {
      final detail = data['message'] ?? data['detail'] ?? '';
      throw '${data['error']}: $detail';
    }
  }
}
