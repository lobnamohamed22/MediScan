import sys
import os
from datetime import datetime, timedelta
import random

# Add backend to python path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo, MedicineInventory
from models.pharmacy import Pharmacy

app = create_app()

MEDICINES_DATA = [
    {
        "medicine_name": "Panadol Extra",
        "generic_name": "Paracetamol + Caffeine",
        "medicine_image": None,
        "uses": "Mild to moderate pain relief (headache, migraine, sore throat, toothache, muscle aches, and fever).",
        "dosage_adult": "1 to 2 tablets every 4 to 6 hours as needed (Maximum 8 tablets daily).",
        "dosage_child": "Not recommended for children under 12 years.",
        "side_effects": "Insomnia, restlessness, mild dizziness, or skin rash in extremely rare cases.",
        "interactions": "Do not take with other paracetamol-containing products or excessive caffeine intake.",
        "contraindications": "Hypersensitivity to paracetamol or caffeine. Severe liver or kidney impairment.",
        "price": 40.0,
        "is_prescription_required": False
    },
    {
        "medicine_name": "Solpadeine Active",
        "generic_name": "Paracetamol + Caffeine + Codeine",
        "medicine_image": None,
        "uses": "Short-term relief of acute moderate pain (migraine, dental pain, dysmenorrhea, backache) not relieved by other analgesics alone.",
        "dosage_adult": "1 to 2 tablets dissolved in a glass of water every 4 to 6 hours (Maximum 8 tablets daily).",
        "dosage_child": "Contraindicated in children under 12 years. Not recommended for adolescents 12-18 years with respiratory issues.",
        "side_effects": "Constipation, drowsiness, nausea, dependency risk if used continuously for more than 3 days.",
        "interactions": "Enhanced sedative effect with alcohol, antidepressants, or other opioids.",
        "contraindications": "Respiratory depression, acute asthma, children who have undergone tonsillectomy.",
        "price": 65.5,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Conventin 100mg",
        "generic_name": "Gabapentin",
        "medicine_image": "http://10.0.2.2:5000/uploads/medicines/conventin.png",
        "uses": "Neuropathic pain (nerve damage pain due to shingles, diabetes) and as adjunctive therapy in partial seizures.",
        "dosage_adult": "Initially 300mg on day 1, titrated up to 900mg-1800mg daily in 3 divided doses.",
        "dosage_child": "Use only as directed by a specialist pediatric neurologist.",
        "side_effects": "Dizziness, somnolence, peripheral edema (fluid retention in limbs), fatigue, and dry mouth.",
        "interactions": "Antacids containing aluminum or magnesium may reduce Gabapentin absorption by 20%.",
        "contraindications": "Hypersensitivity to Gabapentin. History of depression or suicidal ideation requires close monitoring.",
        "price": 120.0,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Recoxibright 90mg",
        "generic_name": "Etoricoxib",
        "medicine_image": "http://10.0.2.2:5000/uploads/medicines/recoxibright.png",
        "uses": "Symptomatic relief of osteoarthritis, rheumatoid arthritis, ankylosing spondylitis, and acute gouty arthritis pain.",
        "dosage_adult": "Osteoarthritis: 60mg once daily. Rheumatoid arthritis: 90mg once daily. Acute gout: 120mg once daily (Max 8 days).",
        "dosage_child": "Contraindicated in children and adolescents under 16 years.",
        "side_effects": "Fluid retention, elevated blood pressure, headache, heart palpitations, dyspepsia, or flatulence.",
        "interactions": "Increases plasma concentration of oral contraceptives, methotrexate, and lithium.",
        "contraindications": "Active peptic ulcer, severe hepatic/renal impairment, ischemic heart disease, peripheral arterial disease.",
        "price": 145.0,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Sulfax Gel",
        "generic_name": "Cetyl Myristoleate + Glucosamine + MSM",
        "medicine_image": "http://10.0.2.2:5000/uploads/medicines/sulfox.png",
        "uses": "Topical joint massage gel formulated to relieve stiffness, reduce joint swelling, and support flexible movement in osteoarthritis.",
        "dosage_adult": "Apply a thin layer to the affected joint and massage gently 2 to 3 times daily until fully absorbed.",
        "dosage_child": "Consult a pediatrician before use.",
        "side_effects": "Mild skin irritation, transient redness, or local warmth in extremely rare cases.",
        "interactions": "No significant systemic drug interactions reported.",
        "contraindications": "Hypersensitivity to any of the ingredients. Do not apply on broken skin or open wounds.",
        "price": 85.0,
        "is_prescription_required": False
    },
    {
        "medicine_name": "Catafast 50mg",
        "generic_name": "Diclofenac Potassium",
        "medicine_image": None,
        "uses": "Fast-acting pain relief for acute painful conditions: post-traumatic pain, dental pain, migraine attacks, and dysmenorrhea.",
        "dosage_adult": "1 sachet (50mg) dissolved in a glass of water 2 to 3 times daily as needed.",
        "dosage_child": "Not recommended for children and adolescents under 14 years.",
        "side_effects": "Gastric irritation, heartburn, nausea, dizziness, transient headache, skin rash.",
        "interactions": "Increases bleeding risk with oral anticoagulants, NSAIDs, and selective serotonin reuptake inhibitors.",
        "contraindications": "Active stomach ulcer, severe heart failure, third trimester of pregnancy, renal failure.",
        "price": 75.0,
        "is_prescription_required": False
    },
    {
        "medicine_name": "Amoxicillin 500mg",
        "generic_name": "Amoxicillin (Penicillin Antibiotic)",
        "medicine_image": None,
        "uses": "Treatment of acute bacterial infections of the ear, nose, throat, respiratory tract, urinary tract, skin, and soft tissues.",
        "dosage_adult": "250mg to 500mg every 8 hours, or 500mg to 875mg every 12 hours depending on severity.",
        "dosage_child": "20mg to 45mg per kg body weight daily in divided doses, depending on infection type.",
        "side_effects": "Diarrhea, nausea, skin rash (hives), oral thrush (fungal infection) with prolonged use.",
        "interactions": "Reduces efficiency of combined oral contraceptive pills. Probenecid increases amoxicillin blood levels.",
        "contraindications": "Hypersensitivity to penicillins or cephalosporins. History of amoxicillin-associated jaundice.",
        "price": 32.5,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Lipitor 20mg",
        "generic_name": "Atorvastatin Calcium",
        "medicine_image": None,
        "uses": "Adjunct to diet to reduce elevated total cholesterol, LDL cholesterol, apolipoprotein B, and triglycerides in primary hypercholesterolemia.",
        "dosage_adult": "10mg to 80mg once daily taken at any time of day, with or without food.",
        "dosage_child": "For pediatric hypercholesterolemia, consult a pediatric endocrinologist for custom dosing.",
        "side_effects": "Myalgia (muscle pain), headache, nasopharyngitis, dyspepsia, mild liver enzyme increases.",
        "interactions": "Avoid excessive grapefruit juice. Increased risk of myopathy when co-administered with clarithromycin, erythromycin, or itraconazole.",
        "contraindications": "Active liver disease, unexplained persistent elevations of serum transaminases, pregnancy, and breastfeeding.",
        "price": 180.0,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Nexium 40mg",
        "generic_name": "Esomeprazole",
        "medicine_image": None,
        "uses": "Symptomatic treatment of gastroesophageal reflux disease (GERD), healing of erosive esophagitis, and prevention of NSAID-associated gastric ulcers.",
        "dosage_adult": "20mg to 40mg once daily, taken 1 hour before a meal, swallowed whole with water.",
        "dosage_child": "For adolescents 12-18 years, 20mg once daily for GERD symptoms.",
        "side_effects": "Headache, diarrhea, dry mouth, abdominal pain, flatulence, constipation.",
        "interactions": "May reduce absorption of ketoconazole, itraconazole, and iron. Increases blood levels of diazepam.",
        "contraindications": "Hypersensitivity to esomeprazole or substituted benzimidazoles. Co-administration with nelfinavir is contraindicated.",
        "price": 150.0,
        "is_prescription_required": False
    },
    {
        "medicine_name": "Zyrtec 10mg",
        "generic_name": "Cetirizine Hydrochloride",
        "medicine_image": None,
        "uses": "Relief of nasal and ocular symptoms of seasonal and perennial allergic rhinitis, and relief of symptoms of chronic idiopathic urticaria (hives).",
        "dosage_adult": "10mg once daily (1 tablet). Elderly or patients with renal impairment: 5mg daily.",
        "dosage_child": "Children 6-12 years: 5mg twice daily. Children 2-6 years: 2.5mg twice daily.",
        "side_effects": "Mild drowsiness, fatigue, headache, dry mouth, pharyngitis.",
        "interactions": "Enhanced CNS depression when taken with alcohol, sedatives, or tranquilizers.",
        "contraindications": "Hypersensitivity to cetirizine, hydroxyzine, or piperazine derivatives. Severe renal impairment (GFR < 10ml/min).",
        "price": 45.0,
        "is_prescription_required": False
    },
    {
        "medicine_name": "Augmentin 1gm",
        "generic_name": "Amoxicillin + Clavulanate Potassium",
        "medicine_image": None,
        "uses": "Treatment of bacterial infections of the middle ear, sinuses, throat, lungs, skin, soft tissues, bones, and joints caused by beta-lactamase producing organisms.",
        "dosage_adult": "1 tablet (1000mg) every 12 hours for mild to moderate infections, or 1 tablet 3 times daily for severe cases.",
        "dosage_child": "Calculated strictly by body weight, administered as suspension or drop forms as prescribed.",
        "side_effects": "Diarrhea, abdominal pain, nausea, skin rash, diaper rash in infants.",
        "interactions": "Reduces contraceptive pill efficacy. Allopurinol increases risk of allergic skin rash.",
        "contraindications": "Hypersensitivity to penicillins or clavulanate. History of cholestatic jaundice or liver injury linked to penicillins.",
        "price": 105.0,
        "is_prescription_required": True
    },
    {
        "medicine_name": "Cataflam 50mg",
        "generic_name": "Diclofenac Potassium",
        "medicine_image": None,
        "uses": "Symptomatic treatment of painful inflammatory conditions: rheumatological joints, dental pain, musculoskeletal strain, and dysmenorrhea.",
        "dosage_adult": "50mg to 150mg daily in 2 or 3 divided doses after meals.",
        "dosage_child": "Not recommended for children under 14 years.",
        "side_effects": "Dyspepsia, epigastric pain, flatulence, headache, dizziness, skin irritation.",
        "interactions": "Increases blood levels of digoxin, cyclosporine, and lithium. Potential for renal injury when combined with diuretics.",
        "contraindications": "Active gastrointestinal ulcer or bleeding. Third trimester of pregnancy. Severe coronary artery disease pain.",
        "price": 55.0,
        "is_prescription_required": False
    }
]

with app.app_context():
    print("Starting database seeding (upsert strategy)...")
    
    # Get all active pharmacies in database
    pharmacies = Pharmacy.query.all()
    print(f"Loaded {len(pharmacies)} pharmacies to seed inventories.")
    
    seed_count = 0
    inv_count = 0
    
    from utils.images import resolve_medicine_image_path
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    uploads_dir = os.path.join(backend_dir, "uploads")
    
    for med in MEDICINES_DATA:
        medicine_name = med["medicine_name"]
        
        # 1. Upsert into MedicineInfo
        info = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(medicine_name)).first()
        
        resolved_img = resolve_medicine_image_path(medicine_name, uploads_dir)
        
        if not info:
            print(f"Creating new medicine catalog record: {medicine_name}")
            info = MedicineInfo(
                medicine_name=medicine_name,
                generic_name=med["generic_name"],
                medicine_image=resolved_img,
                uses=med["uses"],
                dosage_adult=med["dosage_adult"],
                dosage_child=med["dosage_child"],
                side_effects=med["side_effects"],
                interactions=med["interactions"],
                contraindications=med["contraindications"]
            )
            db.session.add(info)
        else:
            print(f"Updating existing medicine catalog record: {medicine_name}")
            info.generic_name = med["generic_name"]
            # Only update image if not already set to a custom upload (i.e. if it is None or generic_pill or http url)
            if not info.medicine_image or info.medicine_image == '/uploads/medicines/generic_pill.png' or info.medicine_image.startswith('http'):
                info.medicine_image = resolved_img
            info.uses = med["uses"]
            info.dosage_adult = med["dosage_adult"]
            info.dosage_child = med["dosage_child"]
            info.side_effects = med["side_effects"]
            info.interactions = med["interactions"]
            info.contraindications = med["contraindications"]
            
        db.session.commit()
        seed_count += 1
        
        # 2. Upsert into MedicineInventory across all pharmacies
        for pharm in pharmacies:
            inv = MedicineInventory.query.filter(
                MedicineInventory.pharmacy_id == pharm.pharmacy_id,
                MedicineInventory.medicine_name.ilike(medicine_name)
            ).first()
            
            # Stock quantity: slightly randomized stock (5 to 45 units), with a 10% chance of being out of stock (0)
            stock = 0 if random.random() < 0.1 else random.randint(5, 45)
            # Price: slightly randomized (+/- 10% of base price)
            price_variation = round(med["price"] * random.uniform(0.9, 1.1), 2)
            
            future_expiry = datetime.utcnow().date() + timedelta(days=random.randint(180, 730))
            
            if not inv:
                inv = MedicineInventory(
                    pharmacy_id=pharm.pharmacy_id,
                    medicine_name=info.medicine_name, # Match catalog name exactly
                    generic_name=med["generic_name"],
                    batch_number=f"BATCH-{random.randint(100, 999)}",
                    expiry_date=future_expiry,
                    stock_quantity=stock,
                    price=price_variation,
                    is_prescription_required=med["is_prescription_required"]
                )
                db.session.add(inv)
            else:
                # Update existing records to add images and update details
                inv.generic_name = med["generic_name"]
                inv.expiry_date = future_expiry
                # Keep existing pricing/stock if they are already valid and realistic, or update if they are zero
                if inv.stock_quantity == 0:
                    inv.stock_quantity = stock
                if float(inv.price or 0.0) == 0.0:
                    inv.price = price_variation
                inv.is_prescription_required = med["is_prescription_required"]
                
            db.session.commit()
            inv_count += 1

    print(f"\nSuccessfully seeded {seed_count} medicines in the catalog!")
    print(f"Successfully upserted {inv_count} inventory records across all pharmacies!")
