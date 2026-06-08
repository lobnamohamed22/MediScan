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

    from sqlalchemy.orm import validates
    import random

    @validates('latitude')
    def validate_latitude(self, key, value):
        if value is None:
            raise ValueError("Latitude is required")
        val_f = float(value)
        if not (22.0 <= val_f <= 32.0):
            raise ValueError(f"Latitude ({val_f}) must be within Egypt borders (22.0 to 32.0)")
        return value

    @validates('longitude')
    def validate_longitude(self, key, value):
        if value is None:
            raise ValueError("Longitude is required")
        val_f = float(value)
        if not (24.0 <= val_f <= 37.0):
            raise ValueError(f"Longitude ({val_f}) must be within Egypt borders (24.0 to 37.0)")
        return value

    @validates('phone')
    def validate_phone(self, key, value):
        if not value:
            return f"+2010{random.randint(10000000, 99999999)}"
        
        # Clean up formatting
        cleaned = "".join(c for c in str(value) if c.isdigit() or c == '+')
        
        if cleaned.startswith('01') and len(cleaned) == 11:
            cleaned = '+20' + cleaned[1:]
        elif cleaned.startswith('02') and len(cleaned) == 9:
            cleaned = '+202' + cleaned[2:]
        elif cleaned.startswith('20') and not cleaned.startswith('+'):
            cleaned = '+' + cleaned
        elif not cleaned.startswith('+20'):
            if len(cleaned) >= 5 and len(cleaned) <= 6:
                cleaned = '+20' + cleaned
            else:
                # If it's something like "1234567890" from mock data, normalize it to valid Egypt number
                cleaned = f"+2010{random.randint(10000000, 99999999)}"
        return cleaned

    @validates('address')
    def validate_address(self, key, value):
        if not value:
            raise ValueError("Address is required")
        addr_str = str(value).strip()
        if "egypt" not in addr_str.lower():
            addr_str = addr_str + ", Egypt"
        return addr_str