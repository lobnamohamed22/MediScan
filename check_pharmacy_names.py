import pymysql

try:
    conn = pymysql.connect(host='localhost', user='root', password='', database='mediscan_db')
    cursor = conn.cursor()
    cursor.execute("SELECT pharmacy_id, name, address FROM pharmacies")
    rows = cursor.fetchall()
    
    print(f"Total pharmacies: {len(rows)}")
    for i, row in enumerate(rows):
        p_id, name, address = row
        print(f"{i+1:3d}. ID: {p_id} | Name: {name} | Address: {address}")
        
except Exception as e:
    print("Error:", e)
finally:
    if 'conn' in locals() and conn:
        conn.close()
