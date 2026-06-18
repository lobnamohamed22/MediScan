from app import create_app
import json

app = create_app()
client = app.test_client()

# We need a JWT token to access the route. Let's log in first.
# Wait, we can bypass @jwt_required() or we can generate a mock token.
from flask_jwt_extended import create_access_token

with app.app_context():
    token = create_access_token(identity='1') # mock user id

headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

data = {
    'names': ['Panadol'],
    'pharmacy_id': '1'
}

response = client.post('/api/medicines/resolve_prices', headers=headers, data=json.dumps(data))
print("STATUS:", response.status_code)
print("RESPONSE:", json.loads(response.data.decode('utf-8')))
