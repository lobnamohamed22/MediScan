import uuid
from extensions import db

class FamilyProfile(db.Model):
    __tablename__ = 'family_profiles'
    
    family_id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    parent_user_id = db.Column(db.String(36), db.ForeignKey('users.user_id'), nullable=False)
    member_name = db.Column(db.String(100), nullable=False)
    relation = db.Column(db.String(50), nullable=False)
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.String(10), nullable=True)
    phone_number = db.Column(db.String(20), nullable=True)
    medical_conditions = db.Column(db.Text)
    
    def to_dict(self):
        return {
            'id': self.family_id,
            'parent_user_id': self.parent_user_id,
            'member_name': self.member_name,
            'relation': self.relation,
            'date_of_birth': self.date_of_birth.isoformat() if self.date_of_birth else None,
            'gender': self.gender,
            'phone_number': self.phone_number,
            'medical_conditions': self.medical_conditions
        }
