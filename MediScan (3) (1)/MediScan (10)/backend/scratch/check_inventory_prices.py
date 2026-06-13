import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.medicine import MedicineInventory
from models.pharmacy import Pharmacy

app = create_app()

with app.app_context():
    inventory = MedicineInventory.query.all()
    print(f"Total inventory items: {len(inventory)}")
    for item in inventory[:30]:
        pharmacy = Pharmacy.query.get(item.pharmacy_id)
        p_name = pharmacy.name if pharmacy else "Unknown"
        print(f"Pharmacy: {p_name} | Med: {item.medicine_name} | Price: {item.price} | Stock: {item.stock_quantity}")
