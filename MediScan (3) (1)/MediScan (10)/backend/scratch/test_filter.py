import re

candidates = {
    "Cozaar 50mg": [
        "cozaar-01.jpg", "cozaar-02.jpg", "cozaar-03.jpg", "cozaar-04.jpg",
        "cozaar-05.jpg", "cozaar-06.jpg", "cozaar-07.jpg", "cozaar-08.jpg",
        "2335.jpg", "3726.jpg", "5077.jpg"
    ],
    "Januvia 100mg": [
        "cb585810-86d3-4bd2-b1c1-aab98a5a57a4-00.jpg",
        "januvia-01.jpg", "januvia-02.jpg", "januvia-03.jpg",
        "70d56126-cb62-4983-acad-0b92f22cd80f-00.jpg",
        "januvia-04.jpg", "januvia-05.jpg", "januvia-06.jpg",
        "lbl500901036.jpg", "lbl500903472.jpg"
    ],
    "Prednisolone 5mg": [
        "label.jpg", "prednisolone-acetate-01.jpg",
        "Kesin Logo-.jpg", "pred-structure.jpg", "prednisoLONE_OS_5mL_Carton_50ct.jpg",
        "8b7144d6-fff1-4afd-a80b-332ff7ed80a1-01.jpg", "lbl500907539.jpg",
        "prednisolone-sodium-phosphate-oral-solution-01.jpg",
        "prednisolone-sodium-phosphate-oral-solution-02.jpg",
        "prednisolone-sodium-phosphate-oral-solution-unit-dose-label.jpg",
        "Prednisolone Sodium Phosphate 15mg - 5mL_70518-4524-04.jpg",
        "Prednisolone Sodium Phosphate 15mg - 5mL_70518-4524-05.jpg",
        "Prednisolone Sodium Phosphate 30mg - 10mL_70518-4524-02.jpg",
        "Prednisolone Sodium Phosphate 30mg - 10mL_70518-4524-03.jpg",
        "Prednisolone Sodium Phosphate 75mg - 25mL_70518-4524-00.jpg",
        "Prednisolone Sodium Phosphate 75mg - 25mL_70518-4524-01.jpg",
        "prednisolone-sodium-phosphate-oral-solution-1.jpg"
    ],
    "Spironolactone 25mg": [
        "43063974.jpg", "spironolactone-figure-1.jpg", "spironolactone-figure-2.jpg", "spironolactone-structure-image.jpg",
        "Spironolactone-01.jpg", "Spironolactone-02.jpg", "Spironolactone-03.jpg", "lbl713352204.jpg",
        "lbl713352205.jpg", "lbl713350401.jpg"
    ],
    "Ciprofloxacin 500mg": [
        "image-01.jpg", "image-02.jpg", "lbl713352097.jpg",
        "lbl713352054.jpg", "label-250mg.jpg", "label-500mg.jpg",
        "45865-171.jpg", "ciprofloxacin-str1.jpg", "ciprofloxacin-str2.jpg",
        "Ciprofloxacin 500mg_70518-4214-01.jpg", "Ciprofloxacin 500mg_70518-4214-02.jpg", "Ciprofloxacin 500mg_70518-4214-03.jpg",
        "Remedy_Label.jpg"
    ]
}

# Negative patterns to reject (structures, labels, figures, diagrams, warning, etc.)
ignored_patterns = [
    r'structure',
    r'\bstr\b',
    r'[-_]str\d*',
    r'fig\d+',
    r'figure',
    r'label',
    r'\blbl',
    r'logo',
    r'chart',
    r'table',
    r'diagram',
    r'chemical',
    r'molecular',
    r'formula',
    r'graph',
    r'schematic',
    r'sketch',
    r'draw',
    r'line',
    r'doc',
    r'text',
    r'sheet',
    r'insert',
    r'info',
    r'monograph',
    r'warning',
    r'illustration',
    r'specimen',
    r'package[-_]insert',
    r'pi[-_]image',
    r'pi\d'
]

package_keywords = ['carton', 'box', 'package', 'container', 'blister', 'case', 'bottle', 'outer', 'pack', 'pkg', 'vial', 'ampule', 'pouch', 'wallet']

def is_ignored(name):
    name_lower = name.lower()
    for pattern in ignored_patterns:
        if re.search(pattern, name_lower):
            return True, pattern
    return False, None

def get_score(name, query):
    name_lower = name.lower()
    query_clean = re.sub(r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap)\b', '', query, flags=re.IGNORECASE).strip().lower()
    
    score = 0
    # Package carton/box keywords
    for pk in package_keywords:
        if pk in name_lower:
            score += 15  # Up from 10 to strongly prioritize actual packages
            
    # Drug name match score
    for word in query_clean.split():
        if word in name_lower:
            score += 5
            
    score += 1
    return score

for drug, files in candidates.items():
    print(f"\n==================== {drug} ====================")
    filtered_scored = []
    for f in files:
        ignored, pattern = is_ignored(f)
        if ignored:
            print(f"  REJECTED: {f:<60} (matched pattern: {pattern})")
        else:
            score = get_score(f, drug)
            filtered_scored.append((score, f))
            
    filtered_scored.sort(key=lambda x: x[0], reverse=True)
    print("  ACCEPTED & SCORED (sorted high to low):")
    for score, f in filtered_scored:
        print(f"    Score: {score:<3} | Name: {f}")
