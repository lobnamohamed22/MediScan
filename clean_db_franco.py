import pymysql

# Franco-Arabic to clean English mappings
NAME_REPLACEMENTS = {
    "Pharmacy ShAHBWR": "Shahbour Pharmacy",
    "Pharmacy FAYQ": "Fayek Pharmacy",
    "Pharmacy ALMRWa": "Al-Marwa Pharmacy",
    "Pharmacy AShRF": "Ashraf Pharmacy",
    "Pharmacy ALWLYD": "Al-Waleed Pharmacy",
    "Pharmacy JAMAa ALDWL ALARBYa": "Arab League Pharmacy",
    "Pharmacy ALMMALYK": "Al-Mamalik Pharmacy",
    "Pharmacy LYLa": "Layla Pharmacy",
    "Pharmacy ALaSAAF BRMSYS": "Al-Isaaf Pharmacy (Ramses)",
    "Pharmacy HSNYN": "Hosny Pharmacy",
    "Pharmacy ABD ALRHMN SALH": "Abdel-Rahman Saleh Pharmacy",
    "Dr. Pharmacy TARQ ALALKY (AWNY SABQA)": "Dr. Tarek Al-Alky Pharmacy",
    "Pharmacies SYF": "Seif Pharmacy",
    "AZBY": "El Ezaby Pharmacy",
    "NWRMNDY": "Normandy Pharmacy",
    "Dr. Pharmacy HNAN MHMWD TH": "Dr. Hanan Mahmoud Pharmacy",
    "Pharmacy AHMD ABW ALFTWH": "Dr. Ahmed Abou Al-Fotouh Pharmacy",
    "Pharmacy NWR ALASLaM": "Nour Al-Islam Pharmacy",
    "Pharmacy MSTFy MHMWD": "Mostafa Mahmoud Pharmacy",
    "elezaby": "El Ezaby Pharmacy",
    "Abdel-Khaiek": "Abdel-Khalek Pharmacy",
    "Mti": "MTI Pharmacy",
    "sandy Pharmacy": "Sandy Pharmacy",
    "Dr George Anwar ferig": "Dr. George Anwar Farag Pharmacy",
    "Pharmacy SWSN ALHDYTha": "Sawsan Al-Hadeetha Pharmacy",
    "Pharmacy Roushdy": "Roushdy Pharmacy",
    "Pharmacy KARMN": "Carmen Pharmacy",
    "Serenade": "Serenade Pharmacy",
    "Africia": "Africa Pharmacy",
    "Sakla": "Sakla Pharmacy",
    "Al Azaby": "El Ezaby Pharmacy",
    "Al-Safa pharmacy": "Al-Safa Pharmacy",
    "El Ezaby pharmacy": "El Ezaby Pharmacy",
    "New Universal Pharmacy": "Universal Pharmacy",
    "Mohamed Salama Pharmacy": "Dr. Mohamed Salama Pharmacy",
}

ADDRESS_REPLACEMENTS = {
    "ShARA ALJAMAa ALHDYTha": "Modern University Street",
    "ShARA ALMNYL": "Manial Street",
    "ShARA ALWHDH": "El-Wehda Street",
    "ShARA AHMD TYSYR": "Ahmed Taysir Street",
    "ShARA BWRSAYD": "Port Said Street",
    "ShARA FYLYB HNA": "Philip Henein Street",
    "ShARA ALRWDa": "El-Rowdah Street",
    "ShARA KhLF ALNADy": "Behind the Club Street",
    "ShARA AThMAN BN AFAN": "Othman Ibn Affan Street",
    "HARa ALTMSAH": "El-Temsah Alley",
    "ALQAHRa": "Cairo",
    "ABW BKR ALSDYQ": "Abu Bakr Al-Siddiq Street",
    "Al Selehdar Street, Cairo, Egypt": "El-Selehdar Street, Cairo, Egypt",
    "Mostafa El Nahas Street, Nasr City, Cairo, Egypt": "Mostafa El-Nahas Street, Nasr City, Cairo, Egypt",
    "El Merghany Street, Heliopolis, Cairo, Egypt": "El-Merghany Street, Heliopolis, Cairo, Egypt",
    "El-Shaheed Street, Hadayek Helwan, Cairo, Egypt": "El-Shaheed Street, Hadayek Helwan, Cairo, Egypt",
    "Abbas El Akkad Street, Nasr City, Cairo, Egypt": "Abbas El-Akkad Street, Nasr City, Cairo, Egypt",
    "El Horreya Road, Heliopolis, Cairo, Egypt": "El-Horreya Road, Heliopolis, Cairo, Egypt",
}

try:
    conn = pymysql.connect(host='localhost', user='root', password='', database='mediscan_db')
    cursor = conn.cursor()
    cursor.execute("SELECT pharmacy_id, name, address FROM pharmacies")
    rows = cursor.fetchall()
    
    updated_count = 0
    for row in rows:
        p_id, name, address = row
        new_name = name
        new_address = address
        
        # Check and replace name
        for k, v in NAME_REPLACEMENTS.items():
            if name == k:
                new_name = v
                break
            elif name.startswith(k):
                new_name = name.replace(k, v)
                break
                
        # Check and replace address
        for k, v in ADDRESS_REPLACEMENTS.items():
            if address == k:
                new_address = v
                break
            elif k in address:
                new_address = address.replace(k, v)
                
        # Address cleanups for extra spaces/commas
        new_address = new_address.replace(",,", ",").strip()
        if new_address.endswith(","):
            new_address = new_address[:-1].strip()
        if not new_address.endswith(", Egypt") and not new_address.endswith("Egypt"):
            new_address += ", Egypt"
            
        if new_name != name or new_address != address:
            cursor.execute(
                "UPDATE pharmacies SET name = %s, address = %s WHERE pharmacy_id = %s",
                (new_name, new_address, p_id)
            )
            print(f"Updated: '{name}' -> '{new_name}' | '{address}' -> '{new_address}'")
            updated_count += 1
            
    conn.commit()
    print(f"\nSuccessfully updated {updated_count} pharmacies in the database.")
    
except Exception as e:
    print("Error:", e)
    conn.rollback()
finally:
    if 'conn' in locals() and conn:
        conn.close()
