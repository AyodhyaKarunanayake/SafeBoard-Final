// Google Maps/Places API key used to search real-world place names when
// picking a boarding/alighting stop (see lib/services/places_service.dart).
//
// To enable this feature:
//   1. Create a key at https://console.cloud.google.com/ (enable "Places API"
//      and set up billing).
//   2. Replace the placeholder below with that key.
// Until replaced, place search silently returns no results and the stop
// picker falls back to its built-in Route 87 stop list.
const String googleMapsApiKey = googleMapsApiKeyPlaceholder;

const String googleMapsApiKeyPlaceholder = 'YOUR_GOOGLE_MAPS_API_KEY';

bool get isGoogleMapsApiKeyConfigured => googleMapsApiKey != googleMapsApiKeyPlaceholder && googleMapsApiKey.isNotEmpty;
