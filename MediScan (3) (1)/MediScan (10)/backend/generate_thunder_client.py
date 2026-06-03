import json
import uuid

# Define the base URL for the backend
BASE_URL = "http://127.0.0.1:5000"

def generate_thunder_client_collection():
    collection_id = str(uuid.uuid4())
    
    collection = {
        "clientName": "Thunder Client",
        "collectionName": "MediScan APIs Collection",
        "collectionId": collection_id,
        "dateExported": "2026-05-12T00:00:00.000Z",
        "version": "1.2",
        "folders": [],
        "requests": []
    }

    folders = [
        {"id": str(uuid.uuid4()), "name": "Auth", "prefix": "/api/auth"},
        {"id": str(uuid.uuid4()), "name": "Users", "prefix": "/api/users"},
        {"id": str(uuid.uuid4()), "name": "Prescriptions", "prefix": "/api/prescriptions"},
        {"id": str(uuid.uuid4()), "name": "Pharmacies", "prefix": "/api/pharmacies"},
        {"id": str(uuid.uuid4()), "name": "Medicines", "prefix": "/api/medicines"},
        {"id": str(uuid.uuid4()), "name": "Orders", "prefix": "/api/orders"},
        {"id": str(uuid.uuid4()), "name": "Chatbot", "prefix": "/api/chatbot"},
        {"id": str(uuid.uuid4()), "name": "General", "prefix": ""}
    ]
    
    for idx, f in enumerate(folders):
        collection["folders"].append({
            "_id": f["id"],
            "name": f["name"],
            "containerId": "",
            "created": "2026-05-12T00:00:00.000Z",
            "sortNum": (idx + 1) * 10000
        })

    endpoints = [
        {"name": "Home", "url": "/", "method": "GET", "folder": "General"},
        {"name": "Ping", "url": "/ping", "method": "GET", "folder": "General"},
        {"name": "Login", "url": "/api/auth/login", "method": "POST", "folder": "Auth", "body": {"email": "test@example.com", "password": "password"}},
        {"name": "Register", "url": "/api/auth/register", "method": "POST", "folder": "Auth", "body": {"name": "Test User", "email": "test@example.com", "password": "password", "phone": "01000000000", "role": "patient"}},
        {"name": "Get Profile", "url": "/api/users/profile", "method": "GET", "folder": "Users"},
        {"name": "Update Profile", "url": "/api/users/profile", "method": "PATCH", "folder": "Users", "body": {"name": "New Name"}},
        {"name": "Get Prescriptions", "url": "/api/prescriptions/", "method": "GET", "folder": "Prescriptions"},
        {"name": "Upload Prescription", "url": "/api/prescriptions/upload", "method": "POST", "folder": "Prescriptions"},
        {"name": "List Pharmacies", "url": "/api/pharmacies/", "method": "GET", "folder": "Pharmacies"},
        {"name": "Search Medicines", "url": "/api/medicines/search", "method": "GET", "folder": "Medicines"},
        {"name": "Create Order", "url": "/api/orders/", "method": "POST", "folder": "Orders"},
        {"name": "Get User Orders", "url": "/api/orders/user", "method": "GET", "folder": "Orders"},
        {"name": "Chatbot Chat", "url": "/api/chatbot/chat", "method": "POST", "folder": "Chatbot", "body": {"message": "Hello, I have a headache"}}
    ]

    sort_counter = 10000
    for ep in endpoints:
        folder_id = next((f["id"] for f in folders if f["name"] == ep["folder"]), "")
        
        req = {
            "_id": str(uuid.uuid4()),
            "colId": collection_id,
            "containerId": folder_id,
            "name": ep["name"],
            "url": BASE_URL + ep["url"],
            "method": ep["method"],
            "sortNum": sort_counter,
            "created": "2026-05-12T00:00:00.000Z",
            "modified": "2026-05-12T00:00:00.000Z",
            "headers": []
        }
        
        if "body" in ep:
            req["headers"].append({"name": "Content-Type", "value": "application/json"})
            req["body"] = {
                "type": "json",
                "raw": json.dumps(ep["body"], indent=2),
                "form": []
            }
        
        # Add Authorization header for typical secure endpoints
        if ep["name"] not in ["Home", "Ping", "Login", "Register"]:
            req["headers"].append({"name": "Authorization", "value": "Bearer YOUR_JWT_TOKEN_HERE"})
            
        collection["requests"].append(req)
        sort_counter += 10000

    with open("thunder-collection_mediscan.json", "w") as f:
        json.dump(collection, f, indent=4)

if __name__ == "__main__":
    generate_thunder_client_collection()
    print("Generated thunder-collection_mediscan.json")
