import pymysql

EXTENDED_NAME_REPLACEMENTS = {
    "Nagui": "Nagui Pharmacy",
    "Saad": "Saad Pharmacy",
    "Elezaby": "El Ezaby Pharmacy",
    "Hindam": "Hindam Pharmacy",
    "Boon": "Boon Pharmacy",
    "Hanna pharmacy": "Hanna Pharmacy",
    "Reham pharmacy": "Reham Pharmacy",
    "Al-Quds pharmacy": "Al-Quds Pharmacy",
    "Makram pharmacy": "Makram Pharmacy",
    "Care pharmacy": "Care Pharmacy",
    "Al-Safa pharmacy": "Al-Safa Pharmacy",
    "Dawa2y": "Dawaey Pharmacy",
}

EXTENDED_ADDRESS_REPLACEMENTS = {
    "Port Said Street, Egypt": "Port Said Street, Cairo, Egypt",
    "Ahmed Taysir Street, Egypt": "Ahmed Taysir Street, Heliopolis, Cairo, Egypt",
    "El-Rowdah Street, Egypt": "El-Rowdah Street, Al-Manial, Cairo, Egypt",
    "Othman Ibn Affan Street, Egypt": "Othman Ibn Affan Street, Heliopolis, Cairo, Egypt",
    "El-Temsah Alley, Egypt": "El-Temsah Alley, Cairo, Egypt",
    "Abu Bakr Al-Siddiq Street, Egypt": "Abu Bakr Al-Siddiq Street, Heliopolis, Cairo, Egypt",
    "Behind the Club Street, Egypt": "Behind the Club Street, Cairo, Egypt",
    "Philip Henein Street, Egypt": "Philip Henein Street, Cairo, Egypt",
    "Manial Street, Egypt": "Manial Street, Al-Manial, Cairo, Egypt",
    "Al Arif Abd Al Monem Street, Egypt": "Al Arif Abd Al Monem Street, Cairo, Egypt",
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
        
        # Check name
        if name in EXTENDED_NAME_REPLACEMENTS:
            new_name = EXTENDED_NAME_REPLACEMENTS[name]
        elif name.endswith(" pharmacy"):
            new_name = name.replace(" pharmacy", " Pharmacy")
            
        # Check address
        if address in EXTENDED_ADDRESS_REPLACEMENTS:
            new_address = EXTENDED_ADDRESS_REPLACEMENTS[address]
            
        if new_name != name or new_address != address:
            cursor.execute(
                "UPDATE pharmacies SET name = %s, address = %s WHERE pharmacy_id = %s",
                (new_name, new_address, p_id)
            )
            print(f"Updated: '{name}' -> '{new_name}' | '{address}' -> '{new_address}'")
            updated_count += 1
            
    conn.commit()
    print(f"\nSuccessfully performed {updated_count} additional cleanup updates.")
    
except Exception as e:
    print("Error:", e)
    conn.rollback()
finally:
    if 'conn' in locals() and conn:
        conn.close()
