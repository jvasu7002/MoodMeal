from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx
import re

from app.services.restaurant_service import fetch_restaurants
from app.services.recommendation_service import recommend_restaurants
from app.rag_service import generate_rag_answer


# =====================================================
# APP
# =====================================================

app = FastAPI(
    title="MoodMeal API",
    description="Backend API for MoodMeal",
    version="1.0.0",
)


# =====================================================
# CORS
# =====================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =====================================================
# ROOT
# =====================================================

@app.get("/")
async def root():
    return {
        "message": "MoodMeal Backend is running 🚀",
        "status": "success",
    }


# =====================================================
# HEALTH CHECK
# =====================================================

@app.get("/health")
async def health_check():
    return {
        "status": "healthy"
    }


# =====================================================
# LOCATION
# =====================================================

@app.get("/location")
async def get_location(location: str):

    if not location.strip():
        raise HTTPException(
            status_code=400,
            detail="Location cannot be empty.",
        )

    url = "https://nominatim.openstreetmap.org/search"

    params = {
        "format": "json",
        "q": location,
        "limit": 1,
    }

    headers = {
        "User-Agent": "MoodMeal/1.0"
    }

    try:

        async with httpx.AsyncClient(
            timeout=10.0
        ) as client:

            response = await client.get(
                url,
                params=params,
                headers=headers,
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=(
                    "Location service is "
                    "currently unavailable."
                ),
            )

        data = response.json()

        if not data:
            raise HTTPException(
                status_code=404,
                detail=(
                    f"Location '{location}' "
                    "not found."
                ),
            )

        result = data[0]

        return {
            "location": location,
            "display_name": result.get(
                "display_name"
            ),
            "latitude": float(
                result["lat"]
            ),
            "longitude": float(
                result["lon"]
            ),
        }

    except httpx.TimeoutException:

        raise HTTPException(
            status_code=504,
            detail="Location service timed out.",
        )

    except httpx.RequestError:

        raise HTTPException(
            status_code=502,
            detail=(
                "Could not connect to "
                "location service."
            ),
        )


# =====================================================
# RESTAURANTS
# =====================================================

@app.get("/restaurants")
async def get_restaurants(
    latitude: float,
    longitude: float,
    radius: float = 5,
):

    if radius <= 0:
        raise HTTPException(
            status_code=400,
            detail="Radius must be greater than 0 km.",
        )

    if radius > 50:
        raise HTTPException(
            status_code=400,
            detail="Maximum search radius is 50 km.",
        )

    try:

        restaurants = await fetch_restaurants(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius,
        )

        return {
            "latitude": latitude,
            "longitude": longitude,
            "radius_km": radius,
            "count": len(restaurants),
            "restaurants": restaurants,
        }

    except ValueError as e:

        raise HTTPException(
            status_code=400,
            detail=str(e),
        )

    except Exception as e:

        print(
            f"Restaurant service error: {e}",
            flush=True,
        )

        raise HTTPException(
            status_code=503,
            detail="Unable to load restaurants right now.",
        )


# =====================================================
# TEST RECOMMENDATIONS
# =====================================================

@app.get("/recommendations/test")
async def test_recommendations():

    test_restaurants = [

        {
            "type": "node",
            "id": 1,
            "lat": 28.6320,
            "lon": 77.2190,
            "tags": {
                "name": "Test Indian Restaurant",
                "amenity": "restaurant",
                "cuisine": "indian",
            },
        },

        {
            "type": "node",
            "id": 2,
            "lat": 28.6400,
            "lon": 77.2300,
            "tags": {
                "name": "Test Cafe",
                "amenity": "cafe",
                "cuisine": "cafe",
            },
        },
    ]

    results = recommend_restaurants(
        restaurants=test_restaurants,
        latitude=28.6328,
        longitude=77.2197,
        preferred_distance=5,
        favorite_cuisines=["Indian"],
        mood="happy",
    )

    return {
        "count": len(results),
        "recommendations": results,
    }


# =====================================================
# RESTAURANT RECOMMENDATIONS
# =====================================================

@app.get("/recommendations")
async def get_recommendations(
    latitude: float,
    longitude: float,
    mood: str,
    preferred_distance: float = 5,
    favorite_cuisines: str = "",
):

    if not mood.strip():
        raise HTTPException(
            status_code=400,
            detail="Mood cannot be empty.",
        )

    if preferred_distance <= 0:
        raise HTTPException(
            status_code=400,
            detail="Preferred distance must be greater than 0.",
        )

    if preferred_distance > 50:
        raise HTTPException(
            status_code=400,
            detail="Maximum search radius is 50 km.",
        )

    cuisines = []

    if favorite_cuisines.strip():

        cuisines = [
            cuisine.strip()
            for cuisine in favorite_cuisines.split(",")
            if cuisine.strip()
        ]

    restaurants_response = await get_restaurants(
        latitude=latitude,
        longitude=longitude,
        radius=preferred_distance,
    )

    restaurants = restaurants_response.get(
        "restaurants",
        [],
    )

    recommendations = recommend_restaurants(
        restaurants=restaurants,
        latitude=latitude,
        longitude=longitude,
        preferred_distance=preferred_distance,
        favorite_cuisines=cuisines,
        mood=mood,
    )

    return {
        "latitude": latitude,
        "longitude": longitude,
        "mood": mood,
        "preferred_distance": preferred_distance,
        "favorite_cuisines": cuisines,
        "count": len(recommendations),
        "recommendations": recommendations,
    }


# =====================================================
# EXTRACT EXPLICIT BUDGET
# =====================================================

def extract_budget_from_query(
    user_query: str,
):
    """
    Detect an explicitly mentioned budget
    from natural language.

    Examples:

    under ₹300       -> 300
    below 500        -> 500
    within 400       -> 400
    budget of 250    -> 250
    less than ₹350   -> 350
    """

    if not user_query:
        return None

    text = user_query.lower()

    patterns = [

        # under ₹300 / under 300
        r"(?:under|below|less than|within|upto|up to)"
        r"\s*(?:₹|rs\.?|inr)?\s*([0-9]+(?:\.[0-9]+)?)",

        # ₹300 budget
        r"(?:₹|rs\.?|inr)\s*([0-9]+(?:\.[0-9]+)?)"
        r"\s*(?:budget)?",

        # budget of 300 / budget ₹300
        r"budget\s*(?:of)?\s*(?:₹|rs\.?|inr)?"
        r"\s*([0-9]+(?:\.[0-9]+)?)",
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            text,
        )

        if match:

            try:
                value = float(
                    match.group(1)
                )

                if value > 0:
                    return value

            except ValueError:
                pass

    return None


# =====================================================
# CLEAN AI RESPONSE
# =====================================================

def clean_ai_response(
    answer: str,
):
    """
    Prevent internal/debug text from appearing
    as the actual recommendation.
    """

    if not answer:
        return ""

    answer = answer.strip()

    unwanted_prefixes = [
        "user safety:",
        "safety:",
        "safe",
        "unsafe",
    ]

    lowered = answer.lower()

    for prefix in unwanted_prefixes:

        if lowered.startswith(prefix):

            lines = answer.splitlines()

            useful_lines = []

            for line in lines:

                if not line.lower().startswith(
                    tuple(unwanted_prefixes)
                ):
                    useful_lines.append(line)

            answer = "\n".join(
                useful_lines
            ).strip()

    return answer


# =====================================================
# EXPLICIT LOCATION EXTRACTION
# =====================================================

async def geocode_place(place: str) -> dict:
    """Resolve a user-mentioned place into coordinates using Nominatim."""
    url = "https://nominatim.openstreetmap.org/search"
    headers = {
        "User-Agent": "MoodMeal/1.0 (restaurant discovery app)"
    }
    params = {
        "format": "jsonv2",
        "q": place,
        "limit": 1,
    }

    async with httpx.AsyncClient(timeout=12.0) as client:
        response = await client.get(url, params=params, headers=headers)
        response.raise_for_status()
        results = response.json()

    if not results:
        return {}

    result = results[0]
    return {
        "place": place,
        "display_name": result.get("display_name", place),
        "latitude": float(result["lat"]),
        "longitude": float(result["lon"]),
    }


def extract_explicit_places(user_query: str) -> list[str]:
    """Extract arbitrary user-mentioned places from restaurant-search queries.

    This deliberately does not use a hard-coded list of neighborhoods. The
    extracted text is passed to Nominatim, which resolves it to coordinates.
    """
    text = re.sub(r"\s+", " ", (user_query or "")).strip()
    if not text:
        return []

    lowered = text.lower()
    restaurant_intent = re.search(
        r"\b(rest\w*|cafes?|places|food spots|dhabas?|eateries|dining|"
        r"nearby|near me|where to eat|recommendations?)\b",
        lowered,
    )
    if not restaurant_intent:
        return []

    # Find a location phrase after a natural-language location cue. The phrase
    # itself is unrestricted, so new towns/areas/landmarks need no code change.
    cue_patterns = [
        r"\b(?:near|nearby|around|close to|in|at|within)\s+(.+)$",
        r"\b(?:rest\w*|cafes?|food spots|dhabas?|eateries|places)\s+"
        r"(?:near|around|in|at|of)\s+(.+)$",
    ]
    candidate = ""
    for pattern in cue_patterns:
        matches = list(re.finditer(pattern, text, flags=re.IGNORECASE))
        if matches:
            # Prefer the last cue: e.g. "restaurants near X for dinner".
            candidate = matches[-1].group(1).strip()
            break

    if not candidate:
        return []

    # Remove conversational endings and non-location constraints while keeping
    # place names as the user typed them for geocoding.
    candidate = re.sub(r"[?.!,;]+$", "", candidate).strip()
    candidate = re.split(
        r"\b(?:please|suggest|recommend|show|find|give me|tell me|"
        r"something|options?|for dinner|for lunch|for breakfast|"
        r"under\s+₹?\s*\d+|within my budget|with ratings?)\b",
        candidate,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0].strip(" ,.;:-")

    # Multiple areas can be separated by 'and', '&', or commas. Keep this
    # dynamic and bounded to avoid sending an unbounded number of geocoding calls.
    parts = re.split(r"\s+(?:and|&)\s+|\s*,\s*", candidate, flags=re.IGNORECASE)
    places: list[str] = []
    for part in parts:
        part = part.strip(" .,'\"-:")
        part = re.sub(r"^(?:the area of|area of)\s+", "", part, flags=re.IGNORECASE)
        if len(part) >= 3 and part.lower() not in {"restaurant", "restaurants", "food", "places"}:
            if part.casefold() not in {p.casefold() for p in places}:
                places.append(part)
        if len(places) >= 3:
            break
    return places


# =====================================================
# AI RECOMMENDATION
# =====================================================

@app.get("/ai-recommendation")
async def ai_recommendation(
    user_query: str,
    mood: str,
    diet: str,
    cuisine: str,
    budget: float,
    latitude: float | None = None,
    longitude: float | None = None,
):

    # =================================================
    # VALIDATION
    # =================================================

    if not user_query.strip():

        raise HTTPException(
            status_code=400,
            detail="User query cannot be empty.",
        )

    if not mood.strip():

        raise HTTPException(
            status_code=400,
            detail="Mood cannot be empty.",
        )

    if not diet.strip():

        raise HTTPException(
            status_code=400,
            detail="Diet cannot be empty.",
        )

    if not cuisine.strip():

        raise HTTPException(
            status_code=400,
            detail="Cuisine cannot be empty.",
        )

    if budget <= 0:

        raise HTTPException(
            status_code=400,
            detail="Budget must be greater than 0.",
        )


    # =================================================
    # BUDGET DETECTION
    # =================================================

    explicit_budget = extract_budget_from_query(
        user_query
    )


    # =================================================
    # EFFECTIVE BUDGET
    # =================================================

    if explicit_budget is not None:

        effective_budget = explicit_budget

    else:

        effective_budget = budget


    # =================================================
    # DEBUG LOG
    # =================================================

    print(
        "\n============================"
    )

    print(
        "===== RAG REQUEST ====="
    )

    print(
        f"User Query: {user_query}"
    )

    print(
        f"Mood: {mood}"
    )

    print(
        f"Diet: {diet}"
    )

    print(
        f"Cuisine: {cuisine}"
    )

    print(
        f"Profile Budget: {budget}"
    )

    print(
        f"Explicit Budget: {explicit_budget}"
    )

    print(
        f"Effective Budget: {effective_budget}"
    )

    print(
        "========================"
    )


    # =================================================
    # RAG + LLM
    # =================================================

    try:

        answer = generate_rag_answer(

            user_query=user_query,

            mood=mood,

            diet=diet,

            cuisine=cuisine,

            budget=effective_budget,
        )

    except Exception as e:

        print(
            f"RAG ERROR: {e}",
            flush=True,
        )

        raise HTTPException(
            status_code=503,
            detail=(
                "AI recommendation service "
                "is temporarily unavailable."
            ),
        )


    # =================================================
    # CLEAN RESPONSE
    # =================================================

    answer = clean_ai_response(
        answer
    )


    # =================================================
    # OPTIONAL RESTAURANT RECOMMENDATIONS
    # Use explicitly mentioned areas when present; otherwise use GPS.
    # =================================================

    restaurants = []
    explicit_places = extract_explicit_places(user_query)
    search_points = []

    if explicit_places:
        for place in explicit_places:
            try:
                resolved = await geocode_place(place)
                if resolved:
                    search_points.append(resolved)
                else:
                    print(f"Could not resolve requested place: {place}", flush=True)
            except Exception as e:
                print(f"Geocoding failed for '{place}': {e}", flush=True)
    elif latitude is not None and longitude is not None:
        search_points.append({
            "place": "Current location",
            "latitude": latitude,
            "longitude": longitude,
        })

    # Search each requested area independently and merge duplicate results.
    seen_restaurants = set()
    for point in search_points:
        try:
            point_lat = point["latitude"]
            point_lon = point["longitude"]
            nearby_restaurants = await fetch_restaurants(
                latitude=point_lat,
                longitude=point_lon,
                radius_km=5,
            )
            ranked = recommend_restaurants(
                restaurants=nearby_restaurants,
                latitude=point_lat,
                longitude=point_lon,
                preferred_distance=5,
                favorite_cuisines=[cuisine] if cuisine.strip().lower() != "any" else [],
                mood=mood,
            )
            for restaurant in ranked:
                raw = restaurant.get("restaurant", restaurant)
                tags = raw.get("tags", {}) if isinstance(raw, dict) else {}
                name = restaurant.get("name") or tags.get("name") or ""
                raw_id = raw.get("id") if isinstance(raw, dict) else None
                dedupe_key = str(raw_id or name).strip().lower()
                if not dedupe_key or dedupe_key in seen_restaurants:
                    continue
                seen_restaurants.add(dedupe_key)
                restaurant["matched_area"] = point.get("place", "Nearby")
                restaurants.append(restaurant)
        except Exception as e:
            print(
                f"Restaurant recommendation error for {point.get('place', 'location')}: {e}",
                flush=True,
            )

    # Keep the response concise and predictable for the Flutter UI.
    restaurants = restaurants[:10]


    # =================================================
    # FINAL RESPONSE
    # =================================================

    return {

        "user_query": user_query,

        "mood": mood,

        "diet": diet,

        "cuisine": cuisine,

        "profile_budget": budget,

        "explicit_budget": explicit_budget,

        "budget": effective_budget,

        "recommendation": answer,

        "restaurants": restaurants,

        "restaurant_count": len(
            restaurants
        ),
    }