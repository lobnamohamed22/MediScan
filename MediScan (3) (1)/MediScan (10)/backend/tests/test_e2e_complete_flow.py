import sys
import json
import uuid
from datetime import datetime, date

sys.path.append('c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend')

from app import create_app
from extensions import db
from models.user import User
from models.pharmacy import Pharmacy
from models.medicine import MedicineInventory, MedicineInfo
from models.order import DeliveryOrder
from models.prescription import Prescription, PrescriptionMedicine
from flask_jwt_extended import create_access_token

def run_e2e_test():
    app = create_app()
    client = app.test_client()
    
    with app.app_context():
        print("=== 1. PREPARING TEST ACCOUNTS ===")
        # Get users
        patient = User.query.filter_by(role='patient').first()
        if not patient:
            patient = User(user_id=str(uuid.uuid4()), email='patient.test@example.com', role='patient', full_name='John Patient', phone='01234567890', is_verified=True)
            db.session.add(patient)
            db.session.commit()
            
        owner = User.query.filter_by(role='pharmacy_owner').first()
        driver = User.query.filter_by(role='delivery').first()
        
        patient_token = create_access_token(identity=patient.user_id)
        owner_token = create_access_token(identity=owner.user_id)
        driver_token = create_access_token(identity=driver.user_id)
        
        pharmacy = Pharmacy.query.filter_by(owner_id=owner.user_id).first()
        print(f"Patient ID: {patient.user_id} | Name: {patient.full_name}")
        print(f"Pharmacy Owner ID: {owner.user_id} | Name: {owner.full_name}")
        print(f"Pharmacy ID: {pharmacy.pharmacy_id} | Name: {pharmacy.name}")
        print(f"Driver ID: {driver.user_id} | Name: {driver.full_name}")
        
        print("\n=== 2. SEEDING TEST INVENTORY AND CATALOG ===")
        # Add test medicine to catalog
        med_name = "E2ETestMedicine"
        catalog_item = MedicineInfo.query.filter_by(medicine_name=med_name).first()
        if not catalog_item:
            catalog_item = MedicineInfo(
                medicine_name=med_name,
                generic_name="E2ETestGeneric",
                uses="E2ETesting uses",
                medicine_image="/uploads/medicines/generic_pill.png",
                status="Verified"
            )
            db.session.add(catalog_item)
            db.session.commit()
            
        # Add to pharmacy inventory
        inv_item = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id, medicine_name=med_name).first()
        if not inv_item:
            inv_item = MedicineInventory(
                pharmacy_id=pharmacy.pharmacy_id,
                medicine_name=med_name,
                generic_name="E2ETestGeneric",
                batch_number="B-E2E-99",
                expiry_date=date(2029, 12, 31),
                stock_quantity=100,
                price=50.00,
                is_prescription_required=True
            )
            db.session.add(inv_item)
            db.session.commit()
        else:
            inv_item.stock_quantity = 100
            inv_item.price = 50.00
            db.session.commit()
            
        print(f"Inventory Item: {inv_item.medicine_name} | Stock: {inv_item.stock_quantity} | Price: {inv_item.price} EGP")
        
        print("\n=== 3. SIMULATING PRESCRIPTION SCAN & DB SYNC ===")
        prescription_id = str(uuid.uuid4())
        presc = Prescription(
            prescription_id=prescription_id,
            user_id=patient.user_id,
            image_url="/uploads/prescriptions/presc_e2e_test.jpg",
            status="processed",
            extracted_text=json.dumps([med_name]),
            uploaded_at=datetime.utcnow()
        )
        db.session.add(presc)
        
        pm = PrescriptionMedicine(
            id=str(uuid.uuid4()),
            prescription_id=prescription_id,
            medicine_name=med_name,
            dosage="1 tablet",
            frequency="Once daily",
            duration_days=10,
            quantity=1
        )
        db.session.add(pm)
        db.session.commit()
        print(f"Seeded Prescription ID: {prescription_id} with medicine: {med_name}")
        
        print("\n=== 4. SIMULATING CHECKOUT (ORDER CREATION) ===")
        checkout_payload = {
            'pharmacy_id': pharmacy.pharmacy_id,
            'medicines': [
                {'name': med_name, 'quantity': 2}
            ],
            'quantity': 2,
            'total_price': 100.00,
            'customer_lat': 30.0444,
            'customer_lng': 31.2357
        }
        res_checkout = client.post(
            '/api/orders',
            data=json.dumps(checkout_payload),
            headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {patient_token}'}
        )
        print(f"POST /api/orders: Status {res_checkout.status_code}")
        print("Response:", res_checkout.get_json())
        assert res_checkout.status_code == 201
        checkout_body = res_checkout.get_json()
        order_id = checkout_body.get('data', {}).get('order_id')
        print(f"Order created successfully! Order ID: {order_id}")
        
        # Verify inventory was decremented
        inv_check = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id, medicine_name=med_name).first()
        print(f"Stock after checkout: {inv_check.stock_quantity} (Expected: 98)")
        assert inv_check.stock_quantity == 98
        
        print("\n=== 5. PHARMACY OWNER FLOW (ACCEPT & PREPARE) ===")
        # Get incoming orders
        res_incoming = client.get(
            '/api/orders/pharmacy/incoming',
            headers={'Authorization': f'Bearer {owner_token}'}
        )
        print(f"GET /api/orders/pharmacy/incoming: Status {res_incoming.status_code}")
        assert res_incoming.status_code == 200
        orders = res_incoming.get_json().get('data', [])
        print(f"Total incoming orders found: {len(orders)}")
        
        # Accept order
        res_accept = client.patch(
            f'/api/orders/{order_id}/status',
            data=json.dumps({'status': 'preparing'}),
            headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {owner_token}'}
        )
        print(f"PATCH /api/orders/{order_id}/status (preparing): Status {res_accept.status_code}")
        assert res_accept.status_code == 200
        
        # Set to ready for delivery
        res_ready = client.patch(
            f'/api/orders/{order_id}/status',
            data=json.dumps({'status': 'ready'}),
            headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {owner_token}'}
        )
        print(f"PATCH /api/orders/{order_id}/status (ready): Status {res_ready.status_code}")
        assert res_ready.status_code == 200
        
        print("\n=== 6. DELIVERY DRIVER CLAIM FLOW ===")
        # List unassigned ready orders
        res_unassigned = client.get(
            '/api/orders/delivery/unassigned',
            headers={'Authorization': f'Bearer {driver_token}'}
        )
        print(f"GET /api/orders/delivery/unassigned: Status {res_unassigned.status_code}")
        assert res_unassigned.status_code == 200
        unassigned = res_unassigned.get_json().get('data', [])
        assert any(o['order_id'] == order_id for o in unassigned)
        print("Order is present in unassigned ready orders list!")
        
        # Accept/Claim order
        res_claim = client.post(
            f'/api/orders/{order_id}/accept-delivery',
            headers={'Authorization': f'Bearer {driver_token}'}
        )
        print(f"POST /api/orders/{order_id}/accept-delivery: Status {res_claim.status_code}")
        assert res_claim.status_code == 200
        
        # Verify order status changed to 'assigned' and driver assigned
        order_check = DeliveryOrder.query.get(order_id)
        print(f"Order status: {order_check.status} (Expected: assigned)")
        print(f"Driver Assigned ID: {order_check.delivery_person_id} (Expected: {driver.user_id})")
        assert order_check.status == 'assigned'
        assert order_check.delivery_person_id == driver.user_id
        
        print("\n=== 7. SIMULATING GPS COORDINATES UPDATE ===")
        gps_payload = {'lat': 30.0512, 'lng': 31.2401}
        res_gps = client.patch(
            f'/api/orders/{order_id}/location',
            data=json.dumps(gps_payload),
            headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {driver_token}'}
        )
        print(f"PATCH /api/orders/{order_id}/location: Status {res_gps.status_code}")
        assert res_gps.status_code == 200
        
        print("\n=== 8. PROGRESSING DELIVERY STATUS ===")
        for next_status in ['picked_up', 'in_transit', 'delivered']:
            res_status = client.patch(
                f'/api/orders/{order_id}/status',
                data=json.dumps({'status': next_status}),
                headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {driver_token}'}
            )
            print(f"PATCH /api/orders/{order_id}/status ({next_status}): Status {res_status.status_code}")
            assert res_status.status_code == 200
            
        # Final checks
        final_order = DeliveryOrder.query.get(order_id)
        print(f"\nFinal Order Status: {final_order.status} (Expected: delivered)")
        assert final_order.status == 'delivered'
        
        # Clean up test entries
        db.session.delete(final_order)
        db.session.delete(pm)
        db.session.delete(presc)
        db.session.commit()
        print("\n=== E2E FLOW TEST PASSED SUCCESSFULLY! ===")

if __name__ == '__main__':
    run_e2e_test()
