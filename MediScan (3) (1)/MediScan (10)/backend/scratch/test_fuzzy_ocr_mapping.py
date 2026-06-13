import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo, MedicineInventory
from routes.prescriptions import calculate_similarity, find_best_inventory_match

app = create_app()

with app.app_context():
    print("Testing calculate_similarity:")
    print(f"Conventu vs Conventin 100mg: {calculate_similarity('Conventu', 'Conventin 100mg')}")
    print(f"Recoribright 90mg vs Recoxibright 90mg: {calculate_similarity('Recoribright 90mg', 'Recoxibright 90mg')}")

    print("\nSimulating candidates where 'Conventu' and 'Recoribright 90mg' DO NOT exist:")
    
    # Get distinct inventory names
    candidates_raw = db.session.query(
        MedicineInventory.medicine_name,
        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
        db.func.avg(MedicineInventory.price).label('avg_price')
    ).group_by(MedicineInventory.medicine_name).all()
    
    candidates_info = []
    for r in candidates_raw:
        if r[0] and r[0] not in ["Conventu", "Recoribright 90mg"]:
            candidates_info.append((r[0], int(r[1]) if r[1] is not None else 0, float(r[2]) if r[2] is not None else 0.0))
            
    print(f"Filtered candidate list count: {len(candidates_info)}")
    
    scanned_names = ["Conventu", "Recoribright 90mg"]
    for raw_name in scanned_names:
        matched = find_best_inventory_match(raw_name, candidates_info)
        print(f"Scanned name: '{raw_name}' matched to database inventory name: '{matched}'")
        
        # Check catalog info
        if matched:
            info = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched)).first()
            if info:
                print(f"  Catalog image: {info.medicine_image}")
                print(f"  Catalog status: {info.status}")
                
            # Get inventory pricing
            prices = [c[2] for c in candidates_info if c[0] == matched]
            print(f"  Average inventory price: {prices}")
