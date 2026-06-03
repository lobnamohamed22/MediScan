import math

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    حساب المسافة بين نقطتين باستخدام Haversine formula
    النتيجة بالكيلومتر
    """
    R = 6371  # نصف قطر الأرض بالكيلومتر
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = math.sin(dlat/2) * math.sin(dlat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlon/2) * math.sin(dlon/2)
    
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    distance = R * c
    
    return distance

def is_pharmacy_open(working_hours):
    """التحقق مما إذا كانت الصيدلية مفتوحة الآن"""
    # دي function بسيطة، هتتطور بعدين
    return True