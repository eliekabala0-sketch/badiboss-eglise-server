from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict

app = FastAPI(title="Badiboss Eglise API", version="1.0.0")

# Autoriser l'app Flutter (important)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MODELE ATTENDU PAR /login ---
class LoginRequest(BaseModel):
    church_code: str
    phone: str
    password: str

# --- Base simple (DEMO) : tu peux remplacer par DB plus tard ---
CHURCH_USERS: Dict[str, Dict[str, str]] = {
    "CH001": {
        "admin": "1234",   # téléphone/username = admin, mot de passe = 1234
        "0810000000": "1234"
    }
}

@app.get("/")
def root():
    return {"status": "ok", "app": "Badiboss Eglise API"}

# Route principale utilisée par Flutter
@app.post("/login")
def login(data: LoginRequest):
    church = data.church_code.strip().upper()
    phone = data.phone.strip()
    pwd = data.password.strip()

    if church not in CHURCH_USERS:
        raise HTTPException(status_code=401, detail="Code église invalide")

    if phone not in CHURCH_USERS[church]:
        raise HTTPException(status_code=401, detail="Utilisateur invalide")

    if CHURCH_USERS[church][phone] != pwd:
        raise HTTPException(status_code=401, detail="Mot de passe invalide")

    return {
        "success": True,
        "church_code": church,
        "user": phone,
        "token": f"demo-token-{church}-{phone}"
    }

# (Optionnel) Alias si plus tard tu veux /auth/login ou /church/login
@app.post("/auth/login")
def login_auth(data: LoginRequest):
    return login(data)

@app.post("/church/login")
def login_church(data: LoginRequest):
    return login(data)
