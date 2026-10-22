import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService firestoreService = FirestoreService();

  UserModel? user;

  bool isLoading = true;
  bool isSaving = false;

  late TextEditingController nameController;
  late TextEditingController budgetController;

  List<String> cuisines = [];

  String budgetType = "Per Person / Per Meal";

  int numberOfPeople = 1;

  String diet = "No Preference";

  int distance = 5;

  String companion = "Alone";

  final List<String> allCuisines = [
    "Pizza",
    "Burger",
    "Indian",
    "Chinese",
    "Cafe",
    "Dessert",
    "Biryani",
  ];

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

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController();
    budgetController = TextEditingController();

    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final profile =
          await firestoreService.getUserProfile();

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        user = profile;

        nameController.text = profile.name;

        budgetController.text =
            profile.budget.toString();

        budgetType = profile.budgetType;

        numberOfPeople =
            profile.numberOfPeople;

        cuisines =
            List<String>.from(
          profile.favoriteCuisines,
        );

        diet = profile.diet;

        distance =
            profile.preferredDistance;

        companion =
            profile.companion;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Failed to load profile: $e"),
        ),
      );
    }
  }

  bool get isGroupBudget {
    return budgetType.startsWith("Total Group");
  }

  Future<void> saveProfile() async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null || user == null) {
      return;
    }

    final name =
        nameController.text.trim();

    final budget =
        int.tryParse(
      budgetController.text.trim(),
    );

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Please enter your name"),
        ),
      );
      return;
    }

    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Please enter a valid budget"),
        ),
      );
      return;
    }

    if (isGroupBudget &&
        numberOfPeople < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Number of people must be at least 1"),
        ),
      );
      return;
    }

    try {
      setState(() {
        isSaving = true;
      });

      await firestoreService.updateUserProfile({
        "name": name,
        "budget": budget,
        "budgetType": budgetType,
        "numberOfPeople": numberOfPeople,
        "favoriteCuisines": cuisines,
        "diet": diet,
        "preferredDistance": distance,
        "companion": companion,
      });

      // Keep Firebase Auth name synchronized.
      if (currentUser.displayName != name) {
        await currentUser.updateDisplayName(name);
      }

      if (!mounted) return;

      setState(() {
        user = user!.copyWith(
          name: name,
          budget: budget,
          budgetType: budgetType,
          numberOfPeople: numberOfPeople,
          favoriteCuisines:
              List<String>.from(cuisines),
          diet: diet,
          preferredDistance: distance,
          companion: companion,
        );

        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Profile updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Failed to update profile: $e"),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    budgetController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text("My Profile"),
        ),
        body: const Center(
          child:
              Text("Profile not found"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("My Profile"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // =====================================
            // PROFILE HEADER
            // =====================================

            Center(
              child: Column(
                children: [

                  CircleAvatar(
                    radius: 50,
                    backgroundColor:
                        Colors.orange.shade100,
                    child: const Icon(
                      Icons.person,
                      size: 55,
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    user!.name.isEmpty
                        ? "User"
                        : user!.name,

                    style:
                        const TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    user!.email,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // =====================================
            // PERSONAL INFORMATION
            // =====================================

            const Text(
              "Personal Information",
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
                  nameController,

              decoration:
                  InputDecoration(
                labelText: "Name",
                prefixIcon:
                    const Icon(
                  Icons.person_outline,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              readOnly: true,

              controller:
                  TextEditingController(
                text: user!.email,
              ),

              decoration:
                  InputDecoration(
                labelText: "Email",
                prefixIcon:
                    const Icon(
                  Icons.email_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // =====================================
            // FOOD PREFERENCES
            // =====================================

            const Text(
              "Food Preferences",
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            // BUDGET TYPE

            DropdownButtonFormField<String>(
              value: budgetType,

              decoration:
                  InputDecoration(
                labelText:
                    "Budget Type",
                prefixIcon:
                    const Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
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

                  // Reset group count
                  // when switching
                  // away from group.
                  if (!value
                      .startsWith(
                          "Total Group")) {
                    numberOfPeople = 1;
                  }
                });
              },
            ),

            const SizedBox(height: 15),

            // BUDGET AMOUNT

            TextField(
              controller:
                  budgetController,

              keyboardType:
                  TextInputType.number,

              decoration:
                  InputDecoration(
                labelText:
                    "Budget Amount",
                prefixIcon:
                    const Icon(
                  Icons.currency_rupee,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
            ),

            // =====================================
            // NUMBER OF PEOPLE
            // =====================================

            if (isGroupBudget) ...[

              const SizedBox(height: 15),

              InputDecorator(
                decoration:
                    InputDecoration(
                  labelText:
                      "Number of People",
                  prefixIcon:
                      const Icon(
                    Icons.people_outline,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
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
                        Icons.remove_circle_outline,
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
                        Icons.add_circle_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 25),

            // =====================================
            // FAVOURITE CUISINES
            // =====================================

            const Text(
              "Favourite Cuisines",
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,

              children:
                  allCuisines.map(
                (item) {

                  final selected =
                      cuisines
                          .contains(item);

                  return FilterChip(
                    label:
                        Text(item),

                    selected:
                        selected,

                    onSelected:
                        (value) {
                      setState(() {

                        if (value) {
                          cuisines.add(
                              item);
                        } else {
                          cuisines.remove(
                              item);
                        }

                      });
                    },
                  );
                },
              ).toList(),
            ),

            const SizedBox(height: 25),

            // =====================================
            // DIET
            // =====================================

            DropdownButtonFormField<String>(
              value: diet,

              decoration:
                  InputDecoration(
                labelText:
                    "Diet",
                prefixIcon:
                    const Icon(
                  Icons.eco_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value:
                      "Vegetarian",
                  child:
                      Text("Vegetarian"),
                ),

                DropdownMenuItem(
                  value:
                      "Non-Veg",
                  child:
                      Text("Non-Veg"),
                ),

                DropdownMenuItem(
                  value:
                      "Vegan",
                  child:
                      Text("Vegan"),
                ),

                DropdownMenuItem(
                  value:
                      "No Preference",
                  child:
                      Text("No Preference"),
                ),
              ],

              onChanged:
                  (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  diet = value;
                });
              },
            ),

            const SizedBox(height: 25),

            // =====================================
            // DISTANCE
            // =====================================

            DropdownButtonFormField<int>(
              value: distance,

              decoration:
                  InputDecoration(
                labelText:
                    "Preferred Distance",
                prefixIcon:
                    const Icon(
                  Icons.location_on_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value: 2,
                  child:
                      Text("Within 2 km"),
                ),

                DropdownMenuItem(
                  value: 5,
                  child:
                      Text("Within 5 km"),
                ),

                DropdownMenuItem(
                  value: 10,
                  child:
                      Text("Within 10 km"),
                ),

                DropdownMenuItem(
                  value: 20,
                  child:
                      Text("Within 20 km"),
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

            // =====================================
            // COMPANION
            // =====================================

            DropdownButtonFormField<String>(
              value: companion,

              decoration:
                  InputDecoration(
                labelText:
                    "Usually Eat With",
                prefixIcon:
                    const Icon(
                  Icons.people_outline,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),

              items: const [

                DropdownMenuItem(
                  value: "Alone",
                  child:
                      Text("Alone"),
                ),

                DropdownMenuItem(
                  value: "Friends",
                  child:
                      Text("Friends"),
                ),

                DropdownMenuItem(
                  value: "Family",
                  child:
                      Text("Family"),
                ),

                DropdownMenuItem(
                  value: "Partner",
                  child:
                      Text("Partner"),
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

            // =====================================
            // SAVE
            // =====================================

            SizedBox(
              width:
                  double.infinity,

              height: 55,

              child:
                  ElevatedButton.icon(

                onPressed:
                    isSaving
                        ? null
                        : saveProfile,

                icon: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),

                label: Text(
                  isSaving
                      ? "Saving..."
                      : "Save Changes",

                  style:
                      const TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}