import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // Save a favorite restaurant
  Future<void> addFavorite(String restaurantName) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(restaurantName)
        .set({
      "name": restaurantName,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Remove a favorite restaurant
  Future<void> removeFavorite(String restaurantName) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(restaurantName)
        .delete();
  }

  // Stream of favorites
  Stream<QuerySnapshot> getFavorites() {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .snapshots();
  }

  // Check if restaurant is favorite
  Future<bool> isFavorite(String restaurantName) async {
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(restaurantName)
        .get();

    return doc.exists;
  }
// =============================
// USER PROFILE SECTION
// =============================

// Create user profile
Future<void> createUserProfile(UserModel user) async {
  await _firestore
      .collection("users")
      .doc(user.uid)
      .set(user.toMap(), SetOptions(merge: true));
}

// Get current user profile
Future<UserModel?> getUserProfile() async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) return null;

  final doc = await _firestore
      .collection("users")
      .doc(currentUser.uid)
      .get();

  if (!doc.exists) return null;

  return UserModel.fromMap(doc.data()!);
}

// Update profile
Future<void> updateUserProfile(
    Map<String, dynamic> data) async {

  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) return;

  await _firestore
      .collection("users")
      .doc(currentUser.uid)
      .update(data);
}

// Check onboarding
Future<bool> isProfileCompleted() async {
  final profile = await getUserProfile();

  if (profile == null) return false;

  return profile.completedSetup;
}
}