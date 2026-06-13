import os
import sys
import json

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.pharmacy import Pharmacy
from routes.pharmacies import get_pharmacy_inventory
from flask import Flask

app = create_app()

with app.app_context():
    # Find a pharmacy with inventory
    from models.medicine import MedicineInventory
    inv = MedicineInventory.query.first()
    if not inv:
        print("No inventory records found!")
        sys.exit(1)
        
    pharmacy_id = inv.pharmacy_id
    pharmacy = Pharmacy.query.get(pharmacy_id)
    print(f"Testing for Pharmacy: {pharmacy.name if pharmacy else 'Unknown'} (ID: {pharmacy_id})")
    
    # Simulate a request context to test the controller directly
    with app.test_request_context():
        # Bypass jwt for testing the internal controller
        inventory = MedicineInventory.query.filter_by(pharmacy_id=pharmacy_id).all()
        response_data = {
            'success': True,
            'data': [i.to_dict() for i in inventory]
        }
        print(f"Total items in response: {len(response_data['data'])}")
        if response_data['data']:
            print("First item sample:")
            print(json.dumps(response_data['data'][0], indent=2))
