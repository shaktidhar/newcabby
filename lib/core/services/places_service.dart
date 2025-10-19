import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import '../config/supabase_config.dart';

class PlaceSuggestion {
  final String description;
  final String placeId;
  PlaceSuggestion(this.description, this.placeId);
}

class PlaceDetails {
  final String address;
  final double lat;
  final double lng;
  PlaceDetails({required this.address, required this.lat, required this.lng});
}

class PlacesService {
  final String _base = kSupabaseFunctionsBase;

  @visibleForTesting
  Uri _uri(Map<String, String> qp) =>
      Uri.parse('$_base/places').replace(queryParameters: qp);

  Future<List<PlaceSuggestion>> autocomplete(
      String input, {
        String language = 'pt',
        String? country,
      }) async {
    if (input.trim().isEmpty) return [];

    final qp = <String, String>{
      'mode': 'autocomplete',
      'q': input,
      'lang': language,
      if (country != null) 'country': country,
    };
    final r = await http.get(_uri(qp));
    if (r.statusCode != 200) {
      throw 'places ${r.statusCode}: ${r.body}';
    }

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final preds = (data['predictions'] as List?) ?? const [];
    return preds
        .map((p) => p as Map<String, dynamic>)
        .map((m) => PlaceSuggestion(
      (m['description'] as String?) ?? '',
      (m['place_id'] as String?) ?? '',
    ))
        .where((s) => s.description.isNotEmpty && s.placeId.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails?> details(String placeId, {String language = 'pt'}) async {
    final qp = <String, String>{
      'mode': 'details',
      'place_id': placeId,
      'lang': language,
    };
    final r = await http.get(_uri(qp));
    if (r.statusCode != 200) {
      throw 'places ${r.statusCode}: ${r.body}';
    }

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final result = data['result'] as Map<String, dynamic>;
    final loc = (result['geometry']['location'] as Map<String, dynamic>);
    return PlaceDetails(
      address: (result['formatted_address'] as String?) ??
          (result['name'] as String? ?? ''),
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }
}
