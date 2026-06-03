import pytest
from extensions import create_app, db

@pytest.fixture
def app():
    """إنشاء تطبيق للاختبار"""
    app = create_app()
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///test.db'
    
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture
def client(app):
    """عميل للاختبار"""
    return app.test_client()

def test_home_page(client):
    """اختبار الصفحة الرئيسية"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'Medi Scan Backend is running!' in response.data

def test_register(client):
    """اختبار تسجيل مستخدم جديد"""
    response = client.post('/api/auth/register', json={
        'name': 'Test User',
        'email': 'test@example.com',
        'password': 'Test123456',
        'phone': '01012345678'
    })
    assert response.status_code == 201
    assert response.json['success'] == True