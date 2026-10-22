import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moodmeal/services/pexels_service.dart';
import 'package:moodmeal/services/image_classifier.dart';


class RestaurantDetailScreen extends StatelessWidget {
  final String name;
  final String cuisine;
  final String city;
  final double distance;
  final double latitude;
  final double longitude;

  const RestaurantDetailScreen({
    super.key,
    required this.name,
    required this.cuisine,
    required this.city,


    required this.distance,
    required this.latitude,
    required this.longitude,
  });

 
Future<void> openMaps() async {
  final Uri uri = Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query': '$latitude,$longitude',
    },
  );

  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    debugPrint('Restaurant Maps URL: $uri');
    debugPrint('Restaurant Maps launch result: $opened');

    if (!opened) {
      debugPrint('Could not launch Google Maps URL');
    }
  } catch (e) {
    debugPrint('Restaurant Maps launch error: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Details"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            ClipRRect(
  borderRadius: const BorderRadius.only(
    bottomLeft: Radius.circular(25),
    bottomRight: Radius.circular(25),
  ),
  child: FutureBuilder<String?>(
  future: PexelsService.getImage(
    ImageClassifier.getImageKeyword(name, cuisine),
  ),
  builder: (context, snapshot) {

    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        height: 250,
        color: Colors.orange.shade100,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data == null) {
      return Container(
        height: 250,
        color: Colors.orange.shade100,
        child: const Center(
          child: Icon(
            Icons.restaurant,
            size: 90,
            color: Colors.orange,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(25),
        bottomRight: Radius.circular(25),
      ),
      child: Image.network(
        snapshot.data!,
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  },
)
),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [

                      const Icon(
                        Icons.restaurant_menu,
                        color: Colors.orange,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        cuisine,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [

                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          city,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [

                      const Icon(
                        Icons.route,
                        color: Colors.blue,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        "${distance.toStringAsFixed(1)} km away",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "About",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "$name serves delicious $cuisine and is one of the popular restaurants near $city. Explore the location and enjoy your meal.",
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 35),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text(
                        "Open in Google Maps",
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: openMaps,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}