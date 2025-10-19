// lib/core/services/places_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceSuggestion {
  final String description;
  final String placeId;
  PlaceSuggestion(this.description, this.placeId);
}

class PlaceDetails {
  final String address;
  final double lat;
  final double lng;
  final String? country;
  PlaceDetails({
    required this.address,
    required this.lat,
    required this.lng,
    this.country,
  });
}

class PlacesService {
  final _fx = Supabase.instance.client.functions;

  // If caller doesn't pass a sessionToken, we generate/cache one per service instance.
  String? _cachedToken;
  String _ensureToken([String? explicit]) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _cachedToken ??= _randomToken();
  }

  /// Autocomplete via POST to /functions/v1/places
  /// Works with both normalized `{ suggestions: [...] }` and raw Google `{ predictions: [...] }`.
  Future<List<PlaceSuggestion>> autocomplete(
      String input, {
        String language = 'pt',
        String? country,
        String? sessionToken,
      }) async {
    if (input.trim().isEmpty) return const [];

    try {
      final token = _ensureToken(sessionToken);
      final res = await _fx.invoke(
        'places',
        method: HttpMethod.post,
        body: {
          'mode': 'autocomplete',
          'q': input,
          'lang': language,
          if (country != null) 'country': country,
          'session_token': token,
        },
      );

      final data = _asMap(res.data);

      // Prefer normalized; fall back to Google shape.
      final List raw =
          (data['suggestions'] as List?) ?? (data['predictions'] as List?) ?? const [];

      return raw
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .map((m) {
        final desc = (m['description'] as String?) ??
            _joinNonEmpty([
              m['main_text'] as String?,
              m['secondary_text'] as String?,
            ]) ??
            '';
        final pid = (m['place_id'] as String?) ?? '';
        return PlaceSuggestion(desc, pid);
      })
          .where((s) => s.description.isNotEmpty && s.placeId.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('PlacesService.autocomplete error: $e');
      rethrow;
    }
  }

  /// Details via POST to /functions/v1/places
  /// Works with normalized fields OR raw Google result payload.
  Future<PlaceDetails?> details(
      String placeId, {
        String language = 'pt',
        String? sessionToken,
      }) async {
    if (placeId.trim().isEmpty) return null;

    try {
      final token = _ensureToken(sessionToken);
      final res = await _fx.invoke(
        'places',
        method: HttpMethod.post,
        body: {
          'mode': 'details',
          'place_id': placeId,
          'lang': language,
          'session_token': token,
        },
      );

      final data = _asMap(res.data);

      // Normalized payload path
      if (data.containsKey('lat') && data.containsKey('lng')) {
        final addr = (data['formatted_address'] as String?) ??
            (data['address'] as String?) ??
            '';
        return PlaceDetails(
          address: addr,
          lat: (data['lat'] as num).toDouble(),
          lng: (data['lng'] as num).toDouble(),
          country: data['country'] as String?,
        );
      }

      // Raw Google path
      final status = data['status'] as String?;
      if (status != null && status != 'OK') {
        debugPrint('PlacesService.details upstream status != OK: $status');
        return null;
      }

      final result = (data['result'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geometry = (result['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
      final loc = (geometry['location'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (!loc.containsKey('lat') || !loc.containsKey('lng')) return null;

      final address =
          (result['formatted_address'] as String?) ?? (result['name'] as String?) ?? '';
      return PlaceDetails(
        address: address,
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('PlacesService.details error: $e');
      rethrow;
    }
  }

  // ---------- helpers ----------

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return const {};
  }

  String? _joinNonEmpty(List<String?> parts) {
    final filtered = parts.where((e) => (e ?? '').trim().isNotEmpty).toList();
    if (filtered.isEmpty) return null;
    return filtered.join(', ');
  }

  String _randomToken() {
    final r = Random();
    // Simple token that’s stable enough for a user’s short search flow.
    return 'sess_${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }
}
