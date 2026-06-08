import uuid
from extensions import db
from datetime import datetime

class User(db.Model):
    __tablename__ = 'users'
    
    user_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(100), unique=True, nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.Enum('Male', 'Female', 'Other'), default='Other')
    role = db.Column(db.Enum('patient', 'pharmacist', 'pharmacy_owner', 'delivery', 'doctor', 'admin', 'family_member', 'regulator'), default='patient')
    is_verified = db.Column(db.Boolean, default=False)
    otp_secret = db.Column(db.String(255))
    reward_points = db.Column(db.Integer, default=0)
    wallet_balance = db.Column(db.Numeric(10, 2), default=0.0)
    
    def to_dict(self):
        return {
            'id': self.user_id,
            'name': self.full_name,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'gender': self.gender,
            'is_verified': self.is_verified,
            'reward_points': self.reward_points if self.reward_points is not None else 0,
            'wallet_balance': float(self.wallet_balance) if self.wallet_balance else 0.0,
            'date_of_birth': self.date_of_birth.isoformat() if self.date_of_birth else None
        }