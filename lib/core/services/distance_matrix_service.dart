// lib/core/services/distance_matrix_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripDistance {
  final double km;
  final double minutes;
  TripDistance(this.km, this.minutes);
}

class DistanceMatrixService {
  final _fx = Supabase.instance.client.functions;

  Future<TripDistance> compute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
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
          'mode': 'driving',
          'lang': 'pt',
        },
      );

      // Edge Functions can return a String body; normalize to Map
      final dynamic raw = res.data;
      final Map<String, dynamic> data =
      raw is String ? jsonDecode(raw) as Map<String, dynamic> : (raw as Map<String, dynamic>);

      // If your function forwards Distance Matrix as-is, these are expected:
      // data.status == 'OK', data.rows[0].elements[0].status == 'OK'
      if ((data['status'] as String?) != 'OK') {
        // Surface the error to the console so you can see what Google returned.
        debugPrint('DistanceMatrix top-level status != OK. Payload: $data');
        throw 'Distance Matrix top-level status: ${data['status']}';
      }

      final rows = (data['rows'] as List?) ?? const [];
      if (rows.isEmpty) throw 'Distance Matrix returned no rows';

      final elements = ((rows.first as Map)['elements'] as List?) ?? const [];
      if (elements.isEmpty) throw 'Distance Matrix returned no elements';

      final el = elements.first as Map<String, dynamic>;
      if ((el['status'] as String?) != 'OK') {
        debugPrint('DistanceMatrix element status != OK. Element: $el');
        throw 'Distance Matrix element status: ${el['status']}';
      }

      final meters = (el['distance']['value'] as num).toDouble();
      final seconds = (el['duration']['value'] as num).toDouble();
      return TripDistance(meters / 1000.0, seconds / 60.0);
    } catch (e, st) {
      // This makes failures visible in the browser console/IDE run tab.
      debugPrint('DistanceMatrixService.compute error: $e\n$st');
      rethrow; // let the UI show "N/A"
    }
  }
}
