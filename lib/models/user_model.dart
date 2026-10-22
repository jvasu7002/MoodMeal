import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;

  // Budget
  final int budget;
  final String budgetType;

  final List<String> favoriteCuisines;

  final String diet;

  final int preferredDistance;

  final String companion;

  final List<String> favoriteRestaurants;

  final List<String> recommendationHistory;

  final bool completedSetup;

  final Timestamp createdAt;
  final int numberOfPeople;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.budget,
    required this.budgetType,
    required this.favoriteCuisines,
    required this.diet,
    required this.preferredDistance,
    required this.companion,
    required this.favoriteRestaurants,
    required this.recommendationHistory,
    required this.completedSetup,
    required this.createdAt,
    required this.numberOfPeople,
  });

  // =====================================================
  // FIRESTORE → USER MODEL
  // =====================================================

factory UserModel.fromMap(
  Map<String, dynamic> map,
) {
  return UserModel(
    uid: map['uid'] ?? '',
    name: map['name'] ?? '',
    email: map['email'] ?? '',

    budget: (map['budget'] ?? 500).toInt(),

    budgetType:
        map['budgetType'] ??
        'Per Person / Per Meal',

    numberOfPeople:
        (map['numberOfPeople'] ?? 1).toInt(),

    favoriteCuisines:
        List<String>.from(
      map['favoriteCuisines'] ?? [],
    ),

    diet:
        map['diet'] ??
        'No Preference',

    preferredDistance:
        (map['preferredDistance'] ?? 5).toInt(),

    companion:
        map['companion'] ??
        'Alone',

    favoriteRestaurants:
        List<String>.from(
      map['favoriteRestaurants'] ?? [],
    ),

    recommendationHistory:
        List<String>.from(
      map['recommendationHistory'] ?? [],
    ),

    completedSetup:
        map['completedSetup'] ?? false,

    createdAt:
        map['createdAt'] ??
        Timestamp.now(),
  );
}

  // =====================================================
  // USER MODEL → FIRESTORE
  // =====================================================

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,

      'budget': budget,
      'budgetType': budgetType,

      'favoriteCuisines': favoriteCuisines,

      'diet': diet,

      'preferredDistance':
          preferredDistance,

      'companion': companion,

      'favoriteRestaurants':
          favoriteRestaurants,

      'recommendationHistory':
          recommendationHistory,

      'completedSetup':
          completedSetup,

      'createdAt':
          createdAt,
      'numberOfPeople': numberOfPeople,
    };
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,

    int? budget,
    String? budgetType,

    List<String>? favoriteCuisines,

    String? diet,

    int? preferredDistance,

    String? companion,

    List<String>? favoriteRestaurants,

    List<String>? recommendationHistory,

    bool? completedSetup,

    Timestamp? createdAt,
    int? numberOfPeople,
  }) {
    return UserModel(
      uid:
          uid ?? this.uid,

      name:
          name ?? this.name,

      email:
          email ?? this.email,

      budget:
          budget ?? this.budget,

      budgetType:
          budgetType ?? this.budgetType,

      favoriteCuisines:
          favoriteCuisines ??
          this.favoriteCuisines,

      diet:
          diet ?? this.diet,

      preferredDistance:
          preferredDistance ??
          this.preferredDistance,

      companion:
          companion ?? this.companion,

      favoriteRestaurants:
          favoriteRestaurants ??
          this.favoriteRestaurants,

      recommendationHistory:
          recommendationHistory ??
          this.recommendationHistory,

      completedSetup:
          completedSetup ??
          this.completedSetup,

      createdAt:
          createdAt ?? this.createdAt,
      numberOfPeople:
          numberOfPeople ?? this.numberOfPeople,    
    );
  }
}