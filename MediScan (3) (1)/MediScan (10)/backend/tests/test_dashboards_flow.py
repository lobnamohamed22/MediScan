import sys
import json
sys.path.append('c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend')

from app import create_app
from flask_jwt_extended import create_access_token
from models.user import User

def run_tests():
    app = create_app()
    client = app.test_client()
    
    with app.app_context():
        # User IDs
        admin_id = '5'
        owner_id = '2'
        driver_id = '4'
        
        # Generate Tokens
        admin_token = create_access_token(identity=admin_id)
        owner_token = create_access_token(identity=owner_id)
        driver_token = create_access_token(identity=driver_id)
        
        print("=== RUNNING ADMIN ENDPOINTS TESTS ===")
        
        # 1. Test Admin Analytics
        res = client.get('/api/admin/analytics', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/analytics: {res.status_code}")
        assert res.status_code == 200
        
        # 2. Test Admin Users List
        res = client.get('/api/admin/users', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/users: {res.status_code}")
        assert res.status_code == 200
        
        # 3. Test Admin Pharmacies List
        res = client.get('/api/admin/pharmacies', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/pharmacies: {res.status_code}")
        assert res.status_code == 200
        
        # 4. Test Admin Medicines Catalog List
        res = client.get('/api/admin/medicines', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/medicines: {res.status_code}")
        assert res.status_code == 200
        
        # 5. Test Admin Inventory List
        res = client.get('/api/admin/inventory', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/inventory: {res.status_code}")
        assert res.status_code == 200
        
        # 6. Test Admin Prescriptions List
        res = client.get('/api/admin/prescriptions', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/prescriptions: {res.status_code}")
        assert res.status_code == 200
        
        # 7. Test Admin Orders List
        res = client.get('/api/admin/orders', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/orders: {res.status_code}")
        assert res.status_code == 200
        
        # 8. Test Admin Notifications List
        res = client.get('/api/admin/notifications', headers={'Authorization': f'Bearer {admin_token}'})
        print(f"GET /api/admin/notifications: {res.status_code}")
        assert res.status_code == 200
        
        print("\n=== RUNNING PHARMACY OWNER ENDPOINTS TESTS ===")
        
        # 9. Test My Pharmacy
        res = client.get('/api/pharmacies/my-pharmacy', headers={'Authorization': f'Bearer {owner_token}'})
        print(f"GET /api/pharmacies/my-pharmacy: {res.status_code}")
        assert res.status_code == 200
        
        # 10. Test My Pharmacy Inventory
        res = client.get('/api/pharmacies/my-pharmacy/inventory', headers={'Authorization': f'Bearer {owner_token}'})
        print(f"GET /api/pharmacies/my-pharmacy/inventory: {res.status_code}")
        assert res.status_code == 200
        
        # 11. Test Pharmacy Incoming Orders
        res = client.get('/api/orders/pharmacy/incoming', headers={'Authorization': f'Bearer {owner_token}'})
        print(f"GET /api/orders/pharmacy/incoming: {res.status_code}")
        assert res.status_code == 200
        
        print("\n=== RUNNING DELIVERY DRIVER ENDPOINTS TESTS ===")
        
        # 12. Test Driver Unassigned Deliveries
        res = client.get('/api/orders/delivery/unassigned', headers={'Authorization': f'Bearer {driver_token}'})
        print(f"GET /api/orders/delivery/unassigned: {res.status_code}")
        assert res.status_code == 200
        
        # 13. Test Driver Assigned Deliveries
        res = client.get('/api/orders/delivery/assigned', headers={'Authorization': f'Bearer {driver_token}'})
        print(f"GET /api/orders/delivery/assigned: {res.status_code}")
        assert res.status_code == 200
        
        print("\nALL TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    run_tests()
