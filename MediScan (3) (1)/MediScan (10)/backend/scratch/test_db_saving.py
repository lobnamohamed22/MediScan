import os
import sys
import uuid
import json

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.prescription import Prescription, PrescriptionMedicine
from models.medicine import MedicineInfo, MedicineInventory
from routes.prescriptions import find_best_inventory_match, find_best_catalog_match

app = create_app()

extracted_medicines = [
  {
    "medicine_name": "Conventa",
    "dosage": "100mg",
    "frequency": "Twice daily",
    "duration_days": 10,
    "quantity": 1
  },
  {
    "medicine_name": "Recoxibright",
    "dosage": "90mg",
    "frequency": "Once daily",
    "duration_days": 10,
    "quantity": 1
  },
  {
    "medicine_name": "Sulfox gel",
    "dosage": None,
    "frequency": "As directed",
    "duration_days": 7,
    "quantity": 1
  },
  {
    "medicine_name": "Venusen Compression Stocking",
    "dosage": "Class II, XL, Below Knee",
    "frequency": None,
    "duration_days": None,
    "quantity": 1
  }
]

with app.app_context():
    # Fetch user id
    from models.user import User
    user = User.query.filter_by(role='patient').first()
    if not user:
        print("No patient user found!")
        sys.exit(1)
        
    user_id = user.user_id
    
    inventory_candidates = db.session.query(
        MedicineInventory.medicine_name,
        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
        db.func.avg(MedicineInventory.price).label('avg_price')
    ).group_by(MedicineInventory.medicine_name).all()
    inventory_info = [(r[0], int(r[1]) if r[1] is not None else 0, float(r[2]) if r[2] is not None else 0.0) for r in inventory_candidates if r[0]]
    info_names = [r[0] for r in db.session.query(MedicineInfo.medicine_name).distinct().all() if r[0]]
    
    prescription_id = str(uuid.uuid4())
    print(f"Creating test prescription: {prescription_id}")
    
    new_prescription = Prescription(
        prescription_id=prescription_id,
        user_id=user_id,
        image_url='/uploads/prescriptions/test_sim.jpg',
        status='processed',
        extracted_text=json.dumps([m.get('medicine_name', '').strip() for m in extracted_medicines if m.get('medicine_name')])
    )
    db.session.add(new_prescription)
    
    resolved_medicines = []
    for med in extracted_medicines:
        raw_name = med.get('medicine_name', '').strip()
        qty = med.get('quantity') or 1
        
        matched_name = find_best_inventory_match(raw_name, inventory_info) or find_best_catalog_match(raw_name, info_names)
        resolved_name = matched_name if matched_name else raw_name
        
        pm = PrescriptionMedicine(
            id=str(uuid.uuid4()),
            prescription_id=prescription_id,
            medicine_name=resolved_name,
            dosage=med.get('dosage'),
            frequency=med.get('frequency'),
            duration_days=med.get('duration_days'),
            quantity=qty
        )
        db.session.add(pm)
        resolved_medicines.append(resolved_name)
        
    db.session.commit()
    print("Database commit successful!")
    
    # Query back
    p_check = Prescription.query.get(prescription_id)
    print(f"Prescription Extracted Text: {p_check.extracted_text}")
    print(f"Prescription Medicines in DB: {[m.medicine_name for m in p_check.medicines_list]}")
    
    # Clean up
    for m in p_check.medicines_list:
        db.session.delete(m)
    db.session.delete(p_check)
    db.session.commit()
    print("Cleanup successful!")
