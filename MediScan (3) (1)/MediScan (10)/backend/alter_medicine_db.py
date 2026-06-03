from app import create_app
from extensions import db
from sqlalchemy import text

app = create_app()

with app.app_context():
    try:
        # Check columns of medicine_info table
        columns = db.session.execute(text("SHOW COLUMNS FROM medicine_info")).fetchall()
        column_names = [col[0] for col in columns]
        print(f"Current columns in medicine_info table: {column_names}")
        
        if 'medicine_image' not in column_names:
            db.session.execute(text("ALTER TABLE medicine_info ADD COLUMN medicine_image VARCHAR(500) NULL"))
            db.session.commit()
            print("Successfully added medicine_image column to medicine_info table!")
        else:
            print("medicine_image column already exists in medicine_info table.")
            
    except Exception as e:
        print(f"Error altering database: {e}")
