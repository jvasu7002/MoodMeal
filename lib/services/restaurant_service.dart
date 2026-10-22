import 'dart:convert';
import 'package:http/http.dart' as http;

class RestaurantService {
  // Public Overpass servers.
  // If one fails, the next server is tried.
  static const List<String> _overpassServers = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  ];

  // --------------------------------------------------
  // GET LOCATION COORDINATES
  // --------------------------------------------------

  static Future<Map<String, double>> getCoordinatesFromCity(
    String location,
  ) async {
    final encodedLocation = Uri.encodeQueryComponent(location);

    final response = await http.get(
      Uri.parse(
        "https://nominatim.openstreetmap.org/search"
        "?format=json"
        "&q=$encodedLocation"
        "&limit=1",
      ),
      headers: {
        "User-Agent": "MoodMeal/1.0",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Unable to find location. Status: ${response.statusCode}",
      );
    }

    final data = jsonDecode(response.body);

    if (data.isEmpty) {
      throw Exception("Location not found.");
    }

    return {
      "lat": double.parse(data[0]["lat"]),
      "lon": double.parse(data[0]["lon"]),
    };
  }

  // --------------------------------------------------
  // GET NEARBY RESTAURANTS
  // --------------------------------------------------

  static Future<List<dynamic>> getNearbyRestaurants(
    double lat,
    double lon,
    int radius,
  ) async {
    // IMPORTANT:
    // Use the exact radius selected by the user.
    //
    // Example:
    // 5 km  -> 5000 metres
    // 10 km -> 10000 metres
    // 20 km -> 20000 metres
    //
    // No artificial 3 km limit.

    if (radius <= 0) {
      throw Exception("Invalid restaurant search radius.");
    }

    final query = """
[out:json][timeout:30];

(
  nwr["amenity"="restaurant"]
    (around:$radius,$lat,$lon);

  nwr["amenity"="cafe"]
    (around:$radius,$lat,$lon);

  nwr["amenity"="fast_food"]
    (around:$radius,$lat,$lon);

  nwr["amenity"="food_court"]
    (around:$radius,$lat,$lon);
);

out center qt;
""";

    Exception? lastError;

    // --------------------------------------------------
    // TRY OVERPASS SERVERS
    // --------------------------------------------------

    for (final server in _overpassServers) {
      try {
        print("=================================");
        print("Trying Overpass server:");
        print(server);
        print("Latitude: $lat");
        print("Longitude: $lon");
        print("Radius: ${radius / 1000} km");
        print("=================================");

        final response = await http
            .post(
              Uri.parse(server),
              headers: {
                "Content-Type":
                    "application/x-www-form-urlencoded",
                "User-Agent":
                    "MoodMeal/1.0",
              },
              body: {
                "data": query,
              },
            )
            .timeout(
              const Duration(seconds: 40),
            );

        print(
          "Overpass status: ${response.statusCode}",
        );

        // --------------------------------------------------
        // SUCCESS
        // --------------------------------------------------

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          final restaurants =
              List<dynamic>.from(
            data["elements"] ?? [],
          );

          print(
            "Restaurants received: "
            "${restaurants.length}",
          );

          return restaurants;
        }

        // --------------------------------------------------
        // SERVER ERROR
        // --------------------------------------------------

        lastError = Exception(
          "Overpass server returned "
          "${response.statusCode}",
        );

        print(
          "Overpass failed: "
          "${response.statusCode}",
        );
      } catch (e) {
        lastError = Exception(e.toString());

        print(
          "Overpass server error: $e",
        );
      }
    }

    // --------------------------------------------------
    // ALL SERVERS FAILED
    // --------------------------------------------------

    print("Last Overpass error: $lastError");

    throw Exception(
      "Unable to load restaurants right now. "
      "Please try again.",
    );
  }
}