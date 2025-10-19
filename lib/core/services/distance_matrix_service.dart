// lib/core/services/distance_matrix_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripDistance {
  final double km;
  final double minutes;
  final String? polyline; // if your edge function returns it
  TripDistance(this.km, this.minutes, {this.polyline});
}

class DistanceMatrixService {
  final _fx = Supabase.instance.client.functions;

  /// Supports both normalized (Routes API) and raw Distance Matrix payloads.
  Future<TripDistance> compute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String language = 'pt',
  }) async {
    try {
      final res = await _fx.invoke(
        'distance',
        method: HttpMethod.post,
        body: {
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toLat': toLat,
          'toLng': toLng,
          'lang': language,
          'mode': 'driving', // harmless if using Routes API
        },
      );

      final data = _asMap(res.data);

      // Normalized (Routes API) shape
      final dk = _asDouble(data['distance_km']);
      final dm = _asDouble(data['duration_min']);
      if (dk != null && dm != null) {
        return TripDistance(dk, dm, polyline: data['polyline'] as String?);
      }

      // Raw Distance Matrix shape
      final status = data['status'] as String?;
      if (status != null && status != 'OK') {
        debugPrint('Distance top-level status != OK: $status');
        throw 'Distance error: $status';
      }
      final rows = (data['rows'] as List?) ?? const [];
      if (rows.isEmpty) throw 'Distance Matrix returned no rows';
      final elements = ((rows.first as Map)['elements'] as List?) ?? const [];
      if (elements.isEmpty) throw 'Distance Matrix returned no elements';

      final el = elements.first as Map<String, dynamic>;
      final estatus = el['status'] as String?;
      if (estatus != null && estatus != 'OK') {
        debugPrint('Distance element status != OK: $estatus');
        throw 'Distance error: $estatus';
      }

      final meters = (el['distance']['value'] as num).toDouble();
      final seconds = (el['duration']['value'] as num).toDouble();
      return TripDistance(meters / 1000.0, seconds / 60.0);
    } catch (e) {
      debugPrint('DistanceMatrixService.compute error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) return jsonDecode(raw) as Map<String, dynamic>;
    return const {};
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
