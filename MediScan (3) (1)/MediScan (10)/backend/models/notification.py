import uuid
from extensions import db
from datetime import datetime

class Notification(db.Model):
    __tablename__ = 'notifications'
    
    notification_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    type = db.Column(db.Enum('stock_update', 'reservation', 'expiry_alert', 'recall', 'alternative_available', 'promotion', 'delivery', 'order', 'pharmacy', 'system', 'prescription', 'reminder'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.notification_id,
            'user_id': self.user_id,
            'type': self.type,
            'message': self.message,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }