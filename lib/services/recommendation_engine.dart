import 'dart:math';

import '../models/user_model.dart';

class RecommendationResult {
  final dynamic restaurant;
  final double score;
  final double distance;
  final List<String> reasons;

  RecommendationResult({
    required this.restaurant,
    required this.score,
    required this.distance,
    required this.reasons,
  });

  factory RecommendationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return RecommendationResult(
      restaurant: json["restaurant"] ?? {},
      score: (json["score"] ?? 0).toDouble(),
      distance: (json["distance"] ?? 0).toDouble(),
      reasons: List<String>.from(
        json["reasons"] ?? [],
      ),
    );
  }
}

class RecommendationEngine {
  static List<RecommendationResult> recommend({
    required List<dynamic> restaurants,
    required UserModel user,
    required String mood,
    required double latitude,
    required double longitude,
  }) {
    final results = <RecommendationResult>[];

    for (final restaurant in restaurants) {
      final tags = restaurant["tags"] ?? {};

      final cuisine =
          (tags["cuisine"] ?? "").toString();

      final restaurantType =
          (tags["amenity"] ?? "").toString();

      final restaurantLat =
          restaurant["lat"] ??
          restaurant["center"]?["lat"];

      final restaurantLon =
          restaurant["lon"] ??
          restaurant["center"]?["lon"];

      if (restaurantLat == null ||
          restaurantLon == null) {
        continue;
      }

      final restaurantLatitude =
          double.tryParse(restaurantLat.toString());

      final restaurantLongitude =
          double.tryParse(restaurantLon.toString());

      if (restaurantLatitude == null ||
          restaurantLongitude == null) {
        continue;
      }

      // ==========================================
      // EXACT DISTANCE
      // ==========================================

      final distance = _calculateDistance(
        latitude,
        longitude,
        restaurantLatitude,
        restaurantLongitude,
      );

      // ==========================================
      // HARD DISTANCE FILTER
      // ==========================================

      if (distance > user.preferredDistance) {
        continue;
      }

      // ==========================================
      // CUISINE
      // ==========================================

      final cuisineResult =
          _calculateCuisineScore(
        cuisine,
        user.favoriteCuisines,
      );

      // ==========================================
      // DIET
      // ==========================================

      final dietScore = _calculateDietScore(
        cuisine,
        user.diet,
      );

      // ==========================================
      // BUDGET
      // ==========================================

      final budgetResult =
          _calculateBudgetScore(
        tags,
        user.budget,
      );

      // ==========================================
      // MOOD
      // ==========================================

      final moodScore = _calculateMoodScore(
        mood: mood,
        restaurantType: restaurantType,
        cuisine: cuisine,
      );

      // ==========================================
      // COMPANION
      // ==========================================

      final companionScore =
          _calculateCompanionScore(
        companion: user.companion,
        restaurantType: restaurantType,
      );

      // ==========================================
      // DISTANCE SCORE
      // ==========================================

      final distanceScore =
          _calculateDistanceScore(
        distance,
        user.preferredDistance.toDouble(),
      );

      // ==========================================
      // TOTAL SCORE
      // ==========================================

      final totalScore =
          distanceScore +
          cuisineResult.score +
          dietScore +
          budgetResult.score +
          moodScore +
          companionScore;

      // ==========================================
      // REASONS
      // ==========================================

      final reasons = <String>[];

      reasons.add(
        "${distance.toStringAsFixed(1)} km away",
      );

      if (cuisineResult.matchedCuisine != null) {
        reasons.add(
          "Matches your ${cuisineResult.matchedCuisine} preference",
        );
      }

      if (dietScore >= 12 &&
          user.diet != "No Preference") {
        reasons.add(
          "Fits your ${user.diet} preference",
        );
      }

      if (budgetResult.score >= 12) {
        reasons.add(
          "Fits your budget",
        );
      }

      if (moodScore >= 15) {
        reasons.add(
          "Good fit for your current mood",
        );
      }

      if (companionScore >= 7) {
        reasons.add(
          "Suitable for ${user.companion.toLowerCase()}",
        );
      }

      results.add(
        RecommendationResult(
          restaurant: restaurant,
          score: totalScore.clamp(0, 100),
          distance: distance,
          reasons: reasons,
        ),
      );
    }

    // Highest score first
    results.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    return results;
  }

  // =====================================================
  // DISTANCE SCORE - 20 POINTS
  // =====================================================

  static double _calculateDistanceScore(
    double distance,
    double preferredDistance,
  ) {
    if (preferredDistance <= 0) {
      return 0;
    }

    final ratio =
        distance / preferredDistance;

    if (ratio <= 0.10) {
      return 20;
    }

    if (ratio <= 0.25) {
      return 18;
    }

    if (ratio <= 0.50) {
      return 15;
    }

    if (ratio <= 0.75) {
      return 12;
    }

    return 8;
  }

  // =====================================================
  // CUISINE SCORE - 25 POINTS
  // =====================================================

  static _CuisineResult _calculateCuisineScore(
    String cuisine,
    List<String> preferredCuisines,
  ) {
    if (preferredCuisines.isEmpty) {
      return _CuisineResult(
        score: 12,
        matchedCuisine: null,
      );
    }

    final restaurantCuisines =
        cuisine
            .toLowerCase()
            .split(";")
            .map(
              (e) => e.trim().replaceAll("_", " "),
            )
            .where(
              (e) => e.isNotEmpty,
            )
            .toList();

    for (final preferred
        in preferredCuisines) {
      final preferredLower =
          preferred.toLowerCase().trim();

      for (final restaurantCuisine
          in restaurantCuisines) {
        if (_cuisineMatches(
          preferredLower,
          restaurantCuisine,
        )) {
          return _CuisineResult(
            score: 25,
            matchedCuisine: preferred,
          );
        }
      }
    }

    return _CuisineResult(
      score: 3,
      matchedCuisine: null,
    );
  }

  static bool _cuisineMatches(
    String preferred,
    String restaurant,
  ) {
    if (preferred == restaurant) {
      return true;
    }

    if (restaurant.contains(preferred)) {
      return true;
    }

    if (preferred.contains(restaurant)) {
      return true;
    }

    // Common OpenStreetMap variations
    final aliases = {
      "indian": [
        "north indian",
        "south indian",
        "indian cuisine",
      ],
      "chinese": [
        "chinese cuisine",
        "asian",
      ],
      "burger": [
        "burger",
        "burgers",
      ],
      "pizza": [
        "italian",
        "pizza",
      ],
      "cafe": [
        "coffee shop",
        "cafe",
      ],
      "dessert": [
        "ice cream",
        "cake",
        "desserts",
      ],
    };

    final possibleMatches =
        aliases[preferred] ?? [];

    return possibleMatches.contains(
      restaurant,
    );
  }

  // =====================================================
  // DIET SCORE - 15 POINTS
  // =====================================================

  static double _calculateDietScore(
    String cuisine,
    String diet,
  ) {
    if (diet == "No Preference") {
      return 8;
    }

    final food = cuisine.toLowerCase();

    if (diet == "Vegetarian") {
      if (food.contains("vegetarian") ||
          food.contains("vegan") ||
          food.contains("indian")) {
        return 15;
      }

      return 7;
    }

    if (diet == "Vegan") {
      if (food.contains("vegan") ||
          food.contains("vegetarian")) {
        return 15;
      }

      return 5;
    }

    if (diet == "Non-Veg") {
      if (food.contains("chicken") ||
          food.contains("meat") ||
          food.contains("kebab") ||
          food.contains("biryani") ||
          food.contains("seafood")) {
        return 15;
      }

      return 8;
    }

    return 8;
  }

  // =====================================================
  // BUDGET SCORE - 15 POINTS
  // =====================================================

  static _BudgetResult _calculateBudgetScore(
    Map<String, dynamic> tags,
    int userBudget,
  ) {
    /*
      OpenStreetMap does not consistently provide
      restaurant prices.

      Therefore we first look for available price
      information. If there is none, we give a
      neutral score rather than inventing a price.
    */

    final priceLevel =
        tags["price_range"] ??
        tags["price"] ??
        tags["price_level"];

    if (priceLevel == null) {
      return _BudgetResult(
        score: 8,
      );
    }

    final value =
        double.tryParse(
      priceLevel.toString(),
    );

    if (value == null) {
      return _BudgetResult(
        score: 8,
      );
    }

    // Generic price-level interpretation.
    // We avoid pretending this is an exact ₹ amount.
    final normalizedBudget =
        userBudget <= 500
            ? 1
            : userBudget <= 1000
                ? 2
                : userBudget <= 2000
                    ? 3
                    : 4;

    final difference =
        (value - normalizedBudget).abs();

    if (difference == 0) {
      return _BudgetResult(
        score: 15,
      );
    }

    if (difference == 1) {
      return _BudgetResult(
        score: 10,
      );
    }

    return _BudgetResult(
      score: 5,
    );
  }

  // =====================================================
  // MOOD SCORE - 15 POINTS
  // =====================================================

  static double _calculateMoodScore({
    required String mood,
    required String restaurantType,
    required String cuisine,
  }) {
    final lowerMood =
        mood.toLowerCase();

    final type =
        restaurantType.toLowerCase();

    final food =
        cuisine.toLowerCase();

    if (lowerMood.contains("happy")) {
      if (type.contains("restaurant") ||
          type.contains("cafe")) {
        return 15;
      }

      return 9;
    }

    if (lowerMood.contains("stressed")) {
      if (type.contains("cafe")) {
        return 15;
      }

      if (type.contains("restaurant")) {
        return 13;
      }

      return 8;
    }

    if (lowerMood.contains("tired")) {
      if (type.contains("cafe")) {
        return 15;
      }

      if (type.contains("restaurant")) {
        return 12;
      }

      return 8;
    }

    if (lowerMood.contains("study")) {
      if (type.contains("cafe")) {
        return 15;
      }

      return 7;
    }

    if (lowerMood.contains("workout")) {
      if (food.contains("salad") ||
          food.contains("healthy") ||
          food.contains("vegetarian") ||
          food.contains("vegan")) {
        return 15;
      }

      return 6;
    }

    if (lowerMood.contains("romantic")) {
      if (type.contains("restaurant")) {
        return 15;
      }

      if (type.contains("cafe")) {
        return 12;
      }

      return 6;
    }

    return 8;
  }

  // =====================================================
  // COMPANION SCORE - 10 POINTS
  // =====================================================

  static double _calculateCompanionScore({
    required String companion,
    required String restaurantType,
  }) {
    final person =
        companion.toLowerCase();

    final type =
        restaurantType.toLowerCase();

    if (person == "alone") {
      if (type.contains("cafe") ||
          type.contains("fast_food")) {
        return 10;
      }

      return 7;
    }

    if (person == "friends") {
      if (type.contains("restaurant") ||
          type.contains("fast_food")) {
        return 10;
      }

      return 7;
    }

    if (person == "family") {
      if (type.contains("restaurant")) {
        return 10;
      }

      return 7;
    }

    if (person == "partner") {
      if (type.contains("restaurant") ||
          type.contains("cafe")) {
        return 10;
      }

      return 7;
    }

    return 7;
  }

  // =====================================================
  // HAVERSINE DISTANCE
  // =====================================================

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;

    final dLat =
        (lat2 - lat1) * pi / 180;

    final dLon =
        (lon2 - lon1) * pi / 180;

    final a =
        sin(dLat / 2) *
            sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c =
        2 *
            atan2(
              sqrt(a),
              sqrt(1 - a),
            );

    return earthRadius * c;
  }
}

// =====================================================
// CUISINE RESULT
// =====================================================

class _CuisineResult {
  final double score;
  final String? matchedCuisine;

  _CuisineResult({
    required this.score,
    required this.matchedCuisine,
  });
}

// =====================================================
// BUDGET RESULT
// =====================================================

class _BudgetResult {
  final double score;

  _BudgetResult({
    required this.score,
  });
}