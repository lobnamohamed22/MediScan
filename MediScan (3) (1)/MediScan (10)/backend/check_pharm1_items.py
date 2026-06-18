from app import create_app
from extensions import db
from models.medicine import MedicineInventory

app = create_app()
with app.app_context():
    items = MedicineInventory.query.filter(MedicineInventory.pharmacy_id == '1').all()
    print(f"Total items in Pharmacy 1: {len(items)}")
    for item in items:
        if 'panadol' in item.medicine_name.lower():
            print(f"Name: {item.medicine_name}, Price: {item.price}, Stock: {item.stock_quantity}")
