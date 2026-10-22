import 'dart:convert';
import 'package:http/http.dart' as http;

class PexelsService {

  // 🔑 Paste your API Key here
  static const String apiKey = "F539T1i2fjnSx3XrXmcIH3uGGnV9Pfh4VOptyO4hS95qbZRRY6ZWtQrg";

  static Future<String?> getImage(String keyword) async {

    final url = Uri.parse(
      "https://api.pexels.com/v1/search?query=$keyword&per_page=1",
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": apiKey,
      },
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      if (data["photos"].length > 0) {

        return data["photos"][0]["src"]["large2x"];

      }

    }

    return null;
  }
}