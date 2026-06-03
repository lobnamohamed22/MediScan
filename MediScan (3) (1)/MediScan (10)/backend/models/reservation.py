import uuid
from extensions import db
from datetime import datetime

class Reservation(db.Model):
    __tablename__ = 'reservations'
    
    reservation_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    pharmacy_id = db.Column(db.String(36), db.ForeignKey('pharmacies.pharmacy_id'), nullable=False)
    prescription_medicine_id = db.Column(db.String(36), db.ForeignKey('prescription_medicines.id'), nullable=False)
    status = db.Column(db.Enum('pending', 'confirmed', 'picked_up', 'cancelled'), default='pending')
    reserved_until = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.reservation_id,
            'user_id': self.user_id,
            'pharmacy_id': self.pharmacy_id,
            'prescription_medicine_id': self.prescription_medicine_id,
            'status': self.status,
            'reserved_until': self.reserved_until.isoformat() if self.reserved_until else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }