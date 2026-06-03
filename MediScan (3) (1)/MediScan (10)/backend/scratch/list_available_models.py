import os
import google.generativeai as genai

api_key = os.getenv('GOOGLE_API_KEY') or os.getenv('GEMINI_API_KEY')
if not api_key:
    with open('.env', 'r') as f:
        for line in f:
            if line.startswith('GOOGLE_API_KEY='):
                api_key = line.split('=', 1)[1].strip()
                break

genai.configure(api_key=api_key)

try:
    for m in genai.list_models():
        if 'generateContent' in m.supported_generation_methods:
            print(f"Name: {m.name} | Description: {m.description}")
except Exception as e:
    print(f"Error: {e}")
