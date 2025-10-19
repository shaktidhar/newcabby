import 'package:supabase_flutter/supabase_flutter.dart';

class RouteSummary {
  final double? distanceKm;
  final double? durationMin;
  final String? polyline;

  RouteSummary({this.distanceKm, this.durationMin, this.polyline});

  factory RouteSummary.fromJson(Map<String, dynamic> j) => RouteSummary(
    distanceKm: (j['distance_km'] as num?)?.toDouble(),
    durationMin: (j['duration_min'] as num?)?.toDouble(),
    polyline: j['polyline'] as String?,
  );
}

class DistanceApi {
  final _fn = Supabase.instance.client.functions;

  Future<RouteSummary> compute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String lang = 'pt',
  }) async {
    final res = await _fn.invoke('distance', body: {
      'fromLat': fromLat, 'fromLng': fromLng,
      'toLat': toLat, 'toLng': toLng,
      'lang': lang,
    });
    return RouteSummary.fromJson(Map<String, dynamic>.from(res.data));
  }
}
