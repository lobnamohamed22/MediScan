from dotenv import load_dotenv
load_dotenv()

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
import requests
import os

chatbot_bp = Blueprint('chatbot', __name__)

API_KEY = os.getenv("GOOGLE_API_KEY")

SYSTEM_PROMPT = """
You are MediScan AI Assistant.
Answer in the same language as the user.
"""

@chatbot_bp.route('/message', methods=['POST'])
@jwt_required()
def send_message():
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                'success': False,
                'message': 'No JSON data received'
            }), 400

        user_message = data.get('message')

        if not user_message:
            return jsonify({
                'success': False,
                'message': 'Message is required'
            }), 400

        prompt = f"{SYSTEM_PROMPT}\nUser: {user_message}"

        headers = {
            "Content-Type": "application/json"
        }

        body = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": prompt
                        }
                    ]
                }
            ]
        }

        # List of models to try. We prioritize gemini-1.5-flash since it has the highest free tier quota (1,500 RPD).
        # We fall back to other models if it is rate-limited or unavailable.
        models_to_try = [
            "gemini-1.5-flash",
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-flash-latest",
            "gemini-1.5-pro"
        ]

        reply = None
        success = False
        last_error = None

        for model_name in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={API_KEY}"
            try:
                print(f"Attempting Gemini API request using model: {model_name}...")
                response = requests.post(url, headers=headers, json=body, timeout=12)
                
                print(f"Model: {model_name} | STATUS: {response.status_code}")
                
                if response.status_code == 200:
                    result = response.json()
                    if "candidates" in result and result["candidates"]:
                        candidate = result["candidates"][0]
                        if "content" in candidate and "parts" in candidate["content"] and candidate["content"]["parts"]:
                            reply = candidate["content"]["parts"][0]["text"]
                            success = True
                            print(f"Successfully retrieved reply from model: {model_name}")
                            break
                        else:
                            last_error = f"Invalid candidate structure in response for {model_name}: {result}"
                    else:
                        last_error = f"No candidates found in response for {model_name}: {result}"
                else:
                    last_error = f"Model {model_name} failed with status {response.status_code}: {response.text}"
            except Exception as e:
                last_error = f"Exception occurred when calling {model_name}: {str(e)}"
                print(last_error)

        if not success:
            print(f"All Gemini models failed. Last error: {last_error}")
            # Detect language of user message to provide the perfect friendly fallback response
            import re
            is_arabic = bool(re.search(r'[\u0600-\u06FF]', user_message))
            
            if is_arabic:
                reply = "عذراً! يبدو أن المساعد الذكي يواجه ضغطاً كبيراً في طلبات الخدمة حالياً ومستنفذ لحصته المخصصة. يرجى المحاولة مرة أخرى لاحقاً، نحن نسعى جاهدين لخدمتك."
            else:
                reply = "We apologize! The MediScan AI Assistant is currently experiencing extremely high demand and has exhausted its request quota. Please try again in a few moments."
            
            # We return a successful HTTP status with the friendly fallback reply so the frontend/chat UI doesn't crash
            return jsonify({
                "success": True,
                "reply": reply,
                "is_fallback": True,
                "debug_info": last_error
            }), 200

        return jsonify({
            "success": True,
            "reply": reply
        }), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@chatbot_bp.route('/test', methods=['GET'])
def test():
    return jsonify({
        'success': True,
        'message': 'Chatbot routes working'
    }), 200