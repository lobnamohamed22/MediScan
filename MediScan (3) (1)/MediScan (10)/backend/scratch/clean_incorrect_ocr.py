import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.prescription import Prescription, PrescriptionMedicine

app = create_app()

with app.app_context():
    prescs = Prescription.query.all()
    deleted_count = 0
    for p in prescs:
        meds = [m.medicine_name for m in p.medicines_list]
        is_venusen = any('venusen' in m.lower() or 'venosen' in m.lower() for m in meds)
        
        # If it contains Venusen but has fewer than 4 medicines, OR has fewer than 2 medicines total
        should_delete = False
        reason = ""
        if is_venusen and len(meds) < 4:
            should_delete = True
            reason = f"contains Venusen but has only {len(meds)} medicines"
        elif len(meds) <= 1:
            # Check if it's the e2e test one (we should keep or delete depending)
            if len(meds) == 1 and meds[0] == "E2ETestMedicine":
                continue
            should_delete = True
            reason = f"has only {len(meds)} medicines"
            
        if should_delete:
            print(f"Deleting prescription {p.prescription_id} (Image: {p.image_url}) - Reason: {reason}")
            # Delete children
            PrescriptionMedicine.query.filter_by(prescription_id=p.prescription_id).delete()
            db.session.delete(p)
            deleted_count += 1
            
    db.session.commit()
    print(f"Successfully deleted {deleted_count} incomplete prescriptions.")
