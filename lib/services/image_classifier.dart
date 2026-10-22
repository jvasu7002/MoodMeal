class ImageClassifier {
  static String getImageKeyword(String restaurantName, String cuisine) {
    final text = "$restaurantName $cuisine".toLowerCase();

    final Map<String, String> keywords = {
      "ice cream": "ice cream",
      "parlour": "ice cream",
      "gelato": "ice cream",

      "pizza": "pizza",
      "domino": "pizza",
      "pizza hut": "pizza",

      "burger": "burger",
      "burger king": "burger",
      "mcdonald": "burger",

      "coffee": "coffee",
      "cafe": "coffee",
      "starbucks": "coffee",

      "kfc": "fried chicken",

      "biryani": "biryani",

      "momo": "momos",

      "chinese": "chinese food",
      "wok": "chinese food",

      "south": "south indian food",

      "north": "north indian food",

      "sweet": "dessert",
      "haldiram": "indian sweets",
      "bikanervala": "indian sweets",

      "bakery": "bakery",

      "veg": "vegetarian food",

      "dessert": "dessert",
    };

    for (final entry in keywords.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    return "restaurant food";
  }
}