import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static Future<List<String>> getFavorites() async {
    final snapshot = await _firestore
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .get();

    return snapshot.docs
        .map((doc) => doc.id)
        .toList();
  }

 static Future<void> saveFavorite({
  required String name,
  required String cuisine,
  required double latitude,
  required double longitude,
  required String city,
  required double distance,
}) async {
  await _firestore
      .collection("users")
      .doc(_uid)
      .collection("favorites")
      .doc(name)
      .set({
    "name": name,
    "cuisine": cuisine,
    "latitude": latitude,
    "longitude": longitude,
    "city": city,
    "distance": distance,
    "createdAt": FieldValue.serverTimestamp(),
  });
}

  static Future<void> removeFavorite(String restaurant) async {
    await _firestore
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(restaurant)
        .delete();
  }

  static Future<bool> isFavorite(String restaurant) async {
    final doc = await _firestore
        .collection("users")
        .doc(_uid)
        .collection("favorites")
        .doc(restaurant)
        .get();

    return doc.exists;
  }

  static Future<List<Map<String, dynamic>>> getFavoriteDetails() async {
  final snapshot = await _firestore
      .collection("users")
      .doc(_uid)
      .collection("favorites")
      .get();

  return snapshot.docs
      .map((doc) => doc.data())
      .toList();
}
}