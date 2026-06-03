import uuid
from extensions import db
from datetime import datetime

class DeliveryOrder(db.Model):
    __tablename__ = 'delivery_orders'
    
    order_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    pharmacy_id = db.Column(db.String(36), db.ForeignKey('pharmacies.pharmacy_id'), nullable=False)
    delivery_person_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=True)
    status = db.Column(db.Enum('assigned', 'picked_up', 'in_transit', 'delivered', 'pending', 'preparing', 'ready', 'rejected'), default='assigned')
    # Using String for tracking_location to handle POINT via raw SQL in routes
    tracking_location = db.Column(db.String(100)) 
    payment_status = db.Column(db.Enum('pending', 'paid', 'refunded'), default='pending')
    discount = db.Column(db.Numeric(10, 2))
    quantity = db.Column('Quantity', db.Integer)
    total_price = db.Column('Total price', db.Numeric(10, 0))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    medicines = db.Column(db.JSON, nullable=True)
    customer_lat = db.Column(db.Float, nullable=True)
    customer_lng = db.Column(db.Float, nullable=True)
    
    def to_dict(self):
        return {
            'id': self.order_id,
            'order_id': self.order_id,
            'user_id': self.user_id,
            'pharmacy_id': self.pharmacy_id,
            'delivery_person_id': self.delivery_person_id,
            'status': self.status,
            'payment_status': self.payment_status,
            'discount': float(self.discount) if self.discount else 0.0,
            'quantity': self.quantity,
            'total_price': float(self.total_price) if self.total_price else 0.0,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'medicines': self.medicines if self.medicines else [],
            'customer_lat': self.customer_lat,
            'customer_lng': self.customer_lng
        }
