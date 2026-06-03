import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from app import create_app
    app = create_app()
    print("App created successfully")
except Exception as e:
    import traceback
    print("Error importing app or creating it:")
    traceback.print_exc()
