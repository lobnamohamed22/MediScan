from app import create_app
from models.pharmacy import Pharmacy
from flask_jwt_extended import create_access_token
import json

app = create_app()
client = app.test_client()

with app.app_context():
    token = create_access_token(identity='1')
    pharmacies = Pharmacy.query.all()

headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

print("=== RESOLVING PRICES FOR PANADOL ACROSS ALL PHARMACIES ===")
for p in pharmacies[:15]:  # print first 15 pharmacies
    data = {
        'names': ['Panadol'],
        'pharmacy_id': p.pharmacy_id
    }
    response = client.post('/api/medicines/resolve_prices', headers=headers, data=json.dumps(data))
    res = json.loads(response.data.decode('utf-8'))
    if res.get('success'):
        med = res['data'][0]
        print(f"Pharm ID: {p.pharmacy_id}, Name: {p.name}, Resolved Price: {med['price']}, Available: {med['available']}")
    else:
        print(f"Pharm ID: {p.pharmacy_id}, Name: {p.name}, Failed: {res.get('message')}")
