import uuid
from extensions import db
from datetime import datetime

class Pharmacy(db.Model):
    __tablename__ = 'pharmacies'
    
    pharmacy_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(150), nullable=False)
    address = db.Column(db.Text, nullable=False)
    latitude = db.Column(db.Numeric(10, 8))
    longitude = db.Column(db.Numeric(11, 8))
    phone = db.Column(db.String(20))
    opening_time = db.Column(db.Time)
    closing_time = db.Column(db.Time)
    is_24_hours = db.Column(db.Boolean, default=False)
    delivery_available = db.Column(db.Boolean, default=False)
    rating = db.Column(db.Numeric(2, 1), default=4.5)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    owner_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=True)
    
    def to_dict(self):
        return {
            'id': self.pharmacy_id,
            'owner_id': self.owner_id,
            'name': self.name,
            'address': self.address,
            'latitude': float(self.latitude) if self.latitude else None,
            'longitude': float(self.longitude) if self.longitude else None,
            'phone': self.phone,
            'opening_time': self.opening_time.strftime('%H:%M:%S') if self.opening_time else None,
            'closing_time': self.closing_time.strftime('%H:%M:%S') if self.closing_time else None,
            'delivery_available': self.delivery_available,
            'rating': float(self.rating) if self.rating else 0.0,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }