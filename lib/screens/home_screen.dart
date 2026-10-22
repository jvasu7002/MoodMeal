import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:moodmeal/services/api_service.dart';
import 'package:moodmeal/services/favorite_service.dart';
import 'package:moodmeal/services/firestore_service.dart';
import 'package:moodmeal/services/location_service.dart';
import 'package:moodmeal/services/openrouter_service.dart';
import 'package:moodmeal/services/recommendation_engine.dart';
import 'package:moodmeal/services/restaurant_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import 'restaurant_detail_screen.dart';


// =============================================================
// HOME SCREEN
// =============================================================

class HomeScreen extends StatefulWidget {
  final VoidCallback? onAskMoodMeal;

  const HomeScreen({super.key, this.onAskMoodMeal});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _assistantAnimationController;
  final FlutterTts _assistantTts = FlutterTts();

  Future<void> _openMoodMealAssistant() async {
    try {
      await _assistantTts.stop();
      await _assistantTts.setLanguage('en-IN');
      await _assistantTts.setSpeechRate(0.45);
      await _assistantTts.awaitSpeakCompletion(true);
      await _assistantTts.speak('Hello, I am MoodMeal. How can I help you?');
    } catch (e) {
      debugPrint('MoodMeal greeting error: $e');
    }
    if (!mounted) return;
    widget.onAskMoodMeal?.call();
  }

  // ===========================================================
  // VARIABLES
  // ===========================================================

  double currentLatitude = 0;
  double currentLongitude = 0;

  double referenceLatitude = 0;
  double referenceLongitude = 0;

  double activeLatitude = 0;
  double activeLongitude = 0;

  List<dynamic> nearbyRestaurants = [];

  List<RecommendationResult> recommendedRestaurants = [];

  bool isRefreshingRecommendations = false;

  String selectedMood = "😔 Stressed";

  String currentLocation = "Current Location";

  int selectedRadius = 10000;

  final TextEditingController cityController =
      TextEditingController();

  String aiRecommendation =
      "Loading recommendations...";

  bool isLoading = false;

  String searchText = "";


  // ===========================================================
  // MOOD MESSAGES
  // ===========================================================

  final Map<String, String> moodMessage = {

    "😊 Happy":
        "Enjoy your favorite treats today!",

    "😔 Stressed":
        "Get comfort food delivered in 20 mins",

    "😴 Tired":
        "Recharge with coffee and snacks",

    "📚 Study":
        "Brain food for better focus",

    "💪 Workout":
        "High protein meals recommended",

    "❤️ Romantic":
        "Perfect meals for a date night",
  };


  // ===========================================================
  // INIT
  // ===========================================================

  @override
  void initState() {
    super.initState();
    _assistantAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    getRecommendation();

    testLocation();

    initializeHome();
  }


  // ===========================================================
  // DISPOSE
  // ===========================================================

  @override
  void dispose() {
    _assistantAnimationController.dispose();
    _assistantTts.stop();
    cityController.dispose();
    super.dispose();
  }


  // ===========================================================
  // LOCATION TEST
  // ===========================================================

  Future<void> testLocation() async {

    debugPrint("TEST LOCATION CALLED");

    try {

      final position =
          await LocationService.getCurrentLocation();

      debugPrint(
        "Latitude: ${position.latitude}",
      );

      debugPrint(
        "Longitude: ${position.longitude}",
      );

    } catch (e) {

      debugPrint(
        "LOCATION ERROR: $e",
      );
    }
  }


  // ===========================================================
  // LOAD NEARBY RESTAURANTS
  // ===========================================================

  Future<void> loadNearbyRestaurants() async {

    try {

      debugPrint(
        "Loading nearby restaurants...",
      );

      final position =
          await LocationService.getCurrentLocation();

      debugPrint(
        "Current Latitude: ${position.latitude}",
      );

      debugPrint(
        "Current Longitude: ${position.longitude}",
      );


      currentLatitude =
          position.latitude;

      currentLongitude =
          position.longitude;

      activeLatitude =
          position.latitude;

      activeLongitude =
          position.longitude;

      referenceLatitude =
          position.latitude;

      referenceLongitude =
          position.longitude;


      final restaurants =
          await RestaurantService.getNearbyRestaurants(
        position.latitude,
        position.longitude,
        selectedRadius,
      );


      // -------------------------------------------------------
      // SORT BY DISTANCE
      // -------------------------------------------------------

      restaurants.sort((a, b) {

        final latA =
            a["lat"] ??
            a["center"]?["lat"];

        final lonA =
            a["lon"] ??
            a["center"]?["lon"];

        final latB =
            b["lat"] ??
            b["center"]?["lat"];

        final lonB =
            b["lon"] ??
            b["center"]?["lon"];


        if (latA == null ||
            lonA == null) {
          return 1;
        }

        if (latB == null ||
            lonB == null) {
          return -1;
        }


        final distA =
            calculateDistance(
          referenceLatitude,
          referenceLongitude,
          latA.toDouble(),
          lonA.toDouble(),
        );


        final distB =
            calculateDistance(
          referenceLatitude,
          referenceLongitude,
          latB.toDouble(),
          lonB.toDouble(),
        );


        return distA.compareTo(distB);
      });


      debugPrint(
        "Restaurants received: ${restaurants.length}",
      );


      if (!mounted) return;


      setState(() {

        nearbyRestaurants =
            restaurants;
      });


      await generateRecommendations();


      debugPrint(
        "Loaded: ${nearbyRestaurants.length}",
      );

    } catch (e) {

      if (!mounted) return;


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "📍 Please turn on your device location.",
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );


      debugPrint(
        "Location loading error: $e",
      );
    }
  }


  // ===========================================================
  // SEARCH CITY
  // ===========================================================

  Future<void> searchCityRestaurants() async {

    try {

      if (cityController.text
          .trim()
          .isEmpty) {
        return;
      }


      final coords =
          await RestaurantService
              .getCoordinatesFromCity(
        cityController.text.trim(),
      );


      activeLatitude =
          coords["lat"]!;

      activeLongitude =
          coords["lon"]!;


      referenceLatitude =
          coords["lat"]!;

      referenceLongitude =
          coords["lon"]!;


      final restaurants =
          await RestaurantService.getNearbyRestaurants(
        coords["lat"]!,
        coords["lon"]!,
        selectedRadius,
      );


      // -------------------------------------------------------
      // SORT BY DISTANCE
      // -------------------------------------------------------

      restaurants.sort((a, b) {

        final latA =
            a["lat"] ??
            a["center"]?["lat"];

        final lonA =
            a["lon"] ??
            a["center"]?["lon"];

        final latB =
            b["lat"] ??
            b["center"]?["lat"];

        final lonB =
            b["lon"] ??
            b["center"]?["lon"];


        if (latA == null ||
            lonA == null) {
          return 1;
        }

        if (latB == null ||
            lonB == null) {
          return -1;
        }


        final distA =
            calculateDistance(
          referenceLatitude,
          referenceLongitude,
          latA.toDouble(),
          lonA.toDouble(),
        );


        final distB =
            calculateDistance(
          referenceLatitude,
          referenceLongitude,
          latB.toDouble(),
          lonB.toDouble(),
        );


        return distA.compareTo(distB);
      });


      if (!mounted) return;


      setState(() {

        nearbyRestaurants =
            restaurants;

        currentLocation =
            cityController.text.trim();
      });


      await generateRecommendations();


      debugPrint(
        "Restaurants Found: ${restaurants.length}",
      );

    } catch (e) {

      debugPrint(
        "CITY SEARCH ERROR: $e",
      );


      if (!mounted) return;


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }


  // ===========================================================
  // LOAD LOCATION NAME
  // ===========================================================

  Future<void> loadLocationName() async {

    try {

      final position =
          await LocationService.getCurrentLocation();


      final placemarks =
          await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );


      if (placemarks.isNotEmpty) {

        final place =
            placemarks.first;


        if (!mounted) return;


        final locality =
            place.locality ?? "";

        final state =
            place.administrativeArea ?? "";


        setState(() {

          currentLocation =
              "$locality, $state";

          cityController.text =
              currentLocation;
        });
      }

    } catch (e) {

      if (!mounted) return;


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "📍 Please turn on your device location.",
          ),
          backgroundColor: Colors.red,
        ),
      );


      debugPrint(
        "Location Error: $e",
      );
    }
  }


  // ===========================================================
  // THEME
  // ===========================================================

  Future<void> toggleTheme() async {

    final prefs =
        await SharedPreferences.getInstance();


    if (themeNotifier.value ==
        ThemeMode.light) {

      themeNotifier.value =
          ThemeMode.dark;

      await prefs.setBool(
        "darkMode",
        true,
      );

    } else {

      themeNotifier.value =
          ThemeMode.light;

      await prefs.setBool(
        "darkMode",
        false,
      );
    }
  }


  // ===========================================================
  // INITIALIZE HOME
  // ===========================================================

  Future<void> initializeHome() async {

    await loadLocationName();

    await loadNearbyRestaurants();
  }


  // ===========================================================
  // BACKEND RESTAURANT RECOMMENDATIONS
  // ===========================================================

  Future<void> generateRecommendations() async {

    if (isRefreshingRecommendations) {
      return;
    }

    if (!mounted) return;


    setState(() {

      isRefreshingRecommendations =
          true;
    });


    try {

      final firestoreService =
          FirestoreService();


      final user =
          await firestoreService
              .getUserProfile();


      if (user == null) {

        debugPrint(
          "❌ User profile not found",
        );

        return;
      }


      debugPrint(
        "===== REFRESH START =====",
      );


      debugPrint(
        "Cuisine: ${user.favoriteCuisines}",
      );

      debugPrint(
        "Diet: ${user.diet}",
      );

      debugPrint(
        "Budget: ${user.budget}",
      );

      debugPrint(
        "Distance: ${user.preferredDistance}",
      );

      debugPrint(
        "Companion: ${user.companion}",
      );

      debugPrint(
        "Mood: $selectedMood",
      );


      if (nearbyRestaurants.isEmpty) {

        debugPrint(
          "⚠️ No restaurants available",
        );

        return;
      }


      final lat =
          activeLatitude != 0
              ? activeLatitude
              : currentLatitude;


      final lon =
          activeLongitude != 0
              ? activeLongitude
              : currentLongitude;


      debugPrint(
        "Recommendation Location: $lat, $lon",
      );


      final recommendations =
          await ApiService.getRecommendations(

        latitude: lat,

        longitude: lon,

        mood: selectedMood,

        preferredDistance:
            user.preferredDistance
                .toDouble(),

        favoriteCuisines:
            user.favoriteCuisines,
      );


      debugPrint(
        "Backend recommendations received: "
        "${recommendations.length}",
      );


      if (!mounted) return;


      setState(() {

        recommendedRestaurants =
            recommendations
                .map(
                  (item) =>
                      RecommendationResult
                          .fromJson(item),
                )
                .toList();
      });


      debugPrint(
        "===== REFRESH COMPLETE =====",
      );

    } catch (e) {

      debugPrint(
        "❌ Recommendation refresh error: $e",
      );


      if (!mounted) return;


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't refresh recommendations.",
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {

          isRefreshingRecommendations =
              false;
        });
      }
    }
  }


  // ===========================================================
  // OLD MOOD AI RECOMMENDATION
  // ===========================================================

  Future<void> getRecommendation() async {

    if (!mounted) return;


    setState(() {

      isLoading = true;
    });


    try {

      final result =
          await OpenRouterService
              .getFoodRecommendation(
        selectedMood,
      );


      if (!mounted) return;


      setState(() {

        aiRecommendation =
            result;

        isLoading = false;
      });

    } catch (e) {

      if (!mounted) return;


      setState(() {

        aiRecommendation =
            "Unable to load recommendation.";

        isLoading = false;
      });


      debugPrint(
        "AI recommendation error: $e",
      );
    }
  }


  // ===========================================================
  // GOOGLE MAPS
  // ===========================================================

  

Future<void> openGoogleMaps(double lat, double lon) async {
  final Uri webUri = Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query': '$lat,$lon',
    },
  );

  debugPrint('MAPS BUTTON TAPPED');
  debugPrint('MAPS URL: $webUri');

  try {
    final bool opened = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );

    debugPrint('MAPS LAUNCH RESULT: $opened');

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Maps. Check internet connection.'),
        ),
      );
    }
  } catch (e, stackTrace) {
    debugPrint('MAPS LAUNCH ERROR: $e');
    debugPrint('$stackTrace');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maps error: $e')),
      );
    }
  }
}




  // ===========================================================
  // DISTANCE CALCULATOR
  // ===========================================================

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {

    const double radius =
        6371;


    final double dLat =
        (lat2 - lat1) *
        pi /
        180;


    final double dLon =
        (lon2 - lon1) *
        pi /
        180;


    final double a =
        sin(dLat / 2) *
            sin(dLat / 2) +

        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *

        sin(dLon / 2) *
            sin(dLon / 2);


    final double c =
        2 *
        atan2(
          sqrt(a),
          sqrt(1 - a),
        );


    return radius * c;
  }


  // ===========================================================
  // HOME UI
  // ===========================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,


      body: SafeArea(

        child: SingleChildScrollView(

          padding:
              const EdgeInsets.all(16),


          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,


            children: [

              // =================================================
              // LOCATION HEADER
              // =================================================

              Row(
                children: [

                  const Icon(
                    Icons.location_on,
                    color: Colors.orange,
                  ),

                  const SizedBox(
                    width: 5,
                  ),

                  Expanded(
                    child: Text(
                      currentLocation,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed:
                        toggleTheme,

                    icon: Icon(
                      themeNotifier.value ==
                              ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,

                      color:
                          Colors.orange,
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 12),

              // Animated Ask MoodMeal assistant card
              AnimatedBuilder(
                animation: _assistantAnimationController,
                builder: (context, child) {
                  final t = _assistantAnimationController.value;
                  return Transform.translate(
                    offset: Offset(0, -4 * t),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA726), Color(0xFFFF7A00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.20 + 0.18 * t),
                            blurRadius: 12 + 8 * t,
                            spreadRadius: 1 + t,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _openMoodMealAssistant,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 29,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ask MoodMeal',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tap to talk about food, mood, or cravings',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.graphic_eq, color: Colors.white, size: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // =================================================
              // RESTAURANT SEARCH
              // =================================================

              TextField(

                onChanged: (value) {

                  setState(() {

                    searchText =
                        value.toLowerCase();
                  });
                },


                decoration:
                    InputDecoration(

                  hintText:
                      "Search restaurant...",

                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),

                  filled: true,

                  fillColor:
                      Theme.of(context)
                          .colorScheme
                          .surface,

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),


              const SizedBox(
                height: 25,
              ),


              // =================================================
              // MOOD BANNER
              // =================================================

              Container(

                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(20),

                decoration:
                    BoxDecoration(

                  color:
                      Colors.orange,

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),


                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,


                  children: [

                    Text(

                      "Feeling "
                      "$selectedMood?",

                      style:
                          const TextStyle(

                        color:
                            Colors.white,

                        fontSize: 24,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),


                    const SizedBox(
                      height: 8,
                    ),


                    Text(

                      moodMessage[
                              selectedMood] ??
                          "",

                      style:
                          const TextStyle(

                        color:
                            Colors.white,

                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),


              const SizedBox(
                height: 20,
              ),


              // =================================================
              // AI RECOMMENDATIONS
              // =================================================

              const Text(

                "🤖 AI Recommendations",

                style:
                    TextStyle(

                  fontSize: 22,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),


              const SizedBox(
                height: 10,
              ),


              Card(

                child: Padding(

                  padding:
                      const EdgeInsets.all(
                    16,
                  ),


                  child:
                      isLoading

                          ? const Center(
                              child:
                                  CircularProgressIndicator(),
                            )

                          : Text(

                              aiRecommendation,

                              style:
                                  const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                ),
              ),


              const SizedBox(
                height: 25,
              ),


              // =================================================
              // RESTAURANTS FOUND
              // =================================================

              Text(

                "Restaurants Found: "
                "${nearbyRestaurants.length}",

                style:
                    const TextStyle(

                  fontSize: 16,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),


              const SizedBox(
                height: 20,
              ),


              // =================================================
              // SEARCH LOCATION
              // =================================================

              const Text(

                "📍 Search Location",

                style:
                    TextStyle(

                  fontSize: 20,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),


              const SizedBox(
                height: 10,
              ),


              TextField(

                controller:
                    cityController,

                decoration:
                    InputDecoration(

                  hintText:
                      "Enter City, District, Town or Area",

                  prefixIcon:
                      const Icon(
                    Icons.location_city,
                  ),

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),


              const SizedBox(
                height: 6,
              ),


              const Text(

                "Examples: Delhi • Shahdara • "
                "Krishna Nagar • Preet Vihar • Jaipur",

                style:
                    TextStyle(

                  color:
                      Colors.grey,

                  fontSize: 12,
                ),
              ),


              const SizedBox(
                height: 15,
              ),


              // =================================================
              // SEARCH RADIUS
              // =================================================

              const Text(

                "Search Radius",

                style:
                    TextStyle(

                  fontWeight:
                      FontWeight.bold,

                  fontSize: 16,
                ),
              ),


              Wrap(

                spacing: 10,

                children: [

                  ChoiceChip(

                    label:
                        const Text(
                      "5 km",
                    ),

                    selected:
                        selectedRadius ==
                            5000,

                    onSelected: (_) {

                      setState(() {

                        selectedRadius =
                            5000;
                      });
                    },
                  ),


                  ChoiceChip(

                    label:
                        const Text(
                      "10 km",
                    ),

                    selected:
                        selectedRadius ==
                            10000,

                    onSelected: (_) {

                      setState(() {

                        selectedRadius =
                            10000;
                      });
                    },
                  ),


                  ChoiceChip(

                    label:
                        const Text(
                      "20 km",
                    ),

                    selected:
                        selectedRadius ==
                            20000,

                    onSelected: (_) {

                      setState(() {

                        selectedRadius =
                            20000;
                      });
                    },
                  ),


                  ChoiceChip(

                    label:
                        const Text(
                      "50 km",
                    ),

                    selected:
                        selectedRadius ==
                            50000,

                    onSelected: (_) {

                      setState(() {

                        selectedRadius =
                            50000;
                      });
                    },
                  ),
                ],
              ),


              const SizedBox(
                height: 15,
              ),


              // =================================================
              // FIND RESTAURANTS
              // =================================================

              SizedBox(

                width:
                    double.infinity,

                child:
                    ElevatedButton.icon(

                  onPressed:
                      searchCityRestaurants,

                  icon:
                      const Icon(
                    Icons.search,
                  ),

                  label:
                      const Text(
                    "Find Restaurants",
                  ),

                  style:
                      ElevatedButton.styleFrom(

                    backgroundColor:
                        Colors.orange,

                    foregroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                    ),

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),


              const SizedBox(
                height: 25,
              ),


              // =================================================
              // CHOOSE MOOD
              // =================================================

              Text(

                "Choose Your Mood",

                style:
                    TextStyle(

                  fontSize: 18,

                  fontWeight:
                      FontWeight.bold,

                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSurface,
                ),
              ),


              const SizedBox(
                height: 15,
              ),


              Wrap(

                spacing: 10,

                runSpacing: 10,

                children: [

                  "😊 Happy",
                  "😔 Stressed",
                  "😴 Tired",
                  "📚 Study",
                  "💪 Workout",
                  "❤️ Romantic",

                ].map((mood) {

                  return ChoiceChip(

                    label:
                        Text(mood),

                    selected:
                        selectedMood ==
                            mood,

                    onSelected:
                        (_) async {

                      setState(() {

                        selectedMood =
                            mood;
                      });


                      await getRecommendation();

                      await generateRecommendations();
                    },
                  );

                }).toList(),
              ),


              const SizedBox(
                height: 30,
              ),


              // =================================================
              // BEST MATCHES
              // =================================================

              Row(

                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                children: [

                  const Text(

                    "✨ Best Matches For You",

                    style:
                        TextStyle(

                      fontSize: 22,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),


                  IconButton(

                    tooltip:
                        "Refresh recommendations",

                    onPressed:
                        isRefreshingRecommendations
                            ? null
                            : generateRecommendations,

                    icon:
                        isRefreshingRecommendations

                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )

                            : const Icon(
                                Icons.refresh,
                              ),
                  ),
                ],
              ),


              const SizedBox(
                height: 15,
              ),


              // =================================================
              // RECOMMENDED RESTAURANTS
              // =================================================

              ...recommendedRestaurants
                  .take(3)
                  .map((result) {

                final restaurant =
                    result.restaurant;


                final tags =
                    restaurant["tags"] ??
                        {};


                final name =
                    tags["name"] ??
                        tags["brand"] ??
                        "Restaurant";


                final cuisine =
                    tags["cuisine"] ??
                        tags["amenity"] ??
                        "Food Place";


                final latitude =
                    restaurant["lat"] ??
                        restaurant[
                            "center"]?[
                          "lat"];


                final longitude =
                    restaurant["lon"] ??
                        restaurant[
                            "center"]?[
                          "lon"];


                return Card(

                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),


                  child:
                      ListTile(

                    leading:
                        const CircleAvatar(

                      backgroundColor:
                          Colors.orange,

                      child:
                          Icon(

                        Icons.restaurant,

                        color:
                            Colors.white,
                      ),
                    ),


                    title:
                        Text(

                      name,

                      style:
                          const TextStyle(

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),


                    subtitle:
                        Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        const SizedBox(
                          height: 5,
                        ),


                        Text(
                          cuisine,
                        ),


                        const SizedBox(
                          height: 5,
                        ),


                        Text(

                          "📍 "
                          "${result.distance.toStringAsFixed(1)} "
                          "km away",
                        ),


                        const SizedBox(
                          height: 5,
                        ),


                        Text(

                          "🎯 "
                          "${result.score.toStringAsFixed(0)}% Match",

                          style:
                              const TextStyle(

                            fontWeight:
                                FontWeight.bold,

                            color:
                                Colors.orange,
                          ),
                        ),


                        const SizedBox(
                          height: 5,
                        ),


                        Text(

                          result.reasons
                              .join(
                            " • ",
                          ),

                          style:
                              const TextStyle(

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),


                    onTap: () {

                      if (latitude ==
                              null ||
                          longitude ==
                              null) {

                        return;
                      }


                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              RestaurantDetailScreen(

                            name:
                                name,

                            cuisine:
                                cuisine.toString(),

                            city:
                                currentLocation,

                            distance:
                                result.distance,

                            latitude:
                                latitude.toDouble(),

                            longitude:
                                longitude.toDouble(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),


              // =================================================
              // POPULAR RESTAURANTS
              // =================================================

              const Text(

                "Popular Restaurants",

                style:
                    TextStyle(

                  fontSize: 22,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),


              const SizedBox(
                height: 15,
              ),


              ...nearbyRestaurants
                  .where((restaurant) {

                final tags =
                    restaurant["tags"] ??
                        {};


                final name =
                    tags["name"] ??
                        tags["brand"] ??
                        "Restaurant";


                if (searchText
                    .trim()
                    .isEmpty) {

                  return true;
                }


                return name
                    .toString()
                    .toLowerCase()
                    .contains(
                      searchText,
                    );

              })
                  .take(20)
                  .map((restaurant) {

                final tags =
                    restaurant["tags"] ??
                        {};


                final restaurantName =
                    tags["name"] ??
                        tags["brand"] ??
                        "Restaurant";


                final cuisine =
                    tags["cuisine"] ??
                        tags["amenity"] ??
                        "Food Place";


                final latitude =
                    restaurant["lat"] ??
                        restaurant[
                            "center"]?[
                          "lat"];


                final longitude =
                    restaurant["lon"] ??
                        restaurant[
                            "center"]?[
                          "lon"];


                final distance =
                    latitude != null &&
                            longitude != null

                        ? calculateDistance(

                            activeLatitude,

                            activeLongitude,

                            latitude.toDouble(),

                            longitude.toDouble(),
                          )

                        : 0.0;


                return Card(

                  margin:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),


                  child:
                      ListTile(

                    leading:
                        const CircleAvatar(

                      backgroundColor:
                          Colors.orange,

                      child:
                          Icon(

                        Icons.restaurant,

                        color:
                            Colors.white,
                      ),
                    ),


                    title:
                        Text(
                      restaurantName,
                    ),


                    subtitle:
                        Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        Row(

                          children: [

                            Icon(

                              cuisine ==
                                      "cafe"

                                  ? Icons.coffee

                                  : cuisine ==
                                          "fast_food"

                                      ? Icons.fastfood

                                      : Icons.restaurant,

                              size: 16,

                              color:
                                  Colors.orange,
                            ),


                            const SizedBox(
                              width: 5,
                            ),


                            Expanded(

                              child:
                                  Text(
                                cuisine,
                              ),
                            ),
                          ],
                        ),


                        const SizedBox(
                          height: 4,
                        ),


                        Text(

                          "📍 "
                          "${distance.toStringAsFixed(1)} "
                          "km away",

                          style:
                              const TextStyle(

                            color:
                                Colors.grey,

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),


                    trailing:
                        FutureBuilder<bool>(

                      future:
                          FavoriteService
                              .isFavorite(
                        restaurantName,
                      ),


                      builder:
                          (
                        context,
                        snapshot,
                      ) {

                        final isFavorite =
                            snapshot.data ??
                                false;


                        return IconButton(

                          icon:
                              Icon(

                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,

                            color:
                                Colors.red,
                          ),


                          onPressed:
                              () async {

                            try {

                              if (isFavorite) {

                                await FavoriteService
                                    .removeFavorite(
                                  restaurantName,
                                );

                              } else {

                                if (latitude ==
                                        null ||
                                    longitude ==
                                        null) {

                                  return;
                                }


                                await FavoriteService
                                    .saveFavorite(

                                  name:
                                      restaurantName,

                                  cuisine:
                                      cuisine.toString(),

                                  latitude:
                                      latitude.toDouble(),

                                  longitude:
                                      longitude.toDouble(),

                                  city:
                                      currentLocation,

                                  distance:
                                      distance,
                                );
                              }


                              if (!mounted)
                                return;


                              setState(
                                () {},
                              );

                            } catch (e) {

                              if (!mounted)
                                return;


                              ScaffoldMessenger
                                  .of(context)
                                  .showSnackBar(

                                SnackBar(

                                  content:
                                      Text(
                                    e.toString(),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),


                    onTap: () {

                      if (latitude ==
                              null ||
                          longitude ==
                              null) {

                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(

                          const SnackBar(

                            content: Text(
                              "Location not available "
                              "for this restaurant.",
                            ),
                          ),
                        );

                        return;
                      }


                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              RestaurantDetailScreen(

                            name:
                                restaurantName,

                            cuisine:
                                cuisine.toString(),

                            city:
                                currentLocation,

                            distance:
                                distance,

                            latitude:
                                latitude.toDouble(),

                            longitude:
                                longitude.toDouble(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),


              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// =============================================================
// ASK MOODMEAL SCREEN
// =============================================================

class AskMoodMealScreen extends StatefulWidget {

  // IMPORTANT:
  // selectedMood is now optional.
  //
  // This allows:
  //
  // const AskMoodMealScreen()
  //
  // from MainScreen.

  final String selectedMood;


  const AskMoodMealScreen({

    super.key,

    this.selectedMood =
        "😔 Stressed",
  });


  @override
  State<AskMoodMealScreen> createState() =>
      _AskMoodMealScreenState();
}



// =============================================================
// ASK MOODMEAL STATE
// =============================================================

class _AskMoodMealScreenState
    extends State<AskMoodMealScreen> {

  final TextEditingController
      messageController =
      TextEditingController();


  final ScrollController
      scrollController =
      ScrollController();


  final List<_ChatMessage>
      messages = [];


  bool isLoading = false;


  dynamic userProfile;


  // ===========================================================
  // INIT
  // ===========================================================

  @override
  void initState() {

    super.initState();


    _loadProfile();


    messages.add(

      const _ChatMessage(

        text:
            "Hi! 👋 I'm MoodMeal.\n\n"
            "Tell me what you're feeling, "
            "what you'd like to eat, your budget, "
            "or anything you're craving.",

        isUser:
            false,
      ),
    );
  }


  // ===========================================================
  // DISPOSE
  // ===========================================================

  @override
  void dispose() {

    messageController.dispose();

    scrollController.dispose();

    super.dispose();
  }


  // ===========================================================
  // LOAD PROFILE
  // ===========================================================

  Future<void> _loadProfile() async {

    try {

      final profile =
          await FirestoreService()
              .getUserProfile();


      if (!mounted) return;


      setState(() {

        userProfile =
            profile;
      });

    } catch (e) {

      debugPrint(
        "Profile loading error: $e",
      );
    }
  }


  // ===========================================================
  // SEND MESSAGE
  // ===========================================================

  Future<void> sendMessage() async {

    final query =
        messageController
            .text
            .trim();


    if (query.isEmpty ||
        isLoading) {

      return;
    }


    messageController.clear();


    setState(() {

      messages.add(

        _ChatMessage(

          text:
              query,

          isUser:
              true,
        ),
      );


      isLoading =
          true;
    });


    _scrollToBottom();


    try {

      // -------------------------------------------------------
      // MAKE SURE PROFILE EXISTS
      // -------------------------------------------------------

      if (userProfile == null) {

        userProfile =
            await FirestoreService()
                .getUserProfile();
      }


      final profile =
          userProfile;


      // -------------------------------------------------------
      // PROFILE VALUES
      // -------------------------------------------------------

      final String diet =
          profile?.diet
                  ?.toString() ??
              "Any";


      final String cuisine =
          profile?.favoriteCuisines
                  ?.join(", ") ??
              "Any";


      final double budget =
          profile?.budget
                  ?.toDouble() ??
              200;


      // -------------------------------------------------------
      // MOOD
      // -------------------------------------------------------

      final String mood =
          widget.selectedMood
              .replaceFirst(
                RegExp(
                  r'^[^\s]+\s',
                ),
                '',
              )
              .toLowerCase();


      debugPrint(
        "===== RAG REQUEST =====",
      );

      debugPrint(
        "User Query: $query",
      );

      debugPrint(
        "Mood: $mood",
      );

      debugPrint(
        "Diet: ${diet.toLowerCase()}",
      );

      debugPrint(
        "Cuisine: ${cuisine.toLowerCase()}",
      );

      debugPrint(
        "Profile Budget: $budget",
      );

      debugPrint(
        "=======================",
      );


      // -------------------------------------------------------
      // CALL BACKEND
      // -------------------------------------------------------

      final response =
          await ApiService
              .getAiRecommendation(

        userQuery:
            query,

        mood:
            mood,

        diet:
            diet.toLowerCase(),

        cuisine:
            cuisine.toLowerCase(),

        budget:
            budget,
      );


      if (!mounted) return;


      setState(() {

        messages.add(

          _ChatMessage(

            text:
                response.isEmpty

                    ? "I couldn't find a good recommendation right now."

                    : response,

            isUser:
                false,
          ),
        );


        isLoading =
            false;
      });


      _scrollToBottom();


    } catch (e) {

      debugPrint(
        "Ask MoodMeal error: $e",
      );


      if (!mounted) return;


      setState(() {

        messages.add(

          _ChatMessage(

            text:
                "Sorry 😕 I couldn't connect "
                "to MoodMeal right now. "
                "Please try again.",

            isUser:
                false,
          ),
        );


        isLoading =
            false;
      });


      _scrollToBottom();
    }
  }


  // ===========================================================
  // SCROLL TO BOTTOM
  // ===========================================================

  void _scrollToBottom() {

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {

        if (!scrollController
            .hasClients) {

          return;
        }


        scrollController.animateTo(

          scrollController
              .position
              .maxScrollExtent,

          duration:
              const Duration(
            milliseconds: 300,
          ),

          curve:
              Curves.easeOut,
        );
      },
    );
  }


  // ===========================================================
  // ASK MOODMEAL UI
  // ===========================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Row(

          children: [

            CircleAvatar(

              radius: 18,

              backgroundColor:
                  Colors.orange,

              child:
                  Icon(

                Icons.auto_awesome,

                color:
                    Colors.white,

                size: 20,
              ),
            ),


            SizedBox(
              width: 10,
            ),


            Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Text(

                  "Ask MoodMeal",

                  style:
                      TextStyle(

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),


                Text(

                  "Your personal food assistant",

                  style:
                      TextStyle(

                    fontSize: 11,

                    fontWeight:
                        FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),


        backgroundColor:
            Colors.orange,

        foregroundColor:
            Colors.white,
      ),


      body:
          Column(

        children: [

          // =================================================
          // MOOD CONTEXT
          // =================================================

          Container(

            width:
                double.infinity,

            margin:
                const EdgeInsets.all(12),

            padding:
                const EdgeInsets.all(12),

            decoration:
                BoxDecoration(

              color:
                  Colors.orange
                      .withOpacity(0.10),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),


            child:
                Row(

              children: [

                const Icon(

                  Icons.mood,

                  color:
                      Colors.orange,
                ),


                const SizedBox(
                  width: 8,
                ),


                Expanded(

                  child:
                      Text(

                    "Current mood: "
                    "${widget.selectedMood}",

                    style:
                        const TextStyle(

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),


          // =================================================
          // CHAT MESSAGES
          // =================================================

          Expanded(

            child:
                ListView.builder(

              controller:
                  scrollController,

              padding:
                  const EdgeInsets
                      .symmetric(

                horizontal: 12,

                vertical: 8,
              ),


              itemCount:
                  messages.length +
                  (isLoading
                      ? 1
                      : 0),


              itemBuilder:
                  (context, index) {

                if (index ==
                    messages.length) {

                  return const Padding(

                    padding:
                        EdgeInsets.all(8),

                    child:
                        Align(

                      alignment:
                          Alignment.centerLeft,

                      child:
                          _TypingIndicator(),
                    ),
                  );
                }


                final message =
                    messages[index];


                return _buildMessage(
                  message,
                );
              },
            ),
          ),


          // =================================================
          // QUICK SUGGESTIONS
          // =================================================

          if (messages.length <= 1)

            SizedBox(

              height: 45,

              child:
                  ListView(

                scrollDirection:
                    Axis.horizontal,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 12,
                ),


                children: [

                  _quickSuggestion(
                    "🍕 Something spicy",
                  ),

                  _quickSuggestion(
                    "🍲 Comfort food",
                  ),

                  _quickSuggestion(
                    "🥗 Healthy meal",
                  ),

                  _quickSuggestion(
                    "💰 Under ₹300",
                  ),
                ],
              ),
            ),


          const SizedBox(
            height: 8,
          ),


          // =================================================
          // MESSAGE INPUT
          // =================================================

          Container(

            padding:
                const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              12,
            ),


            decoration:
                BoxDecoration(

              color:
                  Theme.of(context)
                      .scaffoldBackgroundColor,

              border:
                  Border(

                top:
                    BorderSide(

                  color:
                      Colors.grey
                          .withOpacity(
                    0.25,
                  ),
                ),
              ),
            ),


            child:
                Row(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,

              children: [

                Expanded(

                  child:
                      TextField(

                    controller:
                        messageController,

                    minLines:
                        1,

                    maxLines:
                        4,

                    textInputAction:
                        TextInputAction
                            .newline,


                    decoration:
                        InputDecoration(

                      hintText:
                          "Ask MoodMeal anything...",

                      filled:
                          true,

                      fillColor:
                          Theme.of(context)
                              .colorScheme
                              .surface,

                      border:
                          OutlineInputBorder(

                        borderRadius:
                            BorderRadius
                                .circular(
                          24,
                        ),

                        borderSide:
                            BorderSide.none,
                      ),

                      contentPadding:
                          const EdgeInsets
                              .symmetric(

                        horizontal: 18,

                        vertical: 12,
                      ),
                    ),


                    onSubmitted:
                        (_) {

                      sendMessage();
                    },
                  ),
                ),


                const SizedBox(
                  width: 8,
                ),


                Container(

                  decoration:
                      const BoxDecoration(

                    color:
                        Colors.orange,

                    shape:
                        BoxShape.circle,
                  ),


                  child:
                      IconButton(

                    onPressed:
                        isLoading
                            ? null
                            : sendMessage,

                    icon:
                        const Icon(

                      Icons.send,

                      color:
                          Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ===========================================================
  // MESSAGE BUBBLE
  // ===========================================================

  Widget _buildMessage(
    _ChatMessage message,
  ) {

    final isUser =
        message.isUser;


    return Align(

      alignment:
          isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,


      child:
          Container(

        constraints:
            BoxConstraints(

          maxWidth:
              MediaQuery.of(context)
                  .size
                  .width *
              0.82,
        ),


        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),


        padding:
            const EdgeInsets
                .symmetric(

          horizontal: 16,

          vertical: 12,
        ),


        decoration:
            BoxDecoration(

          color:

              isUser
                  ? Colors.orange
                  : Theme.of(context)
                      .colorScheme
                      .surface,


          borderRadius:
              BorderRadius.only(

            topLeft:
                const Radius.circular(
              18,
            ),

            topRight:
                const Radius.circular(
              18,
            ),

            bottomLeft:
                Radius.circular(
              isUser ? 18 : 4,
            ),

            bottomRight:
                Radius.circular(
              isUser ? 4 : 18,
            ),
          ),


          border:

              isUser

                  ? null

                  : Border.all(

                      color:
                          Colors.grey
                              .withOpacity(
                        0.25,
                      ),
                    ),
        ),


        child:
            Text(

          message.text,

          style:
              TextStyle(

            fontSize: 15,

            height: 1.4,

            color:

                isUser
                    ? Colors.white
                    : Theme.of(context)
                        .colorScheme
                        .onSurface,
          ),
        ),
      ),
    );
  }


  // ===========================================================
  // QUICK SUGGESTION
  // ===========================================================

  Widget _quickSuggestion(
    String text,
  ) {

    return Padding(

      padding:
          const EdgeInsets.only(
        right: 8,
      ),


      child:
          ActionChip(

        label:
            Text(text),


        onPressed: () {

          messageController
              .text = text;

          sendMessage();
        },
      ),
    );
  }
}



// =============================================================
// CHAT MESSAGE MODEL
// =============================================================

class _ChatMessage {

  final String text;

  final bool isUser;


  const _ChatMessage({

    required this.text,

    required this.isUser,
  });
}



// =============================================================
// TYPING INDICATOR
// =============================================================

class _TypingIndicator
    extends StatefulWidget {

  const _TypingIndicator();


  @override
  State<_TypingIndicator> createState() =>
      _TypingIndicatorState();
}



class _TypingIndicatorState
    extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;


  @override
  void initState() {

    super.initState();


    controller =
        AnimationController(

      vsync:
          this,

      duration:
          const Duration(
        milliseconds: 900,
      ),
    )..repeat();
  }


  @override
  void dispose() {

    controller.dispose();

    super.dispose();
  }


  @override
  Widget build(
    BuildContext context,
  ) {

    return Container(

      padding:
          const EdgeInsets
              .symmetric(

        horizontal: 16,

        vertical: 12,
      ),


      decoration:
          BoxDecoration(

        color:
            Theme.of(context)
                .colorScheme
                .surface,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(

          color:
              Colors.grey
                  .withOpacity(
            0.25,
          ),
        ),
      ),


      child:
          AnimatedBuilder(

        animation:
            controller,


        builder:
            (context, child) {

          final value =
              controller.value;


          return Row(

            mainAxisSize:
                MainAxisSize.min,

            children: [

              _dot(
                value,
                0.0,
              ),

              const SizedBox(
                width: 4,
              ),

              _dot(
                value,
                0.2,
              ),

              const SizedBox(
                width: 4,
              ),

              _dot(
                value,
                0.4,
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _dot(
    double value,
    double delay,
  ) {

    final adjusted =
        ((value - delay) % 1.0);


    final opacity =
        0.4 +
        (sin(
                  adjusted *
                      pi *
                      2,
                ) +
                1) *
            0.3;


    return Opacity(

      opacity:
          opacity,


      child:
          Container(

        width: 7,

        height: 7,

        decoration:
            const BoxDecoration(

          color:
              Colors.orange,

          shape:
              BoxShape.circle,
        ),
      ),
    );
  }
}