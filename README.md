# 🩺 MediScan: Smart Prescription Scanning & Digitization Platform
An AI-powered mobile and backend system designed for automated handwritten medical prescription analysis, digitizing medication data, and extracting drug information using Gemini Vision API.

---

### 📌 About the Project
**MediScan** is a smart healthcare application designed to automate the process of reading and digitizing handwritten doctor prescriptions. The application allows patients to scan their prescriptions, extract the medication names and dosages automatically, and manage their parsed medical records.

The system is built as a graduation project, featuring a mobile application (Flutter) and a secure REST API backend (Python Flask) integrated with state-of-the-art Generative AI models.

---

## 🚀 Key Technical Features

### 1. 🤖 AI-Driven Prescription OCR
* **Dual OCR Engine**: Uses the **Google Gemini Vision API** for high-accuracy handwriting recognition of doctor prescriptions. Falls back automatically to local **EasyOCR** processing if rate limits (HTTP 429) or offline states occur.
* **File Deduplication (MD5)**: The backend calculates the MD5 checksum of every uploaded prescription image. If a user uploads a duplicate image, the backend retrieves the cached OCR results instantly, avoiding redundant Gemini API calls and saving resource quotas.
* **Fuzzy Medicine Matching**: Resolves physician handwriting variations and OCR noise by stripping quantitative dosage suffixes (e.g., `500mg`, `1g`, `10ml`, `tablets`, `gel`) via regex, and comparing the base drug names using `difflib.SequenceMatcher` (threshold $\ge 0.85$).


---

## 🏗️ System Workflow Diagrams

### AI OCR & Verification Pipeline
```mermaid
graph TD
    A[User Uploads Prescription Photo] --> B[POST /api/prescriptions/upload]
    B --> C[Calculate File MD5 Hash]
    C --> D{Is Hash Registered in DB?}
    D -- Yes --> E[Instant Cache Read: Duplicate OCR Data]
    D -- No --> F[Call Gemini Vision API]
    F --> G{Did Gemini Succeed?}
    G -- Yes --> H[Extract Cleaned JSON List]
    G -- No --> I[Run Local EasyOCR Fallback]
    H --> J[Strip Dosage Suffixes via Regex]
    I --> J
    J --> K[Fuzzy Match Base Name via SequenceMatcher]
    K --> L{Match Found in Catalog?}
    L -- Yes --> M[Link Existing Medicine & Inventory]
    L -- No --> N[Self-Learning Auto-Creation: Pending status]
    M --> O[Store Prescription & Line Items]
    N --> O
    O --> P[User Verifies/Edits Scanned Items]
    P --> Q[PUT /api/prescriptions/id/verify]
    Q --> R[Status Updated to 'processed']
```

---

## 📂 Repository Structure

The project is structured into three main component layers:

```text
MediScan/
├── backend/                         # Flask REST API Backend
│   ├── app.py                       # Application Entry Point & Blueprint Registration
│   ├── config.py                    # Environment Configuration (MySQL, JWT, Gemini)
│   ├── extensions.py                # Shared SQLAlchemy & JWT Instances
│   ├── requirements.txt             # Python Package Matrix
│   ├── models/                      # SQLAlchemy Database Models
│   │   ├── user.py                  # User profiles and authentication
│   │   ├── pharmacy.py              # Pharmacy profiles and spatial GPS points
│   │   ├── medicine.py              # Drug catalog, inventory, and generic alternatives
│   │   ├── prescription.py          # Prescription records and parsed line items
│   │   ├── order.py                 # Delivery tracking & order states
│   │   └── notification.py          # App alerts & notifications
│   ├── routes/                      # API Endpoint Controller Blueprints
│   │   ├── auth.py                  # User signup, logins, and session control
│   │   ├── medicines.py             # Medicine directory, fuzzy search, and alternatives
│   │   ├── prescriptions.py         # OCR uploads, validation, and verification
│   │   ├── pharmacies.py            # Nearby maps, spatial queries, and pharmacist management
│   │   ├── orders.py                # Order checkout, driver tracking, and chats
│   │   └── chatbot.py               # AI chatbot session logic
│   └── static/                      # Web Panel static folders (Admin, Pharmacy, Delivery)
│
├── mobile/                          # Flutter Mobile Client Application
│   ├── lib/
│   │   ├── main.dart                # App Entry Point & Route definitions
│   │   ├── models/                  # Local data models
│   │   ├── screens/                 # UI Screen Widgets (Patient, Pharmacist, Driver Views)
│   │   ├── services/                # Backend API HTTP request handling
│   │   └── widgets/                 # Reusable UI elements (Custom buttons, cards, chatbot FAB)
│   ├── pubspec.yaml                 # Flutter Dependencies
│   └── assets/                      # Application icons, images, and static graphics
│
└── database/                        # Database Dumps and Migrations
    └── pharmacies_dump.sql          # Pre-seeded database catalog & schema dump
```

---

## 🔌 API Endpoint Summary
The backend exposes a comprehensive set of RESTful endpoints. The core groups include:

| Endpoint Prefix | Description | Auth Required |
|---|---|---|
| `/api/auth` | User Registration, JWT Login, Password Reset | Mixed |
| `/api/users` | Profile view/edit, avatar upload, family accounts | JWT Bearer |
| `/api/medicines` | Fuzzy search, alternative recommendations, recall checks | JWT Bearer |
| `/api/prescriptions` | OCR upload (Gemini/EasyOCR), item editing, and validation | JWT Bearer |
| `/api/pharmacies` | Spatial nearby search, inventory management | JWT Bearer |
| `/api/orders` | Order checkout, status updates, GPS tracking, driver chat | JWT Bearer |
| `/api/chatbot` | Conversational query interface with Gemini | JWT Bearer |

---

## 🛠️ Setup & Installation

### Backend Setup (Python Flask)
1. **Prerequisites**: Ensure Python 3.9+ and MySQL (or MariaDB via XAMPP) are installed on your machine.
2. **Clone the Repository**:
   ```bash
   git clone https://github.com/lobnamohamed22/MediScan.git
   cd MediScan/backend
   ```
3. **Create a Virtual Environment**:
   ```bash
   python -m venv venv
   source venv/Scripts/activate # On Windows: venv\Scripts\activate
   ```
4. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
5. **Configure Environment Variables**:
   Create a `.env` file in the `backend` folder:
   ```ini
   SECRET_KEY=your_flask_secret_key
   JWT_SECRET_KEY=your_jwt_secret_key
   DATABASE_URL=mysql+pymysql://username:password@localhost/mediscan_db
   GOOGLE_API_KEY=your_gemini_api_key
   UPLOAD_FOLDER=uploads
   ```
6. **Set Up the Database**:
   * Open your MySQL client (e.g., phpMyAdmin) and create a database named `mediscan_db`.
   * Import the SQL schema and seed files from the `backend/pharmacies_dump.sql` or `database/` folder.
7. **Run the Backend Server**:
   ```bash
   python app.py
   ```
   The API will start running locally at `http://127.0.0.1:5000/`.

### Mobile Frontend Setup (Flutter)
1. **Prerequisites**: Install Flutter SDK (version 3.x) and Android Studio / Xcode.
2. **Navigate to the Mobile Folder**:
   ```bash
   cd ../mobile
   ```
3. **Install Packages**:
   ```bash
   flutter pub get
   ```
4. **Configure Backend URL**:
   Update your backend API base URL inside the network client files (located in `lib/services/api_service.dart` or corresponding config files) to point to your Flask server (e.g., `http://10.0.2.2:5000` for Android emulator or your local machine IP).
5. **Run the Application**:
   ```bash
   flutter run
   ```
