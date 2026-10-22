import asyncio
import httpx


# Public Overpass instances. If one is overloaded, the next one is tried.
OVERPASS_SERVERS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

TRANSIENT_STATUS_CODES = {429, 500, 502, 503, 504}


async def fetch_restaurants(
    latitude: float,
    longitude: float,
    radius_km: float,
):
    """Fetch real OSM restaurant/cafe/fast-food records near coordinates.

    Returns raw Overpass elements. It never fabricates restaurant names.
    """
    if not (-90 <= latitude <= 90):
        raise ValueError("Latitude must be between -90 and 90.")
    if not (-180 <= longitude <= 180):
        raise ValueError("Longitude must be between -180 and 180.")
    if radius_km <= 0:
        raise ValueError("Radius must be greater than 0 km.")

    radius_meters = int(radius_km * 1000)
    if radius_meters > 50000:
        raise ValueError("Maximum search radius is 50 km.")

    # Keep the query focused to reduce load on public Overpass servers.
    query = f"""
    [out:json][timeout:25];
    (
      nwr[\"amenity\"=\"restaurant\"](around:{radius_meters},{latitude},{longitude});
      nwr[\"amenity\"=\"cafe\"](around:{radius_meters},{latitude},{longitude});
      nwr[\"amenity\"=\"fast_food\"](around:{radius_meters},{latitude},{longitude});
    );
    out center tags;
    """

    headers = {
        "User-Agent": "MoodMeal/1.0 (restaurant discovery app)",
        "Accept": "application/json",
    }
    last_error = "No Overpass server responded."

    # One attempt per server, then a single retry cycle for temporary overloads.
    for cycle in range(2):
        for server in OVERPASS_SERVERS:
            try:
                timeout = httpx.Timeout(40.0, connect=10.0)
                async with httpx.AsyncClient(timeout=timeout) as client:
                    response = await client.post(
                        server,
                        data={"data": query},
                        headers=headers,
                    )

                if response.status_code == 200:
                    try:
                        payload = response.json()
                    except ValueError:
                        last_error = f"Overpass returned invalid JSON from {server}."
                        continue

                    elements = payload.get("elements", [])
                    if not isinstance(elements, list):
                        last_error = f"Unexpected Overpass response from {server}."
                        continue
                    # An empty list is a valid result, not a server failure.
                    return elements

                last_error = f"Overpass returned HTTP {response.status_code} from {server}."
                if response.status_code not in TRANSIENT_STATUS_CODES:
                    continue

            except httpx.TimeoutException:
                last_error = f"Overpass timed out at {server}."
            except httpx.RequestError as exc:
                last_error = f"Overpass connection failed at {server}: {exc}"

        if cycle == 0:
            await asyncio.sleep(1.5)

    raise RuntimeError(
        "Unable to load restaurants after trying all Overpass servers. "
        f"Last error: {last_error}"
    )
