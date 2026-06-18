import pymysql
import json

try:
    connection = pymysql.connect(
        host='127.0.0.1',
        user='root',
        password='',
        database='mediscan_db',
        cursorclass=pymysql.cursors.DictCursor
    )
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM delivery_orders")
        orders = cursor.fetchall()
        print("=== PLACED ORDERS ===")
        for o in orders:
            print("KEYS:", o.keys())
            # Find the total price key
            tp_key = [k for k in o.keys() if 'price' in k.lower()][0]
            print(f"Order ID: {o['order_id']}, Status: {o['status']}, Total Price: {o[tp_key]}, Medicines: {o['medicines']}")
finally:
    connection.close()
