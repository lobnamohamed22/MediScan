import uuid
from extensions import db
from datetime import datetime

class Prescription(db.Model):
    __tablename__ = 'prescriptions'
    
    prescription_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    family_member_id = db.Column(db.String(36), db.ForeignKey('family_profiles.family_id'), nullable=True)
    image_url = db.Column(db.String(500))
    extracted_text = db.Column(db.Text)
    status = db.Column(db.Enum('uploaded', 'processed', 'reserved', 'filled', 'delivered', 'expired'), default='uploaded')
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship to medicines
    medicines_list = db.relationship('PrescriptionMedicine', backref='prescription', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.prescription_id,
            'user_id': self.user_id,
            'family_member_id': self.family_member_id,
            'image_url': self.image_url,
            'extracted_text': self.extracted_text,
            'status': self.status,
            'uploaded_at': self.uploaded_at.isoformat() if self.uploaded_at else None,
            'created_at': self.uploaded_at.isoformat() if self.uploaded_at else None,
            'medicines': [m.to_dict() for m in self.medicines_list]
        }

class PrescriptionMedicine(db.Model):
    __tablename__ = 'prescription_medicines'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    prescription_id = db.Column(db.String(36), db.ForeignKey('prescriptions.prescription_id'), nullable=False)
    medicine_name = db.Column(db.String(150), nullable=False)
    dosage = db.Column(db.String(100))
    frequency = db.Column(db.String(100))
    duration_days = db.Column(db.Integer)
    quantity = db.Column(db.Integer)
    alternative_approved = db.Column(db.Boolean, default=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'medicine_name': self.medicine_name,
            'dosage': self.dosage,
            'frequency': self.frequency,
            'duration_days': self.duration_days,
            'quantity': self.quantity,
            'alternative_approved': self.alternative_approved
        }