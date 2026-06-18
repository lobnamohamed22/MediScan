import pymysql

try:
    connection = pymysql.connect(
        host='127.0.0.1',
        user='root',
        password='',
        database='mediscan_db',
        cursorclass=pymysql.cursors.DictCursor
    )
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM medicine_inventory WHERE medicine_name = 'panadol' OR medicine_name = 'Panadol'")
        res = cursor.fetchall()
        print("=== EXACT PANADOL ROWS IN INVENTORY ===")
        for r in res:
            print(r)
            
        cursor.execute("SELECT * FROM medicine_info WHERE medicine_name = 'panadol' OR medicine_name = 'Panadol'")
        res_info = cursor.fetchall()
        print("\n=== EXACT PANADOL ROWS IN INFO ===")
        for r in res_info:
            print(r)
finally:
    connection.close()
