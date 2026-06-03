import os
import sys
import shutil
import glob

# Add backend to python path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

ARTIFACT_DIR = r"C:\Users\lenovo\.gemini\antigravity\brain\b191a347-2f25-473e-9114-9844328dbf6d"
BACKEND_UPLOADS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
MEDICINES_DIR = os.path.join(BACKEND_UPLOADS, "medicines")

def copy_medicine_images():
    print("--- Creating medicines uploads directory if it does not exist ---")
    os.makedirs(MEDICINES_DIR, exist_ok=True)
    print(f"Directory ready at: {MEDICINES_DIR}")
    
    mapping = {
        "conventin": "conventin_package_*.png",
        "recoxibright": "recoxibright_package_*.png",
        "sulfox": "sulfox_package_*.png"
    }
    
    copied = {}
    
    for key, pattern in mapping.items():
        search_path = os.path.join(ARTIFACT_DIR, pattern)
        files = glob.glob(search_path)
        if files:
            # Get the latest one if multiple
            files.sort(key=os.path.getmtime, reverse=True)
            source_file = files[0]
            dest_file = os.path.join(MEDICINES_DIR, f"{key}.png")
            shutil.copy(source_file, dest_file)
            print(f"Copied: {os.path.basename(source_file)} -> {key}.png")
            copied[key] = f"/uploads/medicines/{key}.png"
        else:
            print(f"Warning: No files found matching {pattern} in {ARTIFACT_DIR}")
            
    return copied

def seed_database_images(urls):
    if not urls:
        print("No image URLs to update.")
        return
        
    print("\n--- Updating medicine_info database records ---")
    
    # 1. Update Conventin and its variants
    conventin_variants = [
        "Conventu", "Convenntu 100mg", "Conventus", 
        "Convenia 100mg", "Conventin 100mg", "Conventin"
    ]
    conventin_url = urls.get("conventin")
    
    # 2. Update Recoxibright and its variants
    recoxibright_variants = [
        "Recoxibright", "Recoribright 90mg", "Recoxibright 90mg", 
        "Recoribright", "Recoxibright"
    ]
    recoxibright_url = urls.get("recoxibright")
    
    # 3. Update Sulfox / Sulfax and variants
    sulfox_variants = [
        "Sulfox", "Sulfora gel", "Sulfoa gel", 
        "Sulfiox gel", "Sulfax Gel", "Sulfax"
    ]
    sulfox_url = urls.get("sulfox")
    
    updated_count = 0
    
    # Update explicitly matched variants and fuzzy matches
    all_meds = MedicineInfo.query.all()
    for m in all_meds:
        med_name = m.medicine_name.strip()
        med_name_lower = med_name.lower()
        
        # Determine if it matches Conventin
        is_conventin = any(v.lower() in med_name_lower or med_name_lower in v.lower() for v in conventin_variants) or "convent" in med_name_lower
        # Determine if it matches Recoxibright
        is_recoxibright = any(v.lower() in med_name_lower or med_name_lower in v.lower() for v in recoxibright_variants) or "recox" in med_name_lower or "recori" in med_name_lower
        # Determine if it matches Sulfox/Sulfax
        is_sulfox = any(v.lower() in med_name_lower or med_name_lower in v.lower() for v in sulfox_variants) or "sulf" in med_name_lower
        
        if is_conventin and conventin_url:
            m.medicine_image = conventin_url
            print(f"Updated record ID {m.id} | Name: '{m.medicine_name}' -> Conventin Image")
            updated_count += 1
        elif is_recoxibright and recoxibright_url:
            m.medicine_image = recoxibright_url
            print(f"Updated record ID {m.id} | Name: '{m.medicine_name}' -> Recoxibright Image")
            updated_count += 1
        elif is_sulfox and sulfox_url:
            m.medicine_image = sulfox_url
            print(f"Updated record ID {m.id} | Name: '{m.medicine_name}' -> Sulfox Image")
            updated_count += 1
            
    db.session.commit()
    print(f"\nSuccessfully updated {updated_count} medicine records in the database with their correct image URLs!")

if __name__ == "__main__":
    with app.app_context():
        urls = copy_medicine_images()
        seed_database_images(urls)
