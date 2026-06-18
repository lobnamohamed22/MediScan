from app import create_app
from extensions import db
from models.medicine import MedicineInfo, MedicineInventory
from routes.prescriptions import calculate_similarity
import re
import os
import datetime

app = create_app()
with app.app_context():
    names = ['Panadol']
    pharmacy_id = '1'

    resolved = []
    total_price = 0.0

    def get_global_avg_price(med_name):
        g_prices = db.session.query(MedicineInventory.price).filter(
            MedicineInventory.medicine_name.ilike(med_name),
            MedicineInventory.price > 0
        ).all()
        print(f"  get_global_avg_price('{med_name}') - direct matches count: {len(g_prices)}")
        if g_prices:
            return sum(float(p[0]) for p in g_prices) / len(g_prices)
        
        all_prices = db.session.query(
            MedicineInventory.medicine_name,
            db.func.avg(MedicineInventory.price)
        ).filter(
            MedicineInventory.price > 0
        ).group_by(MedicineInventory.medicine_name).all()
        
        best_ratio = 0.0
        best_price = 0.0
        for c in all_prices:
            ratio = calculate_similarity(med_name, c[0])
            if ratio > best_ratio:
                best_ratio = ratio
                best_price = float(c[1])
        print(f"  get_global_avg_price('{med_name}') - best fuzzy ratio: {best_ratio} for '{c[0]}' with price {best_price}")
        if best_ratio >= 0.70:
            return best_price
        return 30.0

    for raw_name in names:
        name_clean = raw_name.strip()
        qty = 1
        match = re.search(r'\s+x(\d+)$', name_clean, re.IGNORECASE)
        if match:
            qty = int(match.group(1))
            name_clean = name_clean[:match.start()].strip()

        matched_name = None
        avg_price = 0.0
        total_stock = 0
        available = False
        matched = False
        is_pending = False
        medicine_image = ''

        if pharmacy_id:
            inv_matches = MedicineInventory.query.filter(
                MedicineInventory.pharmacy_id == pharmacy_id,
                MedicineInventory.medicine_name.ilike(name_clean)
            ).all()
            print(f"Pharmacy {pharmacy_id} exact inv_matches for '{name_clean}': {inv_matches}")
            
            if not inv_matches:
                all_pharm_inv = MedicineInventory.query.filter(
                    MedicineInventory.pharmacy_id == pharmacy_id
                ).all()
                best_ratio = 0.0
                pharmacy_match = None
                for item in all_pharm_inv:
                    ratio = calculate_similarity(name_clean, item.medicine_name)
                    if ratio > best_ratio:
                        best_ratio = ratio
                        pharmacy_match = item
                if best_ratio >= 0.70 and pharmacy_match:
                    inv_matches = [pharmacy_match]
                print(f"Pharmacy {pharmacy_id} fuzzy inv_matches for '{name_clean}': {inv_matches} (ratio: {best_ratio})")
            
            if inv_matches:
                matched = True
                matched_name = inv_matches[0].medicine_name
                total_stock = sum(int(r.stock_quantity) if r.stock_quantity is not None else 0 for r in inv_matches)
                valid_prices = [float(r.price) for r in inv_matches if r.price is not None and r.price > 0]
                if valid_prices:
                    avg_price = sum(valid_prices) / len(valid_prices)
                    available = total_stock > 0
                else:
                    avg_price = get_global_avg_price(matched_name)
                    available = False
                    total_stock = 0
        else:
            print("No pharmacy_id provided")

        if matched and matched_name:
            print(f"Matched in inventory! display_name = {matched_name}")
            info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched_name)).first()
            display_name = info_item.medicine_name if info_item else matched_name
            is_pending = info_item.status == 'Pending Verification' if info_item else False
            medicine_image = info_item.medicine_image if info_item else ''
        else:
            print("Not matched in inventory, checking catalog...")
            info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
            if info_item:
                print(f"Found in catalog (MedicineInfo) under name: {info_item.medicine_name}")
                matched = True
                display_name = info_item.medicine_name
                is_pending = info_item.status == 'Pending Verification'
                medicine_image = info_item.medicine_image or ''
                avg_price = get_global_avg_price(display_name)
                total_stock = 0
                available = False
            else:
                print("Not found in catalog! Creating...")
                display_name = name_clean
                avg_price = 30.0

        print(f"RESULT: name_clean={name_clean}, display_name={display_name}, avg_price={avg_price}, matched={matched}, available={available}")
