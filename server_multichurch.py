from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sqlite3

app = FastAPI()

# ================================
# CORS CORRIGÉ (IMPORTANT)
# ================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://lovely-manifestation-production-e17b.up.railway.app",
    ],
    allow_origin_regex=r"^https://.*\.up\.railway\.app$|^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=86400,
)

# ================================
# DATABASE (simple test SQLite)
# ================================
def get_db():
    conn = sqlite3.connect("database.db")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        church_code TEXT,
        phone TEXT,
        password TEXT
    )
    """)

    # utilisateur test
    cursor.execute("""
    INSERT OR IGNORE INTO users (id, church_code, phone, password)
    VALUES (1, 'EGLISE001', '0990000000', '123456')
    """)

    conn.commit()
    conn.close()

init_db()

# ================================
# MODELS
# ================================
class LoginRequest(BaseModel):
    church_code: str
    phone: str
    password: str

# ================================
# ROUTES
# ================================

@app.get("/")
def root():
    return {"message": "Badiboss Église API OK"}

@app.post("/church/login")
def login(data: LoginRequest):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT * FROM users 
    WHERE church_code = ? AND phone = ? AND password = ?
    """, (data.church_code, data.phone, data.password))

    user = cursor.fetchone()
    conn.close()

    if not user:
        raise HTTPException(status_code=401, detail="Identifiants invalides")

    return {
        "status": "success",
        "user": {
            "id": user["id"],
            "phone": user["phone"],
            "church_code": user["church_code"]
        }
    }

# ================================
# DEBUG ROUTE (important)
# ================================
@app.get("/test")
def test():
    return {"status": "ok"}

# ================================
# HEALTHCHECK RAILWAY
# ================================
@app.get("/health")
def health():
    return {"status": "healthy"}