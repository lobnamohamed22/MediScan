import requests

def test_overpass(lat, lng, radius_meters=5000):
    url = "https://overpass-api.de/api/interpreter"
    query = f"""
    [out:json][timeout:15];
    (
      node["amenity"="pharmacy"](around:{radius_meters},{lat},{lng});
      way["amenity"="pharmacy"](around:{radius_meters},{lat},{lng});
    );
    out center;
    """
    headers = {"User-Agent": "MediScanApp/1.0 (contact: support@mediscan.com)"}
    try:
        response = requests.post(url, data={"data": query}, headers=headers)
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            elements = data.get("elements", [])
            print(f"Found {len(elements)} pharmacies")
            for elem in elements[:5]:
                tags = elem.get("tags", {})
                name = tags.get("name", "Unnamed Pharmacy")
                lat_val = elem.get("lat") or elem.get("center", {}).get("lat")
                lng_val = elem.get("lon") or elem.get("center", {}).get("lon")
                print(f"Name: {name} | Lat: {lat_val} | Lng: {lng_val} | Address: {tags.get('addr:street', 'N/A')}")
        else:
            print(response.text)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Test coordinates in Cairo: 30.0444, 31.2357
    test_overpass(30.0444, 31.2357, 5000)
