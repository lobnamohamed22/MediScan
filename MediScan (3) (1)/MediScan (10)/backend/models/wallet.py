import uuid
from extensions import db
from datetime import datetime

class WalletTransaction(db.Model):
    __tablename__ = 'wallet_transactions'
    
    transaction_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    transaction_type = db.Column(db.Enum('earn', 'redeem', 'refund'), nullable=False)
    points = db.Column(db.Integer, nullable=False)
    amount = db.Column(db.Numeric(10, 2), default=0.0)
    description = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.transaction_id,
            'user_id': self.user_id,
            'type': self.transaction_type,
            'points': self.points,
            'amount': float(self.amount) if self.amount else 0.0,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
