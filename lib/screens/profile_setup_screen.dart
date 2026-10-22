import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState
    extends State<ProfileSetupScreen> {

  // =====================================================
  // FOOD BUDGET
  // =====================================================

  int budget = 500;

  String budgetType = "Per Person / Per Meal";

  int numberOfPeople = 1;

  final List<String> budgetTypes = [
    "Per Person / Per Meal",
    "Per Person / Per Day",
    "Per Person / Per Week",
    "Per Person / Per Month",
    "Total Group / Per Meal",
    "Total Group / Per Day",
    "Total Group / Per Week",
    "Total Group / Per Month",
  ];

  // =====================================================
  // OTHER PREFERENCES
  // =====================================================

  String diet = "No Preference";

  int distance = 5;

  String companion = "Alone";

  List<String> cuisines = [];

  final List<String> allCuisines = [
    "Pizza",
    "Burger",
    "Indian",
    "Chinese",
    "Cafe",
    "Dessert",
    "Biryani",
  ];

  // =====================================================
  // FIRESTORE SERVICE
  // =====================================================

  final FirestoreService firestoreService =
      FirestoreService();

  // =====================================================
  // SAVE PROFILE
  // =====================================================

  Future<void> saveProfile() async {

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {

      UserModel user = UserModel(
        uid: currentUser.uid,

        name:
            currentUser.displayName ?? "",

        email:
            currentUser.email ?? "",

        // Budget
        budget: budget,

        budgetType: budgetType,

        numberOfPeople: numberOfPeople,

        // Preferences
        favoriteCuisines: cuisines,

        diet: diet,

        preferredDistance: distance,

        companion: companion,

        // Existing data
        favoriteRestaurants: [],

        recommendationHistory: [],

        completedSetup: true,

        createdAt: Timestamp.now(),
      );

      await firestoreService
          .createUserProfile(user);

      if (!mounted) return;

      Navigator.pop(context);

    } catch (e) {

      debugPrint(
        "PROFILE SAVE ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Failed to save profile: $e",
          ),
        ),
      );
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {

    final isGroupBudget =
        budgetType.startsWith("Total Group");

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Personalize MoodMeal",
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // =================================================
            // WELCOME
            // =================================================

            const Text(
              "Welcome 👋",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Let's personalize your experience.",
            ),

            const SizedBox(height: 30),

            // =================================================
            // FOOD BUDGET
            // =================================================

            const Text(
              "Food Budget",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 12),

            // Budget Type

            DropdownButtonFormField<String>(

              value: budgetType,

              decoration:
                  const InputDecoration(
                labelText:
                    "Budget Type",
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.account_balance_wallet_outlined,
                ),
              ),

              items:
                  budgetTypes.map(
                (type) {

                  return DropdownMenuItem<
                      String>(
                    value: type,
                    child:
                        Text(type),
                  );
                },
              ).toList(),

              onChanged:
                  (value) {

                if (value == null) {
                  return;
                }

                setState(() {

                  budgetType =
                      value;

                  // Reset people when
                  // switching back to
                  // individual budget.

                  if (!budgetType
                      .startsWith(
                          "Total Group")) {

                    numberOfPeople = 1;
                  }
                });
              },
            ),

            const SizedBox(height: 15),

            // Budget Amount

            TextFormField(

              initialValue:
                  budget.toString(),

              keyboardType:
                  TextInputType.number,

              decoration:
                  const InputDecoration(

                labelText:
                    "Budget Amount",

                prefixText:
                    "₹ ",

                border:
                    OutlineInputBorder(),

                prefixIcon:
                    Icon(
                  Icons.currency_rupee,
                ),
              ),

              onChanged:
                  (value) {

                final amount =
                    int.tryParse(
                        value);

                if (amount != null &&
                    amount > 0) {

                  budget =
                      amount;
                }
              },
            ),

            // =================================================
            // NUMBER OF PEOPLE
            // =================================================

            if (isGroupBudget) ...[

              const SizedBox(height: 15),

              InputDecorator(

                decoration:
                    const InputDecoration(

                  labelText:
                      "Number of People",

                  border:
                      OutlineInputBorder(),

                  prefixIcon:
                      Icon(
                    Icons.people_outline,
                  ),
                ),

                child: Row(

                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                  children: [

                    IconButton(

                      onPressed:
                          numberOfPeople > 1
                              ? () {

                                  setState(() {

                                    numberOfPeople--;

                                  });
                                }
                              : null,

                      icon:
                          const Icon(
                        Icons
                            .remove_circle_outline,
                      ),
                    ),

                    Text(

                      "$numberOfPeople",

                      style:
                          const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    IconButton(

                      onPressed: () {

                        setState(() {

                          numberOfPeople++;

                        });
                      },

                      icon:
                          const Icon(
                        Icons
                            .add_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // =================================================
            // FAVOURITE CUISINES
            // =================================================

            const Text(
              "Favourite Cuisines",
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 10),

            Wrap(

              spacing: 10,

              runSpacing: 8,

              children:
                  allCuisines.map(
                (item) {

                  final selected =
                      cuisines.contains(
                          item);

                  return FilterChip(

                    label:
                        Text(item),

                    selected:
                        selected,

                    onSelected:
                        (_) {

                      setState(() {

                        if (selected) {

                          cuisines
                              .remove(
                                  item);

                        } else {

                          cuisines
                              .add(
                                  item);
                        }
                      });
                    },
                  );
                },
              ).toList(),
            ),

            const SizedBox(height: 30),

            // =================================================
            // DIET
            // =================================================

            DropdownButtonFormField<
                String>(

              value: diet,

              decoration:
                  const InputDecoration(
                labelText:
                    "Diet",
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.restaurant_menu,
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value:
                      "Vegetarian",
                  child:
                      Text(
                    "Vegetarian",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "Non-Veg",
                  child:
                      Text(
                    "Non-Veg",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "Vegan",
                  child:
                      Text(
                    "Vegan",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "No Preference",
                  child:
                      Text(
                    "No Preference",
                  ),
                ),
              ],

              onChanged:
                  (value) {

                if (value == null) {
                  return;
                }

                setState(() {

                  diet =
                      value;
                });
              },
            ),

            const SizedBox(height: 25),

            // =================================================
            // DISTANCE
            // =================================================

            DropdownButtonFormField<int>(

              value: distance,

              decoration:
                  const InputDecoration(

                labelText:
                    "Preferred Distance",

                border:
                    OutlineInputBorder(),

                prefixIcon:
                    Icon(
                  Icons.location_on_outlined,
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value: 2,
                  child:
                      Text("2 km"),
                ),

                DropdownMenuItem(
                  value: 5,
                  child:
                      Text("5 km"),
                ),

                DropdownMenuItem(
                  value: 10,
                  child:
                      Text("10 km"),
                ),

                DropdownMenuItem(
                  value: 20,
                  child:
                      Text("20 km"),
                ),
              ],

              onChanged:
                  (value) {

                if (value == null) {
                  return;
                }

                setState(() {

                  distance =
                      value;
                });
              },
            ),

            const SizedBox(height: 25),

            // =================================================
            // COMPANION
            // =================================================

            DropdownButtonFormField<
                String>(

              value: companion,

              decoration:
                  const InputDecoration(

                labelText:
                    "Usually Eat With",

                border:
                    OutlineInputBorder(),

                prefixIcon:
                    Icon(
                  Icons.people_outline,
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value:
                      "Alone",
                  child:
                      Text(
                    "Alone",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "Friends",
                  child:
                      Text(
                    "Friends",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "Family",
                  child:
                      Text(
                    "Family",
                  ),
                ),

                DropdownMenuItem(
                  value:
                      "Partner",
                  child:
                      Text(
                    "Partner",
                  ),
                ),
              ],

              onChanged:
                  (value) {

                if (value == null) {
                  return;
                }

                setState(() {

                  companion =
                      value;
                });
              },
            ),

            const SizedBox(height: 40),

            // =================================================
            // CONTINUE
            // =================================================

            SizedBox(

              width:
                  double.infinity,

              height: 55,

              child:
                  ElevatedButton(

                onPressed:
                    saveProfile,

                child:
                    const Text(

                  "Continue",

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}