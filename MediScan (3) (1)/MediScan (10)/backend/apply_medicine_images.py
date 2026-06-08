import os
import sys
import shutil

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo
from utils.images import resolve_medicine_image_path

app = create_app()

def run_migration():
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    uploads_dir = os.path.join(backend_dir, "uploads")
    meds_dir = os.path.join(uploads_dir, "medicines")
    
    os.makedirs(meds_dir, exist_ok=True)
    print(f"Medicines dir ready at: {meds_dir}", flush=True)
    
    # 1. Copy generated Ibuprofen package image
    ibuprofen_source = r"C:\Users\lenovo\.gemini\antigravity\brain\9538e91d-65bb-4a10-9898-6af94e47122d\ibuprofen_package_1780375951156.png"
    ibuprofen_dest = os.path.join(meds_dir, "ibuprofen.png")
    if os.path.exists(ibuprofen_source):
        shutil.copy(ibuprofen_source, ibuprofen_dest)
        print(f"Copied Ibuprofen image: {ibuprofen_source} -> {ibuprofen_dest}", flush=True)
    else:
        print(f"Warning: Ibuprofen source file not found at {ibuprofen_source}", flush=True)
        
    # 2. Copy panadol.png to paracetamol.png
    panadol_path = os.path.join(meds_dir, "panadol.png")
    paracetamol_path = os.path.join(meds_dir, "paracetamol.png")
    if os.path.exists(panadol_path):
        shutil.copy(panadol_path, paracetamol_path)
        print(f"Copied Paracetamol image: {panadol_path} -> {paracetamol_path}", flush=True)
        
    # 3. Copy sulfox.png to sulfax.png
    sulfox_path = os.path.join(meds_dir, "sulfox.png")
    sulfax_path = os.path.join(meds_dir, "sulfax.png")
    if os.path.exists(sulfox_path):
        shutil.copy(sulfox_path, sulfax_path)
        print(f"Copied Sulfax image: {sulfox_path} -> {sulfax_path}", flush=True)
        
    # 3b. Copy generated Venusen Stocking package image
    stocking_source = r"C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d\venusen_stockings_1780852855800.png"
    stocking_dest = os.path.join(meds_dir, "venusen.png")
    if os.path.exists(stocking_source):
        shutil.copy(stocking_source, stocking_dest)
        print(f"Copied Venusen stocking image: {stocking_source} -> {stocking_dest}", flush=True)
    else:
        print(f"Warning: Venusen source file not found at {stocking_source}", flush=True)
        
    # 4. Loop through and update database records
    print("\n--- Updating database records in medicine_info ---", flush=True)
    meds = MedicineInfo.query.all()
    total_meds = len(meds)
    print(f"Total medicines to process: {total_meds}", flush=True)
    
    updated_count = 0
    for idx, m in enumerate(meds, start=1):
        old_image = m.medicine_image
        
        # Optimize: If it's a local verified drug, match it. 
        # If it's another drug, only run DailyMed query if the image is currently None or generic_pill
        name_lower = m.medicine_name.lower().strip()
        is_local_verified = any(k in name_lower for k in [
            'paracetamol', 'panadol', 'ibuprofen', 'brufen', 'amoxicillin', 'amoxil', 
            'amoxycillin', 'augmentin', 'conventin', 'gabapentin', 'nexium', 'esomeprazole',
            'recoxibright', 'etoricoxib', 'sulfax', 'sulfox'
        ])
        
        # Force re-evaluation of all images to purge chemical structures and other invalid images
        # previously stored in the database.
        pass
            
        print(f"[{idx}/{total_meds}] Resolving image for '{m.medicine_name}'...", flush=True)
        new_image = resolve_medicine_image_path(m.medicine_name, uploads_dir)
        
        # Clean up absolute URL prefixes
        if new_image and 'uploads/medicines' in new_image:
            idx_uploads = new_image.find('/uploads/')
            if idx_uploads != -1:
                new_image = new_image[idx_uploads:]
                
        if old_image != new_image:
            m.medicine_image = new_image
            print(f"  -> Updated: '{old_image}' -> '{new_image}'", flush=True)
            updated_count += 1
            
    db.session.commit()
    print(f"\nSuccessfully migrated {updated_count} records in medicine_info!", flush=True)

if __name__ == "__main__":
    with app.app_context():
        run_migration()
