import sys
sys.path.append('c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend')

from app import create_app
from extensions import db
from models.user import User
from werkzeug.security import generate_password_hash

app = create_app()

with app.app_context():
    credentials = {
        'admin@mediscan.com': 'password',
        'sarah.pharmacy@example.com': 'password',
        'delivery.mike@example.com': 'password'
    }
    
    for email, password in credentials.items():
        user = User.query.filter_by(email=email).first()
        if user:
            user.password_hash = generate_password_hash(password)
            user.is_verified = True
            print(f"Updated user: {email} password to: {password}")
        else:
            print(f"User not found: {email}")
            
    db.session.commit()
    print("Database updates committed successfully!")
