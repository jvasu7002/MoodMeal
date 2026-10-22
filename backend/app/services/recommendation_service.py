from app.utils.distance import calculate_distance


# ============================================================
# RESTAURANT DATA HELPERS
# ============================================================

def get_restaurant_coordinates(restaurant):
    """
    Extract latitude and longitude from an OSM restaurant object.

    OSM objects can store coordinates directly using:
        lat / lon

    Ways/relations may store them inside:
        center.lat / center.lon
    """

    latitude = restaurant.get("lat")
    longitude = restaurant.get("lon")

    if latitude is None or longitude is None:
        center = restaurant.get("center", {})

        latitude = center.get("lat")
        longitude = center.get("lon")

    if latitude is None or longitude is None:
        return None, None

    try:
        return float(latitude), float(longitude)
    except (TypeError, ValueError):
        return None, None


def get_restaurant_info(restaurant):
    """
    Extract useful information from OSM restaurant data.
    """

    tags = restaurant.get("tags", {})

    name = (
        tags.get("name")
        or tags.get("brand")
        or "Restaurant"
    )

    cuisine = tags.get("cuisine", "")

    restaurant_type = tags.get("amenity", "")

    return {
        "name": name,
        "cuisine": cuisine,
        "type": restaurant_type,
        "tags": tags,
    }


# ============================================================
# CUISINE SCORE
# ============================================================

def calculate_cuisine_score(
    restaurant_cuisine,
    preferred_cuisines,
):
    """
    Calculate cuisine matching score.

    Maximum: 30 points
    Exact match: 30
    Partial match: 24
    No match: 5
    No preference: 15
    """

    if not preferred_cuisines:
        return 15, None

    restaurant_cuisine = restaurant_cuisine or ""

    restaurant_cuisines = [
        item.strip().lower()
        for item in restaurant_cuisine.split(";")
        if item.strip()
    ]

    for preferred in preferred_cuisines:

        preferred_lower = preferred.strip().lower()

        for cuisine in restaurant_cuisines:

            # Exact match
            if cuisine == preferred_lower:
                return 30, preferred

            # Partial match
            if (
                cuisine in preferred_lower
                or preferred_lower in cuisine
            ):
                return 24, preferred

    return 5, None


# ============================================================
# MOOD SCORE
# ============================================================

def calculate_mood_score(
    mood,
    restaurant_type,
    cuisine,
):
    """
    Calculate how suitable a restaurant is
    for the user's current mood.

    Maximum: 20 points
    """

    mood = (mood or "").lower()
    restaurant_type = (restaurant_type or "").lower()
    cuisine = (cuisine or "").lower()

    # --------------------------------------------------------
    # HAPPY
    # --------------------------------------------------------
    if "happy" in mood:

        if (
            "restaurant" in restaurant_type
            or "cafe" in restaurant_type
        ):
            return 20

        return 12

    # --------------------------------------------------------
    # STRESSED
    # --------------------------------------------------------
    if "stressed" in mood:

        if (
            "restaurant" in restaurant_type
            or "cafe" in restaurant_type
        ):
            return 20

        return 12

    # --------------------------------------------------------
    # TIRED
    # --------------------------------------------------------
    if "tired" in mood:

        if "cafe" in restaurant_type:
            return 20

        if "restaurant" in restaurant_type:
            return 16

        return 10

    # --------------------------------------------------------
    # STUDY
    # --------------------------------------------------------
    if "study" in mood:

        if "cafe" in restaurant_type:
            return 20

        return 10

    # --------------------------------------------------------
    # WORKOUT
    # --------------------------------------------------------
    if "workout" in mood:

        healthy_keywords = [
            "salad",
            "healthy",
            "vegetarian",
            "vegan",
            "organic",
        ]

        if any(
            keyword in cuisine
            for keyword in healthy_keywords
        ):
            return 20

        return 8

    # --------------------------------------------------------
    # ROMANTIC
    # --------------------------------------------------------
    if "romantic" in mood:

        if "restaurant" in restaurant_type:
            return 20

        if "cafe" in restaurant_type:
            return 17

        return 8

    # Default
    return 10


# ============================================================
# RESTAURANT TYPE SCORE
# ============================================================

def calculate_type_score(
    mood,
    restaurant_type,
):
    """
    Calculate restaurant-type compatibility.

    Maximum: 10 points.
    """

    mood = (mood or "").lower()
    restaurant_type = (restaurant_type or "").lower()

    # Study -> Cafe
    if (
        "study" in mood
        and "cafe" in restaurant_type
    ):
        return 10

    # Tired -> Cafe
    if (
        "tired" in mood
        and "cafe" in restaurant_type
    ):
        return 10

    # Romantic -> Restaurant
    if (
        "romantic" in mood
        and "restaurant" in restaurant_type
    ):
        return 10

    # General restaurant
    if "restaurant" in restaurant_type:
        return 8

    # General cafe
    if "cafe" in restaurant_type:
        return 7

    # Fast food
    if "fast_food" in restaurant_type:
        return 6

    return 4


# ============================================================
# DISTANCE SCORE
# ============================================================

def calculate_distance_score(
    distance,
    preferred_distance,
):
    """
    Calculate distance score.

    Maximum: 40 points.
    """

    if preferred_distance <= 0:
        return 0

    # Extremely close
    if distance <= 1:
        return 40

    ratio = distance / preferred_distance

    if ratio <= 0.5:
        return 36

    if ratio <= 0.75:
        return 32

    if ratio <= 1.0:
        return 28

    if ratio <= 1.5:
        return 20

    if ratio <= 2.0:
        return 12

    return 5


# ============================================================
# MAIN RECOMMENDATION ENGINE
# ============================================================

def recommend_restaurants(
    restaurants,
    latitude,
    longitude,
    preferred_distance,
    favorite_cuisines,
    mood,
):
    """
    Main MoodMeal recommendation engine.

    Scoring:

        Distance  -> 40 points
        Cuisine   -> 30 points
        Mood      -> 20 points
        Type      -> 10 points

        TOTAL     -> 100 points
    """

    results = []

    # Safety
    favorite_cuisines = favorite_cuisines or []

    for restaurant in restaurants:

        # ----------------------------------------------------
        # GET COORDINATES
        # ----------------------------------------------------

        restaurant_lat, restaurant_lon = (
            get_restaurant_coordinates(
                restaurant
            )
        )

        if (
            restaurant_lat is None
            or restaurant_lon is None
        ):
            continue

        # ----------------------------------------------------
        # GET RESTAURANT INFORMATION
        # ----------------------------------------------------

        info = get_restaurant_info(
            restaurant
        )

        # ----------------------------------------------------
        # CALCULATE DISTANCE
        # ----------------------------------------------------

        distance = calculate_distance(
            latitude,
            longitude,
            restaurant_lat,
            restaurant_lon,
        )

        # ----------------------------------------------------
        # CALCULATE INDIVIDUAL SCORES
        # ----------------------------------------------------

        distance_score = calculate_distance_score(
            distance,
            preferred_distance,
        )

        cuisine_score, matched_cuisine = (
            calculate_cuisine_score(
                info["cuisine"],
                favorite_cuisines,
            )
        )

        mood_score = calculate_mood_score(
            mood,
            info["type"],
            info["cuisine"],
        )

        type_score = calculate_type_score(
            mood,
            info["type"],
        )

        # ----------------------------------------------------
        # TOTAL SCORE
        # ----------------------------------------------------

        total_score = (
            distance_score
            + cuisine_score
            + mood_score
            + type_score
        )

        # ----------------------------------------------------
        # GENERATE REASONS
        # ----------------------------------------------------

        reasons = []

        # Distance reason
        if distance <= preferred_distance:
            reasons.append(
                f"{distance:.1f} km away"
            )
        else:
            reasons.append(
                "Slightly beyond your preferred distance"
            )

        # Cuisine reason
        if matched_cuisine:
            reasons.append(
                f"Matches your {matched_cuisine} preference"
            )

        # Mood reason
        if mood_score >= 15:
            reasons.append(
                "Good fit for your current mood"
            )

        # Restaurant type reason
        if type_score >= 8:
            reasons.append(
                "Suitable place type"
            )

        # ----------------------------------------------------
        # ADD RESULT
        # ----------------------------------------------------

        results.append({
            "name": info["name"],
            "distance": round(distance, 2),
            "score": round(total_score, 2),
            "cuisine": info["cuisine"],
            "type": info["type"],
            "reasons": reasons,
            "restaurant": restaurant,
        })

    # --------------------------------------------------------
    # SORT BY SCORE
    # --------------------------------------------------------

    results.sort(
        key=lambda item: item["score"],
        reverse=True,
    )

    return results