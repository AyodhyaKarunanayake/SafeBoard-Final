import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({required this.placeId, required this.description});
}

class PlaceLatLng {
  final double lat;
  final double lng;

  const PlaceLatLng(this.lat, this.lng);
}

// Thin wrapper around the Google Places "Autocomplete" and "Place Details"
// REST endpoints. Both are plain HTTP calls (no native Maps SDK needed),
// so the only setup required is a valid API key in lib/config/api_keys.dart.
class PlacesService {
  static const _autocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (!isGoogleMapsApiKeyConfigured || input.trim().isEmpty) return [];

    final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: {
      'input': input,
      'key': googleMapsApiKey,
      // Bias results to Sri Lanka since Route 87 only runs within the country.
      'components': 'country:lk',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];

      final predictions = (data['predictions'] as List<dynamic>?) ?? [];
      return predictions
          .map((p) => PlaceSuggestion(
                placeId: p['place_id'] as String,
                description: p['description'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<PlaceLatLng?> getPlaceLatLng(String placeId) async {
    if (!isGoogleMapsApiKeyConfigured) return null;

    final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
      'place_id': placeId,
      'fields': 'geometry',
      'key': googleMapsApiKey,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final location = data['result']?['geometry']?['location'];
      if (location == null) return null;

      return PlaceLatLng((location['lat'] as num).toDouble(), (location['lng'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }
}
