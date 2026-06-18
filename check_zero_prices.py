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
        cursor.execute("SELECT * FROM medicine_inventory WHERE (price = 0 OR price IS NULL) AND stock_quantity > 0")
        res = cursor.fetchall()
        print("=== STOCK > 0 AND PRICE = 0 IN INVENTORY ===")
        print(f"Found {len(res)} items.")
        for r in res[:20]:
            print(r)
finally:
    connection.close()
