import uuid
from extensions import db
from datetime import datetime

class MedicineInfo(db.Model):
    __tablename__ = 'medicine_info'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    medicine_name = db.Column(db.String(150), unique=True, nullable=False)
    generic_name = db.Column(db.String(150))
    medicine_image = db.Column(db.String(500))
    status = db.Column(db.String(50), default='Verified')
    uses = db.Column(db.Text)
    dosage_adult = db.Column(db.Text)
    dosage_child = db.Column(db.Text)
    side_effects = db.Column(db.Text)
    interactions = db.Column(db.Text)
    contraindications = db.Column(db.Text)
    
    def to_dict(self):
        img_url = self.medicine_image
        if img_url and img_url.startswith('/'):
            from flask import request
            try:
                img_url = request.host_url.rstrip('/') + img_url
            except Exception:
                pass
        return {
            'id': self.id,
            'medicine_name': self.medicine_name,
            'generic_name': self.generic_name,
            'medicine_image': img_url,
            'status': self.status or 'Verified',
            'uses': self.uses,
            'dosage_adult': self.dosage_adult,
            'dosage_child': self.dosage_child,
            'side_effects': self.side_effects,
            'interactions': self.interactions,
            'contraindications': self.contraindications
        }

class MedicineInventory(db.Model):
    __tablename__ = 'medicine_inventory'
    
    inventory_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pharmacy_id = db.Column(db.String(36), db.ForeignKey('pharmacies.pharmacy_id'), nullable=False)
    medicine_name = db.Column(db.String(150), nullable=False)
    generic_name = db.Column(db.String(150))
    batch_number = db.Column(db.String(100))
    expiry_date = db.Column(db.Date, nullable=False)
    stock_quantity = db.Column(db.Integer, default=0)
    price = db.Column(db.Numeric(10, 2))
    is_prescription_required = db.Column(db.Boolean, default=True)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        info = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(self.medicine_name)).first()
        img_url = info.medicine_image if info else None
        if img_url and img_url.startswith('/'):
            from flask import request
            try:
                img_url = request.host_url.rstrip('/') + img_url
            except Exception:
                pass
        return {
            'id': self.inventory_id,
            'pharmacy_id': self.pharmacy_id,
            'medicine_name': self.medicine_name,
            'generic_name': self.generic_name,
            'medicine_image': img_url,
            'batch_number': self.batch_number,
            'expiry_date': self.expiry_date.isoformat() if self.expiry_date else None,
            'stock_quantity': self.stock_quantity,
            'price': float(self.price) if self.price else 0.0,
            'is_prescription_required': self.is_prescription_required,
            'last_updated': self.last_updated.isoformat() if self.last_updated else None
        }

class MedicineAlternative(db.Model):
    __tablename__ = 'medicine_alternatives'
    
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    medicine_name = db.Column(db.String(150), nullable=False)
    alternative_name = db.Column(db.String(150), nullable=False)
    reason = db.Column(db.Text)
    
    def to_dict(self):
        return {
            'id': self.id,
            'medicine_name': self.medicine_name,
            'alternative_name': self.alternative_name,
            'reason': self.reason
        }

class MedicineRecall(db.Model):
    __tablename__ = 'medicine_recalls'
    
    recall_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    medicine_name = db.Column(db.String(150), nullable=False)
    batch_number = db.Column(db.String(100))
    reason = db.Column(db.Text)
    issued_by_regulator = db.Column(db.String(100))
    issued_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'recall_id': self.recall_id,
            'medicine_name': self.medicine_name,
            'batch_number': self.batch_number,
            'reason': self.reason,
            'issued_by_regulator': self.issued_by_regulator,
            'issued_at': self.issued_at.isoformat() if self.issued_at else None
        }

# For backward compatibility if any route still imports 'Medicine'
Medicine = MedicineInfo