import 'package:supabase_flutter/supabase_flutter.dart';

class Suggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  Suggestion({required this.placeId, required this.description, this.mainText, this.secondaryText});

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
    placeId: j['place_id'],
    description: j['description'],
    mainText: j['main_text'],
    secondaryText: j['secondary_text'],
  );
}

class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final double lat;
  final double lng;
  final String? country;

  PlaceDetails({required this.placeId, required this.formattedAddress, required this.lat, required this.lng, this.country});

  factory PlaceDetails.fromJson(Map<String, dynamic> j) => PlaceDetails(
    placeId: j['place_id'],
    formattedAddress: j['formatted_address'],
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    country: j['country'],
  );
}

class PlacesApi {
  final _fn = Supabase.instance.client.functions;

  Future<List<Suggestion>> autocomplete({
    required String query,
    String lang = 'pt',
    String country = 'pt',
    required String sessionToken,
  }) async {
    final res = await _fn.invoke('places', body: {
      'mode': 'autocomplete',
      'q': query,
      'lang': lang,
      'country': country,
      'session_token': sessionToken,
    });
    final list = (res.data['suggestions'] as List).cast<Map<String, dynamic>>();
    return list.map(Suggestion.fromJson).toList();
  }

  Future<PlaceDetails> details({
    required String placeId,
    String lang = 'pt',
    required String sessionToken,
  }) async {
    final res = await _fn.invoke('places', body: {
      'mode': 'details',
      'place_id': placeId,
      'lang': lang,
      'session_token': sessionToken,
    });
    return PlaceDetails.fromJson(Map<String, dynamic>.from(res.data));
  }
}
