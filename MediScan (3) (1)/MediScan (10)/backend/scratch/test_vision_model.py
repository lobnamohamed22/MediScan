import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo, MedicineInventory

app = create_app()

with app.app_context():
    # Fetch candidates for matching
    inventory_candidates = db.session.query(
        MedicineInventory.medicine_name,
        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
        db.func.avg(MedicineInventory.price).label('avg_price')
    ).group_by(MedicineInventory.medicine_name).all()
    inventory_info = [(r[0], int(r[1]) if r[1] is not None else 0, float(r[2]) if r[2] is not None else 0.0) for r in inventory_candidates if r[0]]
    info_names = [r[0] for r in db.session.query(MedicineInfo.medicine_name).distinct().all() if r[0]]

print(f"Total catalog names: {len(info_names)}")
print(f"Total inventory items: {len(inventory_info)}")

# Find prescription files in uploads/prescriptions
presc_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\uploads\prescriptions"
if os.path.exists(presc_dir):
    files = [f for f in os.listdir(presc_dir) if f.lower().endswith(('.jpg', '.png', '.jpeg'))]
    print(f"Found {len(files)} prescription images: {files}")
else:
    print("uploads/prescriptions directory does not exist")
