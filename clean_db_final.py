import pymysql

LAST_REPLACEMENTS = {
    "Pharmacy ALy AYMDJ": "Ali Emad Pharmacy",
    "Pharmacy ABW ALFTH": "Abou El-Fath Pharmacy",
    "Pharmacy ALHKMa": "Al-Hekma Pharmacy",
    "Dr. Pharmacy DYNA SLaH": "Dr. Dina Salah Pharmacy",
    "Pharmacy NWR ALASLaM": "Nour Al-Islam Pharmacy",
}

try:
    conn = pymysql.connect(host='localhost', user='root', password='', database='mediscan_db')
    cursor = conn.cursor()
    
    for k, v in LAST_REPLACEMENTS.items():
        cursor.execute("UPDATE pharmacies SET name = %s WHERE name = %s", (v, k))
        print(f"Updated: {k} -> {v}")
        
    conn.commit()
    print("\nFinal clean-up complete.")
except Exception as e:
    print("Error:", e)
    conn.rollback()
finally:
    if 'conn' in locals() and conn:
        conn.close()
