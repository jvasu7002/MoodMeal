import 'package:flutter/material.dart';
import 'package:moodmeal/services/favorite_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> favorites = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    favorites = await FavoriteService.getFavoriteDetails();

    if (mounted) {
      setState(() {});
    }
  }

  
Future<void> openGoogleMaps(
  double latitude,
  double longitude,
) async {
  if (latitude == 0 || longitude == 0) {
    debugPrint('Invalid restaurant coordinates: $latitude, $longitude');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restaurant location is unavailable'),
      ),
    );
    return;
  }

  final Uri url = Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query': '$latitude,$longitude',
    },
  );

  try {
    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    debugPrint('Favorites Maps URL: $url');
    debugPrint('Favorites Maps launch result: $opened');

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps'),
        ),
      );
    }
  } catch (e) {
    debugPrint('Favorites Maps launch error: $e');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error opening Google Maps'),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("❤️ Favorites"),
      ),

      body: favorites.isEmpty
          ? const Center(
              child: Text(
                "No Favorite Restaurants Yet",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {

                final restaurant = favorites[index];

                final String name =
                    restaurant["name"] ?? "Restaurant";

                final String cuisine =
                    restaurant["cuisine"] ?? "Food Place";

                final String city =
                    restaurant["city"] ?? "Unknown";

                final double distance =
                    (restaurant["distance"] ?? 0).toDouble();

                final double latitude =
                    (restaurant["latitude"] ?? 0).toDouble();

                final double longitude =
                    (restaurant["longitude"] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(
                        Icons.restaurant,
                        color: Colors.white,
                      ),
                    ),

                    title: Text(name),

                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text("🍽️ $cuisine"),
                        Text("📍 $city"),
                        Text(
                          "📏 ${distance.toStringAsFixed(1)} km",
                        ),
                      ],
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        IconButton(
                          icon: const Icon(
                            Icons.map,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            await openGoogleMaps(
                              latitude,
                              longitude,
                            );
                          },
                        ),

                        IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            await FavoriteService.removeFavorite(
                              name,
                            );

                            loadFavorites();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}