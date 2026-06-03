import uuid
from extensions import db
from datetime import datetime

class Cart(db.Model):
    __tablename__ = 'carts'
    
    cart_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False, unique=True)
    pharmacy_id = db.Column(db.String(36), db.ForeignKey('pharmacies.pharmacy_id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    items = db.relationship('CartItem', backref='cart', lazy=True, cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'cart_id': self.cart_id,
            'user_id': self.user_id,
            'pharmacy_id': self.pharmacy_id,
            'items': [item.to_dict() for item in self.items]
        }

class CartItem(db.Model):
    __tablename__ = 'cart_items'
    
    cart_item_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cart_id = db.Column(db.String(36), db.ForeignKey('carts.cart_id'), nullable=False)
    # Using medicine_info.id because the frontend searches for generic medicines, not specific inventory items.
    medicine_id = db.Column(db.String(36), db.ForeignKey('medicine_info.id'), nullable=False)
    quantity = db.Column(db.Integer, default=1)
    
    # We can store price as a snapshot or just fetch it dynamically.
    # For now, let's keep price dynamic or snapshot it if we want.
    # The frontend uses avg_price from the search route.

    medicine = db.relationship('MedicineInfo', backref='cart_items', lazy=True)

    def to_dict(self):
        # We need to fetch price dynamically or use a field. 
        # Since search API aggregates price, we'll let the route handle injecting dynamic details like price.
        return {
            'cart_item_id': self.cart_item_id,
            'cart_id': self.cart_id,
            'medicine_id': self.medicine_id,
            'quantity': self.quantity,
        }
