import time
import threading
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash
from extensions import db
from sqlalchemy import text
from models.order import DeliveryOrder
from models.pharmacy import Pharmacy
from models.user import User
from models.order_message import OrderMessage

orders_bp = Blueprint('orders', __name__)

def generate_delivery_route_11_points(start_lat, start_lng, end_lat, end_lng):
    points = []
    points.append([start_lat, start_lng])
    
    d_lat = end_lat - start_lat
    d_lng = end_lng - start_lng
    
    # Perpendicular vector to create street bends
    perp_lat = -d_lng
    perp_lng = d_lat
    
    # We will define perp offsets for indices 1 to 9
    # This creates a realistic street-grid path with turns
    perp_scales = [0.0, 0.1, 0.15, 0.05, -0.1, -0.15, -0.05, 0.08, 0.04, 0.0]
    
    for i in range(1, 10):
        fraction = i / 10.0
        perp_scale = perp_scales[i]
        lat = start_lat + d_lat * fraction + perp_lat * perp_scale
        lng = start_lng + d_lng * fraction + perp_lng * perp_scale
        points.append([lat, lng])
        
    points.append([end_lat, end_lng])
    return points


# -------------------------------
# 1. CREATE ORDER
# -------------------------------
@orders_bp.route('', methods=['POST'])
@jwt_required()
def create_order():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        required = ['pharmacy_id', 'quantity', 'total_price']
        for field in required:
            if field not in data:
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
        
        new_order = DeliveryOrder(
            user_id=user_id,
            pharmacy_id=data['pharmacy_id'],
            quantity=data['quantity'],
            total_price=data['total_price'],
            status='assigned',
            payment_status='pending',
            medicines=data.get('medicines', [])
        )
        
        db.session.add(new_order)
        
        # Decrement stock in pharmacy inventory
        from models.medicine import MedicineInventory
        pharmacy_id = data['pharmacy_id']
        for m in data.get('medicines', []):
            med_name = m.get('name') or m.get('medicine_name')
            qty = m.get('quantity', 1)
            if med_name:
                inv_item = MedicineInventory.query.filter_by(
                    pharmacy_id=pharmacy_id,
                    medicine_name=med_name
                ).first()
                if inv_item:
                    inv_item.stock_quantity = max(0, inv_item.stock_quantity - qty)
        
        # Get pharmacy name
        pharmacy_name = "the pharmacy"
        pharm_obj = Pharmacy.query.get(data['pharmacy_id'])
        if pharm_obj and pharm_obj.name:
            pharmacy_name = pharm_obj.name

        # Create notification for order placement
        from models.notification import Notification
        notif = Notification(
            user_id=user_id,
            type='order',
            message=f"Your order for {new_order.quantity} item(s) has been successfully placed at {pharmacy_name}!"
        )
        db.session.add(notif)
        
        # Notify pharmacy owner
        if pharm_obj and pharm_obj.owner_id:
            notif_owner = Notification(
                user_id=pharm_obj.owner_id,
                type='order',
                message=f"New incoming order placed for pharmacy {pharmacy_name}!"
            )
            db.session.add(notif_owner)
            
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Order created',
            'data': new_order.to_dict()
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. GET USER ORDERS
# -------------------------------
@orders_bp.route('', methods=['GET'])
@jwt_required()
def get_orders():
    try:
        user_id = get_jwt_identity()
        print(f"[backend] GET /api/orders - Fetching orders for user_id: {user_id}", flush=True)
        
        results = db.session.query(DeliveryOrder, Pharmacy.name).outerjoin(
            Pharmacy, DeliveryOrder.pharmacy_id == Pharmacy.pharmacy_id
        ).filter(DeliveryOrder.user_id == user_id).all()
        
        print(f"[backend] GET /api/orders - Found {len(results)} orders for user_id: {user_id}", flush=True)
        
        data = []
        for order, pharm_name in results:
            o_dict = order.to_dict()
            o_dict['pharmacy_name'] = pharm_name if pharm_name else 'Unknown Pharmacy'
            
            # ensure medicines is a list of strings for frontend compatibility
            # if we have complex dicts, map them to names for order history summary
            meds_list = []
            if order.medicines:
                for m in order.medicines:
                    if isinstance(m, dict):
                        meds_list.append(f"{m.get('name', 'Unknown')} x{m.get('quantity', 1)}")
                    else:
                        meds_list.append(str(m))
            o_dict['medicines'] = meds_list if meds_list else ['Prescribed Items']
            
            data.append(o_dict)

        return jsonify({
            'success': True,
            'data': data
        }), 200
    except Exception as e:
        print(f"[backend] GET /api/orders - Exception: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. GET TRACKING INFO
# -------------------------------
@orders_bp.route('/<string:order_id>/tracking', methods=['GET'])
@jwt_required()
def get_tracking(order_id):
    try:
        order = DeliveryOrder.query.get(order_id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        driver_name = None
        driver_phone = None
        is_simulated = False
        if order.delivery_person_id:
            driver = User.query.get(order.delivery_person_id)
            if driver:
                driver_name = driver.full_name
                driver_phone = driver.phone
                if driver.email == 'driver_sim@mediscan.com':
                    is_simulated = True
                    
        if driver_name and ('sim' in driver_name.lower() or driver_name == 'Speedy Delivery (Sim)'):
            driver_name = "Mohamed Ahmed"
                
        pharmacy = Pharmacy.query.get(order.pharmacy_id)
        pharm_name = pharmacy.name if pharmacy else "Pharmacy"
        pharm_lat = float(pharmacy.latitude) if (pharmacy and pharmacy.latitude) else 30.0544
        pharm_lng = float(pharmacy.longitude) if (pharmacy and pharmacy.longitude) else 31.2457
        
        cust_lat = float(order.customer_lat) if order.customer_lat is not None else 30.0444
        cust_lng = float(order.customer_lng) if order.customer_lng is not None else 31.2357
        
        if is_simulated:
            pharm_lat = cust_lat + 0.02
            pharm_lng = cust_lng + 0.02
            
        route_points = generate_delivery_route_11_points(pharm_lat, pharm_lng, cust_lat, cust_lng)
        
        # Get driver current location
        driver_lng = None
        driver_lat = None
        if order.tracking_location:
            loc_result = db.session.execute(
                text("SELECT ST_X(tracking_location), ST_Y(tracking_location) FROM delivery_orders WHERE order_id = :order_id"),
                {'order_id': order_id}
            ).fetchone()
            if loc_result:
                driver_lng = float(loc_result[0]) if loc_result[0] is not None else None
                driver_lat = float(loc_result[1]) if loc_result[1] is not None else None
                
        # If driver location is not set yet but the order is assigned/picked_up, position driver
        if driver_lat is None or driver_lng is None:
            if is_simulated:
                driver_lat = route_points[3][0]
                driver_lng = route_points[3][1]
            else:
                driver_lat = pharm_lat
                driver_lng = pharm_lng
            
        return jsonify({
            'success': True,
            'data': {
                'order_id': order.order_id,
                'status': order.status,
                'payment_status': order.payment_status,
                'delivery_lat': driver_lat,
                'delivery_lng': driver_lng,
                'driver_name': driver_name,
                'driver_phone': driver_phone,
                'pharmacy_name': pharm_name,
                'pharmacy_lat': pharm_lat,
                'pharmacy_lng': pharm_lng,
                'customer_lat': cust_lat,
                'customer_lng': cust_lng,
                'route_points': route_points
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 4. UPDATE DRIVER GPS LOCATION
# -------------------------------
@orders_bp.route('/<string:order_id>/location', methods=['PATCH'])
@jwt_required()
def update_location(order_id):
    try:
        driver_id = get_jwt_identity()
        data = request.get_json()
        lat = data.get('lat')
        lng = data.get('lng')

        if not lat or not lng:
            return jsonify({'success': False, 'message': 'lat and lng required'}), 400

        db.session.execute(
            text("""UPDATE delivery_orders 
                    SET tracking_location = POINT(:lng, :lat)
                    WHERE order_id = :order_id 
                    AND delivery_person_id = :driver_id"""),
            {'lng': lng, 'lat': lat, 'order_id': order_id, 'driver_id': driver_id}
        )
        db.session.commit()

        return jsonify({'success': True, 'message': 'Location updated'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 5. SIMULATE DELIVERY
# -------------------------------
def simulation_worker(app_context, order_id):
    with app_context:
        try:
            # Step 1: Wait and set picked_up
            time.sleep(3)
            order = DeliveryOrder.query.get(order_id)
            if order:
                order.status = 'picked_up'
                from models.notification import Notification
                notif = Notification(
                    user_id=order.user_id,
                    type='order',
                    message="The driver has picked up your order and is heading your way."
                )
                db.session.add(notif)
                db.session.commit()
                
            # Get pharmacy location
            pharm_lat, pharm_lng = 30.0544, 31.2457
            pharmacy = None
            if order:
                pharmacy = Pharmacy.query.get(order.pharmacy_id)
            if pharmacy and pharmacy.latitude and pharmacy.longitude:
                pharm_lat = float(pharmacy.latitude)
                pharm_lng = float(pharmacy.longitude)
                
            customer_lat = float(order.customer_lat) if (order and order.customer_lat is not None) else 30.0444
            customer_lng = float(order.customer_lng) if (order and order.customer_lng is not None) else 31.2357
            
            # Check if driver is simulated driver
            is_simulated = False
            if order and order.delivery_person_id:
                driver = User.query.get(order.delivery_person_id)
                if driver and driver.email == 'driver_sim@mediscan.com':
                    is_simulated = True
                    pharm_lat = customer_lat + 0.02
                    pharm_lng = customer_lng + 0.02
                    
            if is_simulated:
                route_points = generate_delivery_route_11_points(pharm_lat, pharm_lng, customer_lat, customer_lng)
            else:
                route_points = []
                for i in range(11):
                    frac = i / 10.0
                    lat = pharm_lat + (customer_lat - pharm_lat) * frac
                    lng = pharm_lng + (customer_lng - pharm_lng) * frac
                    route_points.append([lat, lng])
                
            # Step 2: Wait and set in_transit, initial location (at pharmacy)
            time.sleep(3)
            order = DeliveryOrder.query.get(order_id)
            if order:
                order.status = 'in_transit'
                from models.notification import Notification
                notif = Notification(
                    user_id=order.user_id,
                    type='order',
                    message="Your order is now in transit / out for delivery!"
                )
                db.session.add(notif)
                db.session.execute(
                    text("UPDATE delivery_orders SET tracking_location = POINT(:lng, :lat) WHERE order_id = :order_id"),
                    {'lng': pharm_lng, 'lat': pharm_lat, 'order_id': order_id}
                )
                db.session.commit()
                
            # Step 3: Move over 10 ticks FROM pharmacy TO customer location (route Pharmacy ➜ Customer)
            for i in range(1, 11):
                time.sleep(2)
                curr_lat = route_points[i][0]
                curr_lng = route_points[i][1]
                
                db.session.execute(
                    text("UPDATE delivery_orders SET tracking_location = POINT(:lng, :lat) WHERE order_id = :order_id"),
                    {'lng': curr_lng, 'lat': curr_lat, 'order_id': order_id}
                )
                db.session.commit()
                
            # Step 4: Delivered
            time.sleep(2)
            order = DeliveryOrder.query.get(order_id)
            if order:
                order.status = 'delivered'
                from models.notification import Notification
                notif = Notification(
                    user_id=order.user_id,
                    type='order',
                    message="Your order has been successfully delivered!"
                )
                db.session.add(notif)
                db.session.commit()
        except Exception as e:
            import traceback
            print("SIMULATION EXCEPTION:", str(e))
            traceback.print_exc()
            db.session.rollback()

@orders_bp.route('/<string:order_id>/simulate', methods=['POST'])
@jwt_required()
def simulate_delivery(order_id):
    try:
        order = DeliveryOrder.query.get(order_id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        data = request.get_json() or {}
        cust_lat = data.get('customer_lat')
        cust_lng = data.get('customer_lng')
        if cust_lat is not None and cust_lng is not None:
            order.customer_lat = cust_lat
            order.customer_lng = cust_lng
            db.session.commit()
            
        driver = User.query.filter_by(email='driver_sim@mediscan.com').first()
        import random
        driver_names = ['Ahmed Ali', 'Mohamed Hassan', 'Omar Khaled', 'Mostafa Ibrahim', 'Youssef Mahmoud', 'Mohamed Ahmed']
        if not driver:
            driver = User(
                email='driver_sim@mediscan.com',
                phone='01099999999',
                password_hash=generate_password_hash('password123'),
                full_name=random.choice(driver_names),
                role='delivery',
                is_verified=True
            )
            db.session.add(driver)
            db.session.commit()
        else:
            if driver.full_name == 'Speedy Delivery (Sim)' or 'sim' in driver.full_name.lower():
                driver.full_name = random.choice(driver_names)
                db.session.commit()
            
        order.delivery_person_id = driver.user_id
        order.status = 'assigned'
        
        # Reset tracking location to Pharmacy coordinates (offset if simulated)
        pharmacy = Pharmacy.query.get(order.pharmacy_id)
        if pharmacy and pharmacy.latitude and pharmacy.longitude:
            p_lat = float(pharmacy.latitude)
            p_lng = float(pharmacy.longitude)
            
            if driver and driver.email == 'driver_sim@mediscan.com':
                cust_lat = float(order.customer_lat) if order.customer_lat is not None else 30.0444
                cust_lng = float(order.customer_lng) if order.customer_lng is not None else 31.2357
                p_lat = cust_lat + 0.02
                p_lng = cust_lng + 0.02
                
            db.session.execute(
                text("UPDATE delivery_orders SET tracking_location = POINT(:lng, :lat) WHERE order_id = :order_id"),
                {'lng': p_lng, 'lat': p_lat, 'order_id': order_id}
            )
        db.session.commit()
        
        # Start background thread
        app_context = current_app.app_context()
        thread = threading.Thread(target=simulation_worker, args=(app_context, order_id))
        thread.daemon = True
        thread.start()
        
        return jsonify({'success': True, 'message': 'Simulation started'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

def auto_reply_worker(app_context, order_id, driver_id):
    with app_context:
        # Wait a very short duration to feel dynamic and instant but still natural
        time.sleep(0.15)
        try:
            import os
            import requests
            
            order = DeliveryOrder.query.get(order_id)
            if not order:
                return
            
            driver = User.query.get(driver_id)
            driver_name = driver.full_name if driver else "Speedy Delivery (Sim)"
            
            customer = User.query.get(order.user_id)
            customer_name = customer.full_name if customer else "Customer"
            
            pharmacy = Pharmacy.query.get(order.pharmacy_id)
            pharmacy_name = pharmacy.name if pharmacy else "Local Pharmacy"
            
            order_status = order.status
            total_price = order.total_price
            
            # Map medicines list to a clean string
            meds_list = []
            if order.medicines:
                for m in order.medicines:
                    if isinstance(m, dict):
                        meds_list.append(f"{m.get('name', 'Unknown')} (x{m.get('quantity', 1)})")
                    else:
                        meds_list.append(str(m))
            medicines_string = ", ".join(meds_list) if meds_list else "Prescribed Items"
            
            # Retrieve conversation history
            chat_history = OrderMessage.query.filter_by(order_id=order_id).order_by(OrderMessage.created_at.asc()).all()
            
            # Build history turns strictly alternating and starting with user
            history_turns = []
            for msg in chat_history:
                role = "user" if msg.sender_id != driver_id else "model"
                if history_turns and history_turns[-1]["role"] == role:
                    # Combine consecutive messages from the same sender
                    history_turns[-1]["parts"][0]["text"] += "\n" + msg.message
                else:
                    history_turns.append({
                        "role": role,
                        "parts": [{"text": msg.message}]
                    })
            
            # Ensure sequence starts with user
            if history_turns and history_turns[0]["role"] != "user":
                history_turns.pop(0)
            
            # Formulate system prompt
            system_prompt = f"""You are the delivery driver, {driver_name}, delivering a medicine order from {pharmacy_name} to the customer, {customer_name}.
Current order details:
- Order Status: {order_status} (options: assigned, picked_up, in_transit, delivered)
- Total Price: {total_price} EGP
- Medicines included: {medicines_string}
- Pharmacy: {pharmacy_name}

Your goal is to reply to the customer's message in a helpful, friendly, and natural manner as a real-time delivery driver.
Guidelines:
1. Respond in the SAME language that the user is using (e.g. Arabic, English). Be extremely natural.
2. If the user asks about ETA, status, or what is being delivered, use the order details:
   - 'assigned': You are at the pharmacy waiting for the order to be prepared.
   - 'picked_up': You just received it and are setting off.
   - 'in_transit': You are on your way, driving now.
   - 'delivered': You already handed it over.
3. Be professional, conversational, and warm.
4. Keep the response concise, suitable for a chat message. Avoid markdown formatting, bullets, or headers. Respond with the plain text message only."""

            api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
            
            reply_text = None
            if api_key and api_key != "YOUR_GEMINI_API_KEY":
                try:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key={api_key}"
                    
                    body = {
                        "contents": history_turns,
                        "systemInstruction": {
                            "parts": [{"text": system_prompt}]
                        }
                    }
                    
                    headers = {"Content-Type": "application/json"}
                    res = requests.post(url, json=body, headers=headers, timeout=5)
                    
                    if res.status_code == 200:
                        result = res.json()
                        if "candidates" in result and result["candidates"]:
                            reply_text = result["candidates"][0]["content"]["parts"][0]["text"].strip()
                    else:
                        print(f"Gemini API returned status code {res.status_code}: {res.text}")
                except Exception as api_err:
                    print(f"Error during Gemini API call: {api_err}")
            if not reply_text:
                # Get last user message to detect language and intent
                last_user_msg = ""
                for msg in reversed(chat_history):
                    if msg.sender_id != driver_id:
                        last_user_msg = msg.message.lower()
                        break
                        
                is_arabic = any('\u0600' <= char <= '\u06FF' for char in last_user_msg)
                
                is_greeting = any(k in last_user_msg for k in ["hi", "hello", "hey", "driver", "يا هلا", "مرحبا", "سلام", "أهلاً"])
                is_where = any(k in last_user_msg for k in ["where", "status", "location", "وين", "فين", "مكان", "موقع"])
                is_eta = any(k in last_user_msg for k in ["eta", "how long", "time", "when", "arrive", "متى", "وقت", "بتوصل", "تاخر", "كم من الوقت"])
                is_coming = any(k in last_user_msg for k in ["coming", "heading", "on your way", "are you", "جاي", "واصل", "تحركت", "طريق"])
                is_thanks = any(k in last_user_msg for k in ["thanks", "thank", "ok", "great", "تمام", "شكرا", "ماشي", "تسلم"])
                
                if is_arabic:
                    if order_status == 'delivered':
                        if is_thanks:
                            reply_text = "على الرحب والسعة! أتمنى لك الشفاء العاجل."
                        else:
                            reply_text = "لقد قمت بتسليم الطلب بالفعل. أتمنى لك الشفاء العاجل!"
                    elif order_status == 'assigned':
                        if is_greeting:
                            reply_text = "أهلاً بك! كيف أقدر أساعدك؟"
                        elif is_where:
                            reply_text = "أنا حالياً عند الصيدلية وجاري تجهيز طلبك."
                        elif is_coming:
                            reply_text = "نعم، أنا في الصيدلية الآن وسأنطلق فور تجهيز طلبك مباشرة."
                        elif is_eta:
                            reply_text = "سيتطلب الأمر حوالي 10-15 دقيقة حتى تنتهي الصيدلية من تجهيزه."
                        else:
                            reply_text = "أهلاً بك! أنا بانتظار تجهيز طلبك في الصيدلية حالياً."
                    elif order_status == 'picked_up':
                        if is_greeting:
                            reply_text = "أهلاً بك! استلمت طلبك وجاري التحرك حالاً."
                        elif is_where:
                            reply_text = "استلمت الطلب للتو من الصيدلية وجاري التحرك إليك."
                        elif is_coming:
                            reply_text = "نعم، استلمت الطلب للتو وجاري التحرك إليك حالاً."
                        elif is_eta:
                            reply_text = "استلمته للتو! سأكون عندك خلال 10-12 دقيقة تقريباً."
                        else:
                            reply_text = "استلمت طلبك وجاري الاستعداد للانطلاق حالاً."
                    elif order_status == 'in_transit':
                        if is_greeting:
                            reply_text = "أهلاً بك! أنا في الطريق إليك الآن."
                        elif is_where:
                            reply_text = "أنا في الطريق إليك حالياً."
                        elif is_coming:
                            reply_text = "نعم، أنا في طريقي إليك حالياً."
                        elif is_eta:
                            reply_text = "سأصل خلال 5-10 دقائق بإذن الله."
                        else:
                            reply_text = "أنا في طريقي إليك حالياً وسأصل قريباً."
                else:
                    # English or Mixed English/Arabic
                    if order_status == 'delivered':
                        if is_thanks:
                            reply_text = "You're very welcome! Feel better soon."
                        else:
                            reply_text = "I have successfully delivered the order. Hope you feel better soon!"
                    elif order_status == 'assigned':
                        if is_greeting:
                            reply_text = "Hi, how can I help you?"
                        elif is_where:
                            reply_text = "I'm currently near the pharmacy and preparing your order."
                        elif is_coming:
                            reply_text = "Yes, I'm at the pharmacy now and will set off as soon as they finish preparing your items."
                        elif is_eta:
                            reply_text = "Around 10-15 minutes."
                        else:
                            reply_text = "Hi! I'm waiting at the pharmacy to prepare your order."
                    elif order_status == 'picked_up':
                        if is_greeting:
                            reply_text = "Hello! I just picked up your order and I'm heading out."
                        elif is_where:
                            reply_text = "I've just picked up the order from the pharmacy and I'm sorting it out to head your way."
                        elif is_coming:
                            reply_text = "Yes, I just picked it up and I'm heading out to you right now."
                        elif is_eta:
                            reply_text = "Just picked it up! I'll be there in about 10-12 minutes."
                        else:
                            reply_text = "I've picked up your order and I'm preparing to head out shortly."
                    elif order_status == 'in_transit':
                        if is_greeting:
                            reply_text = "Hello! I'm on my way."
                        elif is_where:
                            reply_text = "I'm currently on the road, heading towards your location."
                        elif is_coming:
                            reply_text = "Yes, I'm on my way now."
                        elif is_eta:
                            reply_text = "Around 5-10 minutes."
                        else:
                            reply_text = "I'm currently on my way to your location. See you soon!"
                    
            message = OrderMessage(
                order_id=order_id,
                sender_id=driver_id,
                message=reply_text
            )
            db.session.add(message)
            db.session.commit()
        except Exception as e:
            db.session.rollback()
            print(f"Error in smart AI auto reply: {e}")

# -------------------------------
# 6. GET ORDER CHAT
# -------------------------------
@orders_bp.route('/<string:order_id>/chat', methods=['GET'])
@jwt_required()
def get_order_chat(order_id):
    try:
        messages = OrderMessage.query.filter_by(order_id=order_id).order_by(OrderMessage.created_at.asc()).all()
        return jsonify({
            'success': True,
            'data': [m.to_dict() for m in messages]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 7. SEND ORDER MESSAGE
# -------------------------------
@orders_bp.route('/<string:order_id>/chat', methods=['POST'])
@jwt_required()
def send_order_message(order_id):
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        text_msg = data.get('message')
        
        if not text_msg:
            return jsonify({'success': False, 'message': 'Message is required'}), 400
            
        new_msg = OrderMessage(
            order_id=order_id,
            sender_id=user_id,
            message=text_msg
        )
        db.session.add(new_msg)
        db.session.commit()

        # Check if driver is the simulated driver to trigger auto-reply
        order = DeliveryOrder.query.get(order_id)
        if order and order.delivery_person_id:
            driver = User.query.get(order.delivery_person_id)
            if driver and driver.email == 'driver_sim@mediscan.com':
                app_context = current_app.app_context()
                thread = threading.Thread(target=auto_reply_worker, args=(app_context, order_id, driver.user_id))
                thread.daemon = True
                thread.start()

        return jsonify({'success': True, 'data': new_msg.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 8. DELIVERY DASHBOARD ROUTES
# -------------------------------
@orders_bp.route('/delivery/assigned', methods=['GET'])
@jwt_required()
def get_delivery_assigned_orders():
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if not user or user.role != 'delivery':
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        # Get active orders assigned to this driver
        # We can also return all assigned, picked_up, in_transit
        results = db.session.query(DeliveryOrder, Pharmacy.name).outerjoin(
            Pharmacy, DeliveryOrder.pharmacy_id == Pharmacy.pharmacy_id
        ).filter(DeliveryOrder.delivery_person_id == user_id).order_by(DeliveryOrder.created_at.desc()).all()
        
        data = []
        for order, pharm_name in results:
            o_dict = order.to_dict()
            o_dict['pharmacy_name'] = pharm_name if pharm_name else 'Unknown Pharmacy'
            
            meds_list = []
            if order.medicines:
                for m in order.medicines:
                    if isinstance(m, dict):
                        meds_list.append(f"{m.get('name', 'Unknown')} x{m.get('quantity', 1)}")
                    else:
                        meds_list.append(str(m))
            o_dict['medicines'] = meds_list if meds_list else ['Prescribed Items']
            
            data.append(o_dict)

        return jsonify({'success': True, 'data': data}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@orders_bp.route('/<string:order_id>/status', methods=['PATCH'])
@jwt_required()
def update_order_status(order_id):
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        data = request.get_json()
        new_status = data.get('status')
        if not new_status:
            return jsonify({'success': False, 'message': 'status required'}), 400
            
        order = DeliveryOrder.query.get(order_id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        # Verify permissions: delivery driver assigned or pharmacy owner
        if user.role == 'delivery' and order.delivery_person_id != user_id:
            return jsonify({'success': False, 'message': 'Not assigned to you'}), 403
            
        if user.role == 'pharmacy_owner':
            pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
            if not pharmacy or order.pharmacy_id != pharmacy.pharmacy_id:
                return jsonify({'success': False, 'message': 'Order not for your pharmacy'}), 403

        order.status = new_status
        
        # Generate notification on status update
        from models.notification import Notification
        status_messages = {
            'accepted': 'Your order has been accepted by the pharmacy!',
            'preparing': 'Your order is being prepared by the pharmacy.',
            'ready': 'Your order is ready for delivery.',
            'picked_up': 'The driver has picked up your order and is heading your way.',
            'in_transit': 'Your order is now in transit / out for delivery!',
            'delivered': 'Your order has been successfully delivered!',
            'rejected': 'Your order was unfortunately rejected by the pharmacy.'
        }
        if new_status in status_messages:
            notif = Notification(
                user_id=order.user_id,
                type='order',
                message=status_messages[new_status]
            )
            db.session.add(notif)
            
        # Notify delivery drivers if status is ready
        if new_status == 'ready':
            drivers = User.query.filter_by(role='delivery').all()
            for d in drivers:
                driver_notif = Notification(
                    user_id=d.user_id,
                    type='delivery',
                    message="A new order is ready for pickup! Claim it now."
                )
                db.session.add(driver_notif)
            

                
        db.session.commit()
        return jsonify({'success': True, 'message': 'Status updated', 'data': order.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 8.5 UNASSIGNED & ACCEPT DELIVERY ROUTES
# -------------------------------
@orders_bp.route('/delivery/unassigned', methods=['GET'])
@jwt_required()
def get_delivery_unassigned_orders():
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if not user or user.role != 'delivery':
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        results = db.session.query(DeliveryOrder, Pharmacy.name, Pharmacy.address).outerjoin(
            Pharmacy, DeliveryOrder.pharmacy_id == Pharmacy.pharmacy_id
        ).filter(
            DeliveryOrder.status == 'ready',
            DeliveryOrder.delivery_person_id == None
        ).order_by(DeliveryOrder.created_at.desc()).all()
        
        data = []
        for order, pharm_name, pharm_address in results:
            o_dict = order.to_dict()
            o_dict['pharmacy_name'] = pharm_name if pharm_name else 'Unknown Pharmacy'
            o_dict['pharmacy_address'] = pharm_address if pharm_address else ''
            
            meds_list = []
            if order.medicines:
                for m in order.medicines:
                    if isinstance(m, dict):
                        meds_list.append(f"{m.get('name', 'Unknown')} x{m.get('quantity', 1)}")
                    else:
                        meds_list.append(str(m))
            o_dict['medicines'] = meds_list if meds_list else ['Prescribed Items']
            data.append(o_dict)
            
        return jsonify({'success': True, 'data': data}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@orders_bp.route('/<string:order_id>/accept-delivery', methods=['POST', 'PATCH'])
@jwt_required()
def accept_delivery(order_id):
    try:
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        if not user or user.role != 'delivery':
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        order = DeliveryOrder.query.get(order_id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        if order.delivery_person_id is not None:
            return jsonify({'success': False, 'message': 'Order already claimed'}), 400
            
        order.delivery_person_id = user_id
        order.status = 'assigned'
        
        # Notify customer
        from models.notification import Notification
        notif_customer = Notification(
            user_id=order.user_id,
            type='delivery',
            message=f"Driver {user.full_name} has accepted your order and is heading to the pharmacy."
        )
        db.session.add(notif_customer)
        
        # Notify pharmacy owner
        pharmacy = Pharmacy.query.get(order.pharmacy_id)
        if pharmacy and pharmacy.owner_id:
            notif_pharmacy = Notification(
                user_id=pharmacy.owner_id,
                type='delivery',
                message=f"Driver {user.full_name} is assigned to collect Order #{order.order_id[:8]}."
            )
            db.session.add(notif_pharmacy)
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Delivery accepted', 'data': order.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 8.75 REORDER PREVIOUS ORDER
# -------------------------------
@orders_bp.route('/<string:order_id>/reorder', methods=['POST'])
@jwt_required()
def reorder_order(order_id):
    try:
        user_id = get_jwt_identity()
        old_order = DeliveryOrder.query.get(order_id)
        if not old_order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        if old_order.user_id != user_id:
            return jsonify({'success': False, 'message': 'Unauthorized to reorder this order'}), 403
            
        new_order = DeliveryOrder(
            user_id=user_id,
            pharmacy_id=old_order.pharmacy_id,
            quantity=old_order.quantity,
            total_price=old_order.total_price,
            status='assigned',
            payment_status='pending',
            medicines=old_order.medicines,
            customer_lat=old_order.customer_lat,
            customer_lng=old_order.customer_lng
        )
        db.session.add(new_order)
        
        # Decrement stock in pharmacy inventory
        from models.medicine import MedicineInventory
        pharmacy_id = old_order.pharmacy_id
        for m in (old_order.medicines or []):
            if isinstance(m, dict):
                med_name = m.get('name') or m.get('medicine_name')
                qty = m.get('quantity', 1)
            else:
                med_name = str(m)
                qty = 1
                if " x" in med_name:
                    parts = med_name.split(" x")
                    med_name = parts[0].strip()
                    try:
                        qty = int(parts[1])
                    except:
                        qty = 1
            if med_name:
                inv_item = MedicineInventory.query.filter_by(
                    pharmacy_id=pharmacy_id,
                    medicine_name=med_name
                ).first()
                if inv_item:
                    inv_item.stock_quantity = max(0, inv_item.stock_quantity - qty)
                    
        # Get pharmacy name
        pharmacy_name = "the pharmacy"
        pharm_obj = Pharmacy.query.get(pharmacy_id)
        if pharm_obj and pharm_obj.name:
            pharmacy_name = pharm_obj.name

        # Create notification for order placement
        from models.notification import Notification
        notif = Notification(
            user_id=user_id,
            type='order',
            message=f"Your reorder for {new_order.quantity} item(s) has been successfully placed at {pharmacy_name}!"
        )
        db.session.add(notif)
        
        # Notify pharmacy owner
        if pharm_obj and pharm_obj.owner_id:
            notif_owner = Notification(
                user_id=pharm_obj.owner_id,
                type='order',
                message=f"New incoming reorder placed for pharmacy {pharmacy_name}!"
            )
            db.session.add(notif_owner)
            
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Order successfully reordered',
            'data': new_order.to_dict()
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 9. PHARMACY DASHBOARD ROUTES
# -------------------------------
@orders_bp.route('/pharmacy/incoming', methods=['GET'])
@jwt_required()
def get_pharmacy_incoming_orders():
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
            
        results = db.session.query(DeliveryOrder, User.full_name, User.phone).outerjoin(
            User, DeliveryOrder.user_id == User.user_id
        ).filter(DeliveryOrder.pharmacy_id == pharmacy.pharmacy_id).order_by(DeliveryOrder.created_at.desc()).all()
        
        data = []
        for order, u_name, u_phone in results:
            o_dict = order.to_dict()
            o_dict['customer_name'] = u_name
            o_dict['customer_phone'] = u_phone
            data.append(o_dict)

        return jsonify({'success': True, 'data': data}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500