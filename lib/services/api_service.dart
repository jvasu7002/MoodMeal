import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // =====================================================
  // BASE URL
  // =====================================================

  // Chrome / local PC testing
  static const String baseUrl = "https://moodmeal-o6qa.onrender.com";
  // Physical Android phone ke liye later PC IP use karna hoga.
  // Example:
  // static const String baseUrl = "http://192.168.1.5:8000";


  // =====================================================
  // TEST RECOMMENDATIONS
  // =====================================================

  static Future<void> testRecommendations() async {
    try {
      final recommendations = await getRecommendations(
        latitude: 28.6328,
        longitude: 77.2197,
        mood: "happy",
        preferredDistance: 5,
        favoriteCuisines: [
          "Indian",
          "Chinese",
        ],
      );

      print("================================");
      print("Recommendations received:");
      print(recommendations);
      print("================================");
    } catch (e) {
      print("API ERROR: $e");
    }
  }


  // =====================================================
  // GET RESTAURANT RECOMMENDATIONS
  // =====================================================

  static Future<List<dynamic>> getRecommendations({
    required double latitude,
    required double longitude,
    required String mood,
    required double preferredDistance,
    required List<String> favoriteCuisines,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/recommendations",
    ).replace(
      queryParameters: {
        "latitude": latitude.toString(),
        "longitude": longitude.toString(),
        "mood": mood,
        "preferred_distance":
            preferredDistance.toString(),
        "favorite_cuisines":
            favoriteCuisines.join(","),
      },
    );

    print("================================");
    print("RESTAURANT API URL:");
    print(uri);

    try {
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
          );

      print(
        "RESTAURANT API STATUS: "
        "${response.statusCode}",
      );

      print("RESTAURANT API RESPONSE:");
      print(response.body);

      print("================================");

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to load restaurant recommendations. "
          "Server returned ${response.statusCode}.",
        );
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception(
          "Invalid restaurant API response.",
        );
      }

      return data["recommendations"] ?? [];
    } catch (e) {
      print("Restaurant API Error: $e");

      rethrow;
    }
  }


  // =====================================================
  // AI RECOMMENDATION - RAG + LLM
  // =====================================================

  static Future<Map<String, dynamic>> getAiRecommendationResult({
    required String userQuery,
    required String mood,
    required String diet,
    required String cuisine,
    required double budget,
    double? latitude,
    double? longitude,
  }) async {
    final cleanUserQuery = userQuery.trim();
    final cleanMood = mood.trim();
    final cleanDiet = diet.trim();
    final cleanCuisine = cuisine.trim();

    final queryParameters = <String, String>{
      "user_query": cleanUserQuery,
      "mood": cleanMood,
      "diet": cleanDiet,
      "cuisine": cleanCuisine,
      "budget": budget.toString(),
    };

    if (latitude != null && longitude != null) {
      queryParameters["latitude"] = latitude.toString();
      queryParameters["longitude"] = longitude.toString();
    }

    final uri = Uri.parse("$baseUrl/ai-recommendation").replace(
      queryParameters: queryParameters,
    );

    print("================================");
    print("AI RECOMMENDATION API");
    print("AI API URL: $uri");

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 60));

      print("AI API STATUS: ${response.statusCode}");
      print("AI API RESPONSE: ${response.body}");
      print("================================");

      if (response.statusCode != 200) {
        String errorMessage = "Failed to get AI recommendation.";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData["detail"] != null) {
            errorMessage = errorData["detail"].toString();
          }
        } catch (_) {
          // Keep default error message.
        }
        throw Exception("$errorMessage (Status: ${response.statusCode})");
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception("Invalid AI recommendation response.");
      }

      final recommendation = data["recommendation"];
      if (recommendation == null ||
          recommendation.toString().trim().isEmpty) {
        throw Exception("AI recommendation was not returned by the server.");
      }

      return data;
    } catch (e) {
      print("================================");
      print("AI API ERROR: $e");
      print("================================");
      rethrow;
    }
  }

  // Backward-compatible helper for any existing screens that only need text.
  static Future<String> getAiRecommendation({
    required String userQuery,
    required String mood,
    required String diet,
    required String cuisine,
    required double budget,
  }) async {
    final result = await getAiRecommendationResult(
      userQuery: userQuery,
      mood: mood,
      diet: diet,
      cuisine: cuisine,
      budget: budget,
    );
    return result["recommendation"].toString().trim();
  }

}