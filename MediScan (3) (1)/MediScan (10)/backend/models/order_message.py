import uuid
from extensions import db
from datetime import datetime

class OrderMessage(db.Model):
    __tablename__ = 'order_messages'
    
    message_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = db.Column(db.String(36), db.ForeignKey('delivery_orders.order_id'), nullable=False)
    sender_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    sender = db.relationship('User', backref=db.backref('order_messages', lazy=True))
    order = db.relationship('DeliveryOrder', backref=db.backref('messages', lazy=True, cascade='all, delete-orphan'))

    def to_dict(self):
        return {
            'message_id': self.message_id,
            'order_id': self.order_id,
            'sender_id': self.sender_id,
            'sender_name': self.sender.full_name if self.sender else 'Unknown',
            'sender_role': self.sender.role if self.sender else 'unknown',
            'message': self.message,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
