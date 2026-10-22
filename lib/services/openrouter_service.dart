import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  // API key is stored securely on the backend.
  static Future<String> getFoodRecommendation(String mood) async {
    try {
      final response = await http.post(
        Uri.parse(
          "https://openrouter.ai/api/v1/chat/completions",
        ),
        headers: {
          "Content-Type": "application/json",
          "HTTP-Referer": "https://moodmeal.app",
          "X-Title": "MoodMeal",
        },
        body: jsonEncode({
  "model": "google/gemini-2.5-flash",
  "max_tokens": 100,
  "messages": [
    {
      "role": "user",
      "content":
          "Suggest exactly 3 foods for someone feeling $mood. Return only food names."
    }
  ]
}),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data["choices"][0]["message"]["content"];
      }

      return "API Error: ${response.statusCode}\n${response.body}";
    } catch (e) {
      return "Error: $e";
    }
  }
}