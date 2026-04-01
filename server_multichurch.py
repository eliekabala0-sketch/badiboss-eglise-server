from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Tuple
import sqlite3
import json
import time
import secrets
import hashlib
import os

app = FastAPI(title="Badiboss Multi-Church Server", version="2.0.0")

# CORS: Flutter Web (Railway) + local dev — public routes must never fail preflight or error responses without ACAO.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=86400,
)

DB_FILE = "badiboss_multichurch.db"

# SUPER ADMIN GLOBAL (Badiboss)
SUPER_ADMIN_PHONE = "243999999999"
SUPER_ADMIN_PASSWORD = "123456"  # terrain: même simplicité que DEMO_PASSWORD

DEMO_CHURCH_CODE = "EGLISE_DEMO_MULTI01"
DEMO_PASSWORD = "123456"

def normalize_phone_rd_congo(v: str) -> str:
    """
    Normalise un numéro RDC vers format digits: 243 + 9 chiffres (donc 12 digits).
    Accepte input avec ou sans '+' et accepte aussi format local '0xxxxxxxxx'.
    """
    s = (v or "").strip()
    # ne garder que les chiffres
    digits = "".join([ch for ch in s if ch.isdigit()])
    if digits.startswith("0"):
        digits = "243" + digits[1:]
    elif not digits.startswith("243"):
        # fallback minimal: si déjà en format local sans 0/243 (rare), on préfixe
        if len(digits) == 9:
            digits = "243" + digits
    # tronquer proprement si besoin
    if len(digits) > 12:
        digits = digits[:12]
    return digits

# ---------------------------
# DB helpers
# ---------------------------
def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_FILE, check_same_thread=False, timeout=30.0)
    conn.row_factory = sqlite3.Row
    return conn

def now_ts() -> int:
    return int(time.time())

def hash_pw(pw: str) -> str:
    return hashlib.sha256(pw.encode("utf-8")).hexdigest()

def init_db():
    conn = db()
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS churches(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      is_suspended INTEGER NOT NULL DEFAULT 0,
      suspend_reason TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER,
      phone TEXT NOT NULL,
      full_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL,
      is_disabled INTEGER NOT NULL DEFAULT 0,
      permissions_json TEXT NOT NULL DEFAULT '[]',
      member_number TEXT,
      created_at INTEGER NOT NULL,
      UNIQUE(church_id, phone)
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS restrictions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      denied_permissions_json TEXT NOT NULL DEFAULT '[]',
      UNIQUE(church_id, role)
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS sessions(
      token TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL,
      church_id INTEGER,
      role TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS audit_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER,
      actor_user_id INTEGER,
      action TEXT NOT NULL,
      data_json TEXT NOT NULL DEFAULT '{}',
      created_at INTEGER NOT NULL
    )
    """)

    # Members
    cur.execute("""
    CREATE TABLE IF NOT EXISTS members(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      member_number TEXT NOT NULL,
      full_name TEXT NOT NULL,
      phone TEXT NOT NULL,
      sex TEXT NOT NULL,
      quarter TEXT NOT NULL,
      category TEXT NOT NULL,
      presence_status TEXT NOT NULL,
      marital_status TEXT NOT NULL,
      partner_member_number TEXT,
      is_validated INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      UNIQUE(church_id, member_number),
      UNIQUE(church_id, phone)
    )
    """)

    # Donations
    cur.execute("""
    CREATE TABLE IF NOT EXISTS donations(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      member_number TEXT NOT NULL,
      type TEXT NOT NULL,          -- ESPECE / NATURE
      label TEXT NOT NULL,         -- Construction, Noel...
      amount REAL NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'CDF',
      nature_desc TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )
    """)

    # Finance module (entrées / sorties + catégories)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS finance_categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      direction TEXT NOT NULL,     -- 'in' ou 'out'
      created_at INTEGER NOT NULL,
      UNIQUE(church_id, name)
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS finance_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      category_id INTEGER NOT NULL,
      direction TEXT NOT NULL,     -- redondant pour stabilité des rapports
      member_number TEXT,
      amount REAL NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'CDF',
      note TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )
    """)

    # Attendance events + records
    cur.execute("""
    CREATE TABLE IF NOT EXISTS attendance_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      title TEXT NOT NULL,          -- Culte Dimanche, Cellule...
      event_date TEXT NOT NULL,     -- YYYY-MM-DD
      created_at INTEGER NOT NULL
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS attendance_records(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      event_id INTEGER NOT NULL,
      member_number TEXT NOT NULL,
      present INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL
    )
    """)

    # Protocol: services + assignments
    cur.execute("""
    CREATE TABLE IF NOT EXISTS protocol_services(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      title TEXT NOT NULL,           -- Service/Programme
      service_date TEXT NOT NULL,    -- YYYY-MM-DD
      created_at INTEGER NOT NULL
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS protocol_assignments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      church_id INTEGER NOT NULL,
      service_id INTEGER NOT NULL,
      member_number TEXT NOT NULL,
      task TEXT NOT NULL,            -- Ex: Accueil, Sécurité, Placement...
      checked_in INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
    """)

    # Settings (member counter per church)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS church_settings(
      church_id INTEGER NOT NULL,
      key TEXT NOT NULL,
      value TEXT NOT NULL,
      PRIMARY KEY(church_id, key)
    )
    """)

    conn.commit()
    conn.close()

init_db()

def ensure_members_columns():
    """
    Idempotent schema evolution for members table.
    Adds minimal fields required by Flutter member module (address + status + soft delete).
    """
    conn = db()
    cur = conn.cursor()
    cols = cur.execute("PRAGMA table_info(members)").fetchall()
    existing = {c["name"] for c in cols} if cols else set()

    def add_col(sql: str):
        try:
            cur.execute(sql)
        except Exception:
            pass

    if "status" not in existing:
        add_col("ALTER TABLE members ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'")
    if "is_deleted" not in existing:
        add_col("ALTER TABLE members ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0")

    # Address / neighborhood (optional)
    if "commune" not in existing:
        add_col("ALTER TABLE members ADD COLUMN commune TEXT NOT NULL DEFAULT ''")
    if "zone" not in existing:
        add_col("ALTER TABLE members ADD COLUMN zone TEXT NOT NULL DEFAULT ''")
    if "address_line" not in existing:
        add_col("ALTER TABLE members ADD COLUMN address_line TEXT NOT NULL DEFAULT ''")
    if "neighborhood" not in existing:
        add_col("ALTER TABLE members ADD COLUMN neighborhood TEXT NOT NULL DEFAULT ''")
    if "region" not in existing:
        add_col("ALTER TABLE members ADD COLUMN region TEXT NOT NULL DEFAULT ''")
    if "province" not in existing:
        add_col("ALTER TABLE members ADD COLUMN province TEXT NOT NULL DEFAULT ''")
    if "birth_date" not in existing:
        add_col("ALTER TABLE members ADD COLUMN birth_date TEXT NOT NULL DEFAULT ''")
    if "member_card_payload" not in existing:
        add_col("ALTER TABLE members ADD COLUMN member_card_payload TEXT NOT NULL DEFAULT ''")

    conn.commit()
    conn.close()

ensure_members_columns()

def ensure_attendance_columns():
    conn = db()
    cur = conn.cursor()
    cols_events = cur.execute("PRAGMA table_info(attendance_events)").fetchall()
    existing_events = {c["name"] for c in cols_events} if cols_events else set()
    cols_records = cur.execute("PRAGMA table_info(attendance_records)").fetchall()
    existing_records = {c["name"] for c in cols_records} if cols_records else set()

    def add_col(sql: str):
        try:
            cur.execute(sql)
        except Exception:
            pass

    if "status" not in existing_events:
        add_col("ALTER TABLE attendance_events ADD COLUMN status TEXT NOT NULL DEFAULT 'open'")
    if "closed_at" not in existing_events:
        add_col("ALTER TABLE attendance_events ADD COLUMN closed_at INTEGER")
    if "guest_name" not in existing_records:
        add_col("ALTER TABLE attendance_records ADD COLUMN guest_name TEXT NOT NULL DEFAULT ''")

    conn.commit()
    conn.close()

ensure_attendance_columns()

def ensure_pastoral_relations_table():
    conn = db()
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS pastoral_relations(
      church_id INTEGER NOT NULL,
      relation_id TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (church_id, relation_id)
    )
    """)
    conn.commit()
    conn.close()

ensure_pastoral_relations_table()

def ensure_church_extended_tables():
    conn = db()
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS church_documents(
      church_id INTEGER NOT NULL,
      doc_key TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (church_id, doc_key)
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS church_feed_items(
      id TEXT PRIMARY KEY,
      church_id INTEGER NOT NULL,
      kind TEXT NOT NULL,
      body TEXT NOT NULL,
      audience TEXT NOT NULL,
      sender_phone TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS church_notifications(
      id TEXT PRIMARY KEY,
      church_id INTEGER NOT NULL,
      target TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      sender_phone TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      read_phones_json TEXT NOT NULL DEFAULT '[]'
    )
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS platform_kv(
      kv_key TEXT PRIMARY KEY,
      value_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
    """)
    conn.commit()
    conn.close()

ensure_church_extended_tables()

def church_document_get(church_id: int, doc_key: str) -> Dict[str, Any]:
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT payload_json FROM church_documents WHERE church_id=? AND doc_key=?",
        (church_id, doc_key),
    ).fetchone()
    conn.close()
    if not row:
        return {}
    try:
        o = json.loads(row["payload_json"])
        return o if isinstance(o, dict) else {}
    except Exception:
        return {}

def church_document_set(church_id: int, doc_key: str, payload: Dict[str, Any]) -> None:
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO church_documents(church_id, doc_key, payload_json, updated_at) VALUES(?,?,?,?) "
        "ON CONFLICT(church_id, doc_key) DO UPDATE SET payload_json=excluded.payload_json, updated_at=excluded.updated_at",
        (church_id, doc_key, json.dumps(payload, ensure_ascii=False), now_ts()),
    )
    conn.commit()
    conn.close()

def platform_kv_get(key: str) -> Dict[str, Any]:
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT value_json FROM platform_kv WHERE kv_key=?", (key,)).fetchone()
    conn.close()
    if not row:
        return {}
    try:
        o = json.loads(row["value_json"])
        return o if isinstance(o, dict) else {}
    except Exception:
        return {}

def platform_kv_set(key: str, payload: Dict[str, Any]) -> None:
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO platform_kv(kv_key, value_json, updated_at) VALUES(?,?,?) "
        "ON CONFLICT(kv_key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at",
        (key, json.dumps(payload, ensure_ascii=False), now_ts()),
    )
    conn.commit()
    conn.close()

def ensure_finance_defaults_for_church(church_id: int):
    """
    Idempotent: insère les rubriques finance par défaut si aucune n'existe.
    """
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT id FROM finance_categories WHERE church_id=? LIMIT 1",
        (church_id,),
    ).fetchone()
    if row:
        conn.close()
        return

    defaults = [
        ("Dîme", "in"),
        ("Offrande", "in"),
        ("Action de grâce", "in"),
        ("Don spécial", "in"),
        ("Dépenses", "out"),
        ("Salaires", "out"),
    ]
    created_at = now_ts()
    for name, direction in defaults:
        try:
            cur.execute(
                "INSERT INTO finance_categories(church_id, name, direction, created_at) VALUES(?,?,?,?)",
                (church_id, name, direction, created_at),
            )
        except Exception:
            pass

    conn.commit()
    conn.close()

def resolve_church_id_by_code(church_code: str) -> int:
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT id FROM churches WHERE church_code=?",
        (church_code.strip(),),
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Church not found")
    return int(row["id"])

# ---------------------------
# Permissions defaults
# ---------------------------
def default_permissions_for_role(role: str) -> List[str]:
    role = role.upper()

    perms = {
        "PASTEUR_RESPONSABLE": [
            "church.read","church.update",
            "users.read","users.create","users.update","users.disable",
            "roles.assign","permissions.assign",
            "members.read","members.create","members.update","members.archive","members.validate",
            "attendance.read","attendance.write","attendance.report",
            "finance.read","finance.write","finance.report","finance.member.read","finance.member.write",
            "relations.read","relations.write","relations.archive",
            "protocol.read","protocol.write","protocol.assign","protocol.checkin",
            "announcements.read","announcements.write","announcements.delete",
            "programs.read","programs.write",
            "me.read","me.update","me.attendance.read","me.finance.read","me.assignments.read","me.notifications.read",
        ],
        "SECRETAIRE": [
            "church.read",
            "members.read","members.create","members.update","members.validate",
            "attendance.write",
            "relations.read","relations.write","relations.archive",
            "announcements.read","announcements.write",
            "programs.read","programs.write",
            "me.read","me.update","me.attendance.read","me.finance.read","me.assignments.read","me.notifications.read",
        ],
        "FINANCE": [
            "church.read",
            "members.read",
            "finance.read","finance.write","finance.report","finance.member.read","finance.member.write",
            "announcements.read",
            "me.read","me.update","me.attendance.read","me.finance.read","me.assignments.read","me.notifications.read",
        ],
        "PROTOCOLE": [
            "church.read",
            "protocol.read","protocol.checkin",
            "announcements.read","programs.read",
            "me.read","me.update","me.attendance.read","me.finance.read","me.assignments.read","me.notifications.read",
        ],
        "MEMBRE": [
            "church.read",
            "announcements.read","programs.read",
            "messages.reply",
            "me.read","me.update","me.attendance.read","me.finance.read","me.assignments.read","me.notifications.read",
        ]
    }
    return perms.get(role, ["church.read","me.read"])

def apply_role_restrictions(church_id: int, role: str, perms: List[str]) -> List[str]:
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT denied_permissions_json FROM restrictions WHERE church_id=? AND role=?",
        (church_id, role.upper())
    ).fetchone()
    conn.close()
    if not row:
        return perms
    try:
        denied = set(json.loads(row["denied_permissions_json"] or "[]"))
    except json.JSONDecodeError:
        denied = set()
    return [p for p in perms if p not in denied]

def seed_if_empty():
    conn = db()
    cur = conn.cursor()
    church_code = "EGLISE001"
    existing = cur.execute("SELECT id FROM churches WHERE church_code=?", (church_code,)).fetchone()
    if existing:
        conn.close()
        return

    church_name = "Badiboss Église (démo)"
    created_at = now_ts()
    cur.execute(
        "INSERT INTO churches(church_code, name, is_suspended, suspend_reason, created_at) VALUES(?,?,?,?,?)",
        (church_code, church_name, 0, "", created_at),
    )
    church_id = int(cur.lastrowid)

    role = "PASTEUR_RESPONSABLE"
    perms = default_permissions_for_role(role)
    perms = apply_role_restrictions(church_id, role, perms)

    # Compte par défaut pour test Flutter (login_screen.dart)
    phone = normalize_phone_rd_congo("0990000000")
    full_name = "Compte Démo"
    password_plain = "123456"
    cur.execute(
        "INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at) "
        "VALUES(?,?,?,?,?,?,?,?,?)",
        (
            church_id,
            phone,
            full_name,
            hash_pw(password_plain),
            role,
            0,
            json.dumps(perms),
            None,
            created_at,
        ),
    )

    conn.commit()
    conn.close()

seed_if_empty()

# ---------------------------
# Auth helpers
# ---------------------------
def require_token(authorization: Optional[str]) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization header")
    return authorization.split(" ", 1)[1].strip()

def get_session(token: str) -> sqlite3.Row:
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT * FROM sessions WHERE token=?", (token,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid session token")
    return row

def get_church(church_id: int) -> sqlite3.Row:
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT * FROM churches WHERE id=?", (church_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Church not found")
    return row

def ensure_church_active(church_id: int):
    c = get_church(church_id)
    if c["is_suspended"] == 1:
        raise HTTPException(status_code=403, detail=c["suspend_reason"] or "Eglise suspendue")

def audit(church_id: Optional[int], actor_user_id: Optional[int], action: str, data: Dict[str, Any]):
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO audit_logs(church_id, actor_user_id, action, data_json, created_at) VALUES(?,?,?,?,?)",
        (church_id, actor_user_id, action, json.dumps(data, ensure_ascii=False), now_ts())
    )
    conn.commit()
    conn.close()

def actor_context(Authorization: Optional[str]) -> Dict[str, Any]:
    token = require_token(Authorization)
    ses = get_session(token)
    role = ses["role"].upper()
    church_id = ses["church_id"]
    user_id = int(ses["user_id"])
    if role != "SUPER_ADMIN":
        if church_id is None:
            raise HTTPException(status_code=403, detail="Forbidden")
        ensure_church_active(int(church_id))
    return {"role": role, "church_id": church_id, "user_id": user_id, "token": token}

def user_has_permission(church_id: int, user_id: int, perm: str) -> bool:
    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT permissions_json, role FROM users WHERE id=? AND church_id=?", (user_id, church_id)).fetchone()
    conn.close()
    if not u:
        return False
    perms = json.loads(u["permissions_json"] or "[]")
    perms = apply_role_restrictions(church_id, u["role"].upper(), perms)
    return perm in set(perms)

def require_perm(ctx: Dict[str, Any], perm: str):
    if ctx["role"] == "SUPER_ADMIN":
        return
    cid = int(ctx["church_id"])
    if not user_has_permission(cid, ctx["user_id"], perm):
        raise HTTPException(status_code=403, detail=f"Permission manquante: {perm}")

def ui_member_role_to_backend(ui: Optional[str]) -> Optional[str]:
    if not ui:
        return None
    m = {
        "membre": "MEMBRE",
        "protocole": "PROTOCOLE",
        "secretaire": "SECRETAIRE",
        "secrétaire": "SECRETAIRE",
        "finance": "FINANCE",
        "admin": "SECRETAIRE",
    }
    return m.get(ui.strip().lower())

def phone_is_church_non_member_staff(church_id: int, phone_norm: str) -> bool:
    if not phone_norm:
        return False
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT role FROM users WHERE church_id=? AND phone=?",
        (church_id, phone_norm),
    ).fetchone()
    conn.close()
    if not row:
        return False
    return (row["role"] or "").upper() != "MEMBRE"

def actor_user_phone(ctx: Dict[str, Any]) -> str:
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT phone FROM users WHERE id=?", (ctx["user_id"],)).fetchone()
    conn.close()
    return (row["phone"] or "").strip() if row else ""

def push_phone_target_notification(
    church_id: int, phone_norm: str, title: str, body: str, sender_phone: str
) -> None:
    if not phone_norm or len(phone_norm) < 12 or not phone_norm.startswith("243"):
        return
    nid = secrets.token_hex(10)
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO church_notifications(id, church_id, target, title, body, sender_phone, created_at, read_phones_json) VALUES(?,?,?,?,?,?,?,?)",
        (nid, church_id, f"phone:{phone_norm}", (title or "")[:500], (body or "")[:2000], sender_phone or "", now_ts(), "[]"),
    )
    conn.commit()
    conn.close()

def notify_member_number(
    church_id: int,
    member_number: str,
    title: str,
    body: str,
    sender_phone: str,
) -> None:
    mn = (member_number or "").strip()
    if not mn:
        return
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT phone FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
        (church_id, mn),
    ).fetchone()
    conn.close()
    if not row:
        return
    push_phone_target_notification(
        church_id, normalize_phone_rd_congo((row["phone"] or "").strip()), title, body, sender_phone
    )

def _relation_member_codes(rel: Dict[str, Any]) -> List[str]:
    out: List[str] = []
    for k in ("memberCodeA", "memberCodeB"):
        c = str(rel.get(k) or "").strip()
        if c:
            out.append(c)
    return out

def _irregular_items_dict(payload: Any) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    if not payload or not isinstance(payload, dict):
        return out
    raw = payload.get("items")
    if not isinstance(raw, list):
        return out
    for it in raw:
        if not isinstance(it, dict):
            continue
        iid = str(it.get("id") or "").strip()
        if iid:
            out[iid] = it
    return out

def _notify_irregulars_diff(church_id: int, prev: Any, new: Any, sender_phone: str) -> None:
    prev_m = _irregular_items_dict(prev)
    new_m = _irregular_items_dict(new)
    for iid, it in new_m.items():
        phone = normalize_phone_rd_congo(str(it.get("phone") or "").strip())
        if len(phone) != 12 or not phone.startswith("243"):
            continue
        shepherd = str(it.get("shepherd") or "").strip()
        status = str(it.get("status") or "").strip()
        nfu = str(it.get("nextFollowUp") or "").strip()
        old = prev_m.get(iid)
        if old is None:
            push_phone_target_notification(
                church_id,
                phone,
                "Suivi irrégularité",
                f"Un accompagnement pour irrégularité a été ouvert pour vous. Berger : {shepherd or 'à préciser'}.",
                sender_phone,
            )
            continue
        old_sh = str(old.get("shepherd") or "").strip()
        old_st = str(old.get("status") or "").strip()
        old_fu = str(old.get("nextFollowUp") or "").strip()
        parts: List[str] = []
        if old_sh != shepherd and (shepherd or old_sh):
            parts.append(f"Berger : {shepherd or old_sh}")
        if old_st != status and status:
            parts.append(f"Statut : {status}")
        if old_fu != nfu and nfu:
            parts.append(f"Prochain suivi : {nfu}")
        if parts:
            push_phone_target_notification(
                church_id,
                phone,
                "Mise à jour suivi",
                ". ".join(parts),
                sender_phone,
            )

def _notify_relations_diff(church_id: int, prev_map: Dict[str, dict], new_payloads: Dict[str, dict], sender_phone: str) -> None:
    for rel_id, rel in new_payloads.items():
        codes = _relation_member_codes(rel)
        if not codes:
            continue
        old = prev_map.get(rel_id)
        if old is None:
            for mn in codes:
                try:
                    notify_member_number(
                        church_id,
                        mn,
                        "Relation pastorale",
                        "Vous avez été associé(e) à un dossier relationnel (mariage / accompagnement).",
                        sender_phone,
                    )
                except Exception:
                    pass
            continue
        old_step = str(old.get("step") or "")
        new_step = str(rel.get("step") or "")
        old_ap = str(old.get("nextAppointment") or "")
        new_ap = str(rel.get("nextAppointment") or "")
        if old_step == new_step and old_ap == new_ap:
            continue
        detail_parts: List[str] = []
        if old_step != new_step and new_step:
            detail_parts.append(f"Étape : {new_step}")
        if old_ap != new_ap and new_ap:
            detail_parts.append(f"Prochain rendez-vous : {new_ap}")
        body = ". ".join(detail_parts) if detail_parts else "Votre dossier relationnel a été mis à jour."
        for mn in codes:
            try:
                notify_member_number(
                    church_id,
                    mn,
                    "Évolution relation pastorale",
                    body,
                    sender_phone,
                )
            except Exception:
                pass

# ---------------------------
# Member counter per church
# ---------------------------
def next_member_number(church_id: int) -> str:
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT value FROM church_settings WHERE church_id=? AND key='member_counter'",
        (church_id,)
    ).fetchone()
    if not row:
        cur.execute(
            "INSERT INTO church_settings(church_id, key, value) VALUES(?,?,?)",
            (church_id, "member_counter", "1")
        )
        counter = 1
    else:
        counter = int(row["value"] or "1")

    code = f"M{str(counter).zfill(3)}"
    counter += 1
    cur.execute(
        "INSERT INTO church_settings(church_id, key, value) VALUES(?,?,?) "
        "ON CONFLICT(church_id, key) DO UPDATE SET value=excluded.value",
        (church_id, "member_counter", str(counter))
    )
    conn.commit()
    conn.close()
    return code


def seed_terrain_demo_if_needed():
    """
    Idempotent: église terrain + 5 comptes + >=20 membres numérotés + invités (INV-*) + présences + finance.
    """
    demo_church_code = DEMO_CHURCH_CODE
    pw = DEMO_PASSWORD

    demo_names_m = [
        "Grace Mbemba", "Samuel Kanku", "Marie Lukusa", "David Tshisekedi", "Ruth Ilunga",
        "Paul Kabeya", "Esther Mwamba", "Jean-Pierre Ngalula", "Sarah Mutombo", "Andre Kasaï",
        "Naomi Tshilombo", "Michel Banza", "Deborah Mbuyi", "Simon Kimbuta", "Hannah Lusambo",
        "Timothée Nzuzi", "Rebecca Mwadi", "Elie Kabongo", "Joanna Mpoyi", "Benjamin Tshimanga",
    ]

    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT id FROM churches WHERE church_code=?", (demo_church_code,)).fetchone()
    if not row:
        cur.execute(
            "INSERT INTO churches(church_code, name, is_suspended, suspend_reason, created_at) VALUES(?,?,?,?,?)",
            (demo_church_code, "Badiboss Eglise (Terrain Demo)", 0, "", now_ts()),
        )
        church_id = int(cur.lastrowid)
    else:
        church_id = int(row["id"])

    ensure_finance_defaults_for_church(church_id)
    fin_defaults = [
        ("Dîme", "in"),
        ("Offrande", "in"),
        ("Action de grâce", "in"),
        ("Don spécial", "in"),
        ("Dépenses", "out"),
        ("Salaires", "out"),
    ]
    ts = now_ts()
    for nm, dr in fin_defaults:
        try:
            cur.execute(
                "INSERT OR IGNORE INTO finance_categories(church_id, name, direction, created_at) VALUES(?,?,?,?)",
                (church_id, nm, dr, ts),
            )
        except Exception:
            pass

    demo_users = [
        ("SUPER_ADMIN", normalize_phone_rd_congo(SUPER_ADMIN_PHONE), "Super Admin Terrain", pw),
        ("PASTEUR_RESPONSABLE", normalize_phone_rd_congo("+243990010000"), "Pasteur Terrain", pw),
        ("SECRETAIRE", normalize_phone_rd_congo("+243990010001"), "Secretaire Admin", pw),
        ("FINANCE", normalize_phone_rd_congo("+243990010002"), "Tresorier Finance", pw),
        ("MEMBRE", normalize_phone_rd_congo("+243990010003"), "Membre Simple", pw),
    ]

    for role, phone_norm, full_name, pwx in demo_users:
        if role == "SUPER_ADMIN":
            perms_json = json.dumps([])
        else:
            perms = default_permissions_for_role(role)
            perms = apply_role_restrictions(church_id, role, perms)
            perms_json = json.dumps(perms)

        cur.execute(
            """
            INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at)
            VALUES(?,?,?,?,?,?,?,?,?)
            ON CONFLICT(church_id, phone) DO UPDATE SET
              full_name=excluded.full_name,
              password_hash=excluded.password_hash,
              role=excluded.role,
              is_disabled=excluded.is_disabled,
              permissions_json=excluded.permissions_json
            """,
            (church_id, phone_norm, full_name, hash_pw(pwx), role, 0, perms_json, None, now_ts()),
        )

    m_count = int(
        cur.execute(
            "SELECT COUNT(*) AS c FROM members WHERE church_id=? AND is_deleted=0 AND member_number LIKE 'M%'",
            (church_id,),
        ).fetchone()["c"]
    )
    conn.commit()
    conn.close()

    idx_add = 0
    guard = 0
    while m_count < 20 and guard < 50:
        guard += 1
        mn = next_member_number(church_id)
        name = demo_names_m[idx_add % len(demo_names_m)]
        phone_member = normalize_phone_rd_congo(f"+24399002{1000 + idx_add:04d}")
        is_pending = idx_add < 5
        conn2 = db()
        cu = conn2.cursor()
        try:
            cu.execute(
                """
                INSERT INTO members(
                  church_id, member_number, full_name, phone, sex, quarter, category, presence_status,
                  marital_status, partner_member_number, is_validated, created_at,
                  status, is_deleted, commune, zone, address_line, neighborhood, region, province
                )
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    church_id,
                    mn,
                    name,
                    phone_member,
                    "male" if idx_add % 2 == 0 else "female",
                    "Limete",
                    "adulte",
                    "regular",
                    "single",
                    None,
                    0 if is_pending else 1,
                    now_ts(),
                    "pending" if is_pending else "active",
                    0,
                    "Kinshasa",
                    "Quartier Demo",
                    "",
                    "",
                    "Kinshasa",
                    "Kinshasa",
                ),
            )
            conn2.commit()
            m_count += 1
            idx_add += 1
        except sqlite3.IntegrityError:
            conn2.rollback()
            idx_add += 1
        conn2.close()

    conn3 = db()
    cur3 = conn3.cursor()
    pending_n = int(
        cur3.execute(
            "SELECT COUNT(*) AS c FROM members WHERE church_id=? AND is_deleted=0 AND member_number LIKE 'M%' AND is_validated=0",
            (church_id,),
        ).fetchone()["c"]
    )
    if pending_n < 4:
        need = 4 - pending_n
        for r in cur3.execute(
            "SELECT member_number FROM members WHERE church_id=? AND is_deleted=0 AND member_number LIKE 'M%' AND is_validated=1 ORDER BY id ASC LIMIT ?",
            (church_id, int(need)),
        ).fetchall():
            cur3.execute(
                "UPDATE members SET is_validated=0, status='pending' WHERE church_id=? AND member_number=?",
                (church_id, r["member_number"]),
            )

    invites = [
        ("INV-01", "Visiteur Alpha", normalize_phone_rd_congo("+243990030001")),
        ("INV-02", "Visiteur Beta", normalize_phone_rd_congo("+243990030002")),
        ("INV-03", "Visiteur Gamma", normalize_phone_rd_congo("+243990030003")),
    ]
    for inv_no, inv_name, inv_phone in invites:
        ex = cur3.execute(
            "SELECT id FROM members WHERE church_id=? AND member_number=?",
            (church_id, inv_no),
        ).fetchone()
        if ex:
            continue
        try:
            cur3.execute(
                """
                INSERT INTO members(
                  church_id, member_number, full_name, phone, sex, quarter, category, presence_status,
                  marital_status, partner_member_number, is_validated, created_at,
                  status, is_deleted, commune, zone, address_line, neighborhood, region, province
                )
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    church_id,
                    inv_no,
                    inv_name,
                    inv_phone,
                    "male",
                    "—",
                    "invite",
                    "visitor",
                    "single",
                    None,
                    1,
                    now_ts(),
                    "active",
                    0,
                    "Kinshasa",
                    "—",
                    "",
                    "",
                    "Kinshasa",
                    "Kinshasa",
                ),
            )
        except sqlite3.IntegrityError:
            pass

    open_ev = cur3.execute(
        "SELECT id FROM attendance_events WHERE church_id=? AND status='open' ORDER BY id DESC LIMIT 1",
        (church_id,),
    ).fetchone()
    if not open_ev:
        cur3.execute(
            "INSERT INTO attendance_events(church_id, title, event_date, created_at, status, closed_at) VALUES(?,?,?,?,?,?)",
            (church_id, "Culte Dimanche (Terrain Demo)", time.strftime("%Y-%m-%d"), now_ts(), "open", None),
        )
        event_id = int(cur3.lastrowid)
    else:
        event_id = int(open_ev["id"])

    mnums = [
        r["member_number"]
        for r in cur3.execute(
            "SELECT member_number FROM members WHERE church_id=? AND is_deleted=0 AND member_number LIKE 'M%' ORDER BY member_number LIMIT 12",
            (church_id,),
        ).fetchall()
    ]
    for mn in mnums:
        dup = cur3.execute(
            "SELECT id FROM attendance_records WHERE church_id=? AND event_id=? AND member_number=?",
            (church_id, event_id, mn),
        ).fetchone()
        if not dup:
            cur3.execute(
                "INSERT INTO attendance_records(church_id, event_id, member_number, guest_name, present, created_at) VALUES(?,?,?,?,?,?)",
                (church_id, event_id, mn, "", 1, now_ts()),
            )
    for g in ["Patrick Mulumba", "Chantal Kiese", "Oscar Ndombe"]:
        norm = " ".join(g.split()).lower()
        dup = cur3.execute(
            "SELECT id FROM attendance_records WHERE church_id=? AND event_id=? AND lower(trim(guest_name))=?",
            (church_id, event_id, norm),
        ).fetchone()
        if not dup:
            cur3.execute(
                "INSERT INTO attendance_records(church_id, event_id, member_number, guest_name, present, created_at) VALUES(?,?,?,?,?,?)",
                (church_id, event_id, "", g, 1, now_ts()),
            )

    fin_n = int(
        cur3.execute("SELECT COUNT(*) AS c FROM finance_transactions WHERE church_id=?", (church_id,)).fetchone()["c"]
    )
    if fin_n == 0:

        def cid(name: str) -> Optional[int]:
            r = cur3.execute("SELECT id FROM finance_categories WHERE church_id=? AND name=?", (church_id, name)).fetchone()
            return int(r["id"]) if r else None

        txs = [
            (cid("Dîme"), 120.0, "Dime terrain"),
            (cid("Offrande"), 75.0, "Offrande terrain"),
            (cid("Action de grâce"), 40.0, "Action de grace"),
            (cid("Don spécial"), 15.0, "Don special"),
            (cid("Dépenses"), 55.0, "Depenses terrain"),
            (cid("Salaires"), 35.0, "Salaires terrain"),
        ]
        for c_id, amount, note in txs:
            if c_id is None:
                continue
            drow = cur3.execute("SELECT direction FROM finance_categories WHERE id=?", (c_id,)).fetchone()
            if not drow:
                continue
            cur3.execute(
                """
                INSERT INTO finance_transactions(church_id, category_id, direction, member_number, amount, currency, note, created_at)
                VALUES(?,?,?,?,?,?,?,?)
                """,
                (church_id, c_id, drow["direction"], None, float(amount), "CDF", note, now_ts()),
            )

    cur3.execute(
        "INSERT INTO church_settings(church_id, key, value) VALUES(?,?,?) "
        "ON CONFLICT(church_id, key) DO UPDATE SET value=excluded.value",
        (church_id, "terrain_demo_v1", "1"),
    )
    conn3.commit()
    conn3.close()


seed_terrain_demo_if_needed()

# ---------------------------
# Models (API)
# ---------------------------
class ResolveChurchIn(BaseModel):
    church_code: str

class LoginIn(BaseModel):
    church_code: str
    phone: str
    password: str

class LoginCompatIn(BaseModel):
    church_code: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None

class SuperLoginIn(BaseModel):
    phone: str
    password: str

class CreateChurchIn(BaseModel):
    church_code: str
    name: str
    pasteur_phone: str
    pasteur_full_name: str
    pasteur_password: str

class SuspendChurchIn(BaseModel):
    church_code: str
    reason: str = "Eglise temporairement suspendue, régler vos paiements."

class CreateUserIn(BaseModel):
    phone: str
    full_name: str = ""
    password: str
    role: str  # SECRETAIRE, FINANCE, PROTOCOLE, MEMBRE

class DisableUserIn(BaseModel):
    user_id: int
    disabled: bool

class DenyPermissionsIn(BaseModel):
    role: str
    denied_permissions: List[str]

class AssignUserPermsIn(BaseModel):
    user_id: int
    permissions: List[str]

class MemberCreateIn(BaseModel):
    full_name: str
    phone: str
    sex: str
    quarter: str
    category: str
    presence_status: str
    marital_status: str
    commune: Optional[str] = ""
    zone: Optional[str] = ""
    address_line: Optional[str] = ""
    neighborhood: Optional[str] = ""
    region: Optional[str] = ""
    province: Optional[str] = ""
    partner_member_number: Optional[str] = None
    create_account: bool = False
    account_password: Optional[str] = None
    account_role: str = "MEMBRE"  # MEMBRE ou PROTOCOLE

class PublicMemberSelfRegisterIn(BaseModel):
    church_code: str
    full_name: str
    phone: str
    sex: str
    quarter: str
    category: str = "member"
    presence_status: str = "unknown"
    marital_status: str
    birth_date: Optional[str] = None
    commune: Optional[str] = ""
    zone: Optional[str] = ""
    address_line: Optional[str] = ""
    neighborhood: Optional[str] = ""
    region: Optional[str] = ""
    province: Optional[str] = ""
    password: str

class MemberValidateIn(BaseModel):
    member_number: str
    validated: bool = True

class MemberStatusIn(BaseModel):
    member_number: str
    status: str  # pending|active|suspended|banned

class MemberDeleteIn(BaseModel):
    member_number: str

class MemberUpdateIn(BaseModel):
    member_number: str
    full_name: str
    phone: str
    commune: Optional[str] = ""
    quarter: Optional[str] = ""
    zone: Optional[str] = ""
    address_line: Optional[str] = ""
    role_name: Optional[str] = None  # membre|protocole|secretaire|finance|admin

class DonationCreateIn(BaseModel):
    member_number: str
    type: str
    label: str
    amount: float = 0
    currency: str = "CDF"
    nature_desc: str = ""

class FinanceCategoryCreateIn(BaseModel):
    name: str
    direction: str  # in|out|entrée|sortie

class FinanceTransactionCreateIn(BaseModel):
    category_id: int
    member_number: Optional[str] = None
    amount: float = 0
    currency: str = "CDF"
    note: str = ""

class AttendanceEventCreateIn(BaseModel):
    title: str
    event_date: str  # YYYY-MM-DD

class AttendanceEventCloseIn(BaseModel):
    event_id: int
    closed: bool = True

class AttendanceMarkIn(BaseModel):
    event_id: int
    member_number: Optional[str] = None
    guest_name: Optional[str] = None
    present: bool = True

class ProtocolServiceCreateIn(BaseModel):
    title: str
    service_date: str  # YYYY-MM-DD

class ProtocolAssignIn(BaseModel):
    service_id: int
    member_number: str
    task: str

class ProtocolCheckinIn(BaseModel):
    assignment_id: int
    checked_in: bool = True

class PastoralRelationsSyncIn(BaseModel):
    relations: List[Dict[str, Any]]

class ChurchDocumentSyncIn(BaseModel):
    payload: Dict[str, Any]

class FeedCreateIn(BaseModel):
    kind: str  # announcement | message
    body: str
    audience: str = "all"

class NotificationMarkReadIn(BaseModel):
    notification_id: str

class UserPasswordResetIn(BaseModel):
    user_id: int
    new_password: str

class SuperSaaSStateIn(BaseModel):
    plans: Optional[List[Dict[str, Any]]] = None
    saas_global: Optional[Dict[str, Any]] = None
    church_subscriptions: Optional[List[Dict[str, Any]]] = None


class SuperUserPasswordResetIn(BaseModel):
    church_code: str
    phone: str
    new_password: str


class ChurchBillingUpsertIn(BaseModel):
    subscription: Dict[str, Any] = Field(default_factory=dict)

# ---------------------------
# Endpoints
# ---------------------------
@app.get("/health")
def health():
    return {"ok": True, "time": now_ts()}

@app.post("/church/resolve")
def resolve_church(body: ResolveChurchIn):
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT id, church_code, name, is_suspended, suspend_reason FROM churches WHERE church_code=?",
        (body.church_code.strip(),)
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Church not found")
    return {
        "ok": True,
        "church": {
            "id": row["id"],
            "church_code": row["church_code"],
            "name": row["name"],
            "is_suspended": bool(row["is_suspended"]),
            "suspend_reason": row["suspend_reason"],
        }
    }

@app.post("/super/login")
def super_login(body: SuperLoginIn):
    phone_ok = normalize_phone_rd_congo(body.phone.strip()) == normalize_phone_rd_congo(SUPER_ADMIN_PHONE)
    if not phone_ok or body.password.strip() != SUPER_ADMIN_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid super admin credentials")
    token = secrets.token_hex(24)
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO sessions(token, user_id, church_id, role, created_at) VALUES(?,?,?,?,?)",
        (token, 0, None, "SUPER_ADMIN", now_ts())
    )
    conn.commit()
    conn.close()
    audit(None, None, "super_login", {"phone": body.phone})
    return {"ok": True, "role": "SUPER_ADMIN", "token": token}

def db_create_church_with_pasteur(body: CreateChurchIn) -> Dict[str, Any]:
    church_code = body.church_code.strip()
    name = body.name.strip()
    phone_norm = normalize_phone_rd_congo(body.pasteur_phone.strip())
    full_name = body.pasteur_full_name.strip()
    pw = body.pasteur_password.strip()
    if len(pw) < 4:
        raise HTTPException(status_code=400, detail="Mot de passe trop court")

    conn = db()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO churches(church_code, name, is_suspended, suspend_reason, created_at) VALUES(?,?,?,?,?)",
            (church_code, name, 0, "", now_ts()),
        )
        church_id = int(cur.lastrowid)
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=409, detail="Church code already exists")

    role = "PASTEUR_RESPONSABLE"
    perms = default_permissions_for_role(role)
    perms = apply_role_restrictions(church_id, role, perms)

    cur.execute(
        "INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at) "
        "VALUES(?,?,?,?,?,?,?,?,?)",
        (
            church_id,
            phone_norm,
            full_name,
            hash_pw(pw),
            role,
            0,
            json.dumps(perms),
            None,
            now_ts(),
        ),
    )

    conn.commit()
    conn.close()
    return {
        "church_id": church_id,
        "church_code": church_code,
        "church_name": name,
        "pasteur_role": role,
    }


@app.post("/super/church/create")
def super_create_church(body: CreateChurchIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")

    out = db_create_church_with_pasteur(body)
    audit(int(out["church_id"]), 0, "super_church_create", {"church_code": out["church_code"], "name": out["church_name"]})
    return {"ok": True, "church_code": out["church_code"], "church_name": out["church_name"], "pasteur_role": out["pasteur_role"]}


@app.post("/public/church/trial_create")
def public_church_trial_create(body: CreateChurchIn):
    out = db_create_church_with_pasteur(body)
    audit(int(out["church_id"]), None, "public_trial_church_create", {"church_code": out["church_code"], "name": out["church_name"]})
    return {"ok": True, "church_code": out["church_code"], "church_name": out["church_name"], "pasteur_role": out["pasteur_role"]}

@app.post("/super/church/suspend")
def super_suspend_church(body: SuspendChurchIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")

    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT id FROM churches WHERE church_code=?", (body.church_code.strip(),)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Church not found")

    cur.execute(
        "UPDATE churches SET is_suspended=1, suspend_reason=? WHERE church_code=?",
        (body.reason, body.church_code.strip())
    )
    conn.commit()
    conn.close()
    audit(row["id"], 0, "super_church_suspend", {"church_code": body.church_code, "reason": body.reason})
    return {"ok": True, "church_code": body.church_code, "is_suspended": True}

@app.post("/super/church/unsuspend")
def super_unsuspend_church(body: ResolveChurchIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")

    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT id FROM churches WHERE church_code=?", (body.church_code.strip(),)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Church not found")

    cur.execute(
        "UPDATE churches SET is_suspended=0, suspend_reason='' WHERE church_code=?",
        (body.church_code.strip(),)
    )
    conn.commit()
    conn.close()
    audit(row["id"], 0, "super_church_unsuspend", {"church_code": body.church_code})
    return {"ok": True, "church_code": body.church_code, "is_suspended": False}

@app.post("/super/restrictions/deny")
def super_deny_permissions(body: DenyPermissionsIn, church_code: str, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")

    conn = db()
    cur = conn.cursor()
    c = cur.execute("SELECT id FROM churches WHERE church_code=?", (church_code.strip(),)).fetchone()
    if not c:
        conn.close()
        raise HTTPException(status_code=404, detail="Church not found")
    church_id = c["id"]

    role = body.role.upper()
    denied = list(sorted(set(body.denied_permissions)))

    cur.execute(
        "INSERT INTO restrictions(church_id, role, denied_permissions_json) VALUES(?,?,?) "
        "ON CONFLICT(church_id, role) DO UPDATE SET denied_permissions_json=excluded.denied_permissions_json",
        (church_id, role, json.dumps(denied))
    )
    conn.commit()
    conn.close()

    audit(church_id, 0, "super_restrictions_deny", {"role": role, "denied": denied})
    return {"ok": True, "church_code": church_code, "role": role, "denied": denied}

@app.post("/login")
def login(body: LoginIn):
    church_code = body.church_code.strip()

    conn = db()
    cur = conn.cursor()
    c = cur.execute(
        "SELECT id, is_suspended, suspend_reason FROM churches WHERE church_code=?",
        (church_code,)
    ).fetchone()
    if not c:
        conn.close()
        raise HTTPException(status_code=404, detail="Church not found")

    if c["is_suspended"] == 1:
        conn.close()
        raise HTTPException(status_code=403, detail=c["suspend_reason"] or "Eglise suspendue")

    church_id = int(c["id"])
    phone_raw_digits = "".join([ch for ch in (body.phone or "").strip() if ch.isdigit()])
    phone_norm = normalize_phone_rd_congo(phone_raw_digits)
    if phone_raw_digits == phone_norm:
        u = cur.execute(
            "SELECT * FROM users WHERE church_id=? AND phone=?",
            (church_id, phone_norm),
        ).fetchone()
    else:
        u = cur.execute(
            "SELECT * FROM users WHERE church_id=? AND (phone=? OR phone=?)",
            (church_id, phone_raw_digits, phone_norm),
        ).fetchone()
    if not u:
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if u["is_disabled"] == 1:
        conn.close()
        raise HTTPException(status_code=403, detail="Compte désactivé")
    if u["password_hash"] != hash_pw(body.password.strip()):
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid credentials")

    role = u["role"].upper()
    user_perms = json.loads(u["permissions_json"] or "[]")
    user_perms = apply_role_restrictions(church_id, role, user_perms)

    token = secrets.token_hex(24)
    cur.execute(
        "INSERT INTO sessions(token, user_id, church_id, role, created_at) VALUES(?,?,?,?,?)",
        (token, int(u["id"]), church_id, role, now_ts())
    )
    conn.commit()
    conn.close()

    audit(church_id, int(u["id"]), "login", {"phone": body.phone, "role": role})

    return {
        "ok": True,
        "token": token,
        "church_id": church_id,
        "role": role,
        "user": {"id": int(u["id"]), "full_name": u["full_name"], "phone": u["phone"], "member_number": u["member_number"]},
        "permissions": user_perms
    }

# ---------------------------
# Aliases compat (Flutter/OpenAPI legacy)
# ---------------------------

@app.post("/api/eglise/login")
async def api_eglise_login(request: Request):
    """
    Alias vers /login.
    Accepte JSON body ou query params: church_code|churchCode, phone, password
    """
    payload: Dict[str, Any] = {}
    try:
        body = await request.json()
        if isinstance(body, dict):
            payload = body
    except Exception:
        payload = {}

    q = request.query_params
    church_code = (
        (payload.get("church_code") or payload.get("churchCode") or q.get("church_code") or q.get("churchCode") or "")
    )
    phone = (payload.get("phone") or q.get("phone") or "")
    password = (payload.get("password") or q.get("password") or "")

    data = LoginIn(church_code=str(church_code), phone=str(phone), password=str(password))
    return login(data)

@app.get("/api/eglise/me")
def api_eglise_me(authorization: Optional[str] = Header(default=None)):
    # Alias vers /me/profile (header Authorization identique)
    return me_profile(Authorization=authorization)

# ---------------------------
# Pasteur: manage users
# ---------------------------
@app.post("/church/users/create")
def church_create_user(body: CreateUserIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "users.create")

    church_id = int(ctx["church_id"])
    role_new = body.role.upper()

    perms = default_permissions_for_role(role_new)
    perms = apply_role_restrictions(church_id, role_new, perms)

    conn = db()
    cur = conn.cursor()
    phone_norm = normalize_phone_rd_congo(body.phone.strip())
    display_name = (body.full_name or "").strip() or phone_norm
    try:
        cur.execute(
            "INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at) "
            "VALUES(?,?,?,?,?,?,?,?,?)",
            (
                church_id,
                phone_norm,
                display_name,
                hash_pw(body.password.strip()),
                role_new,
                0,
                json.dumps(perms),
                None,
                now_ts(),
            ),
        )
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=409, detail="Téléphone déjà utilisé dans cette église")

    user_id = cur.lastrowid
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "user_create", {"user_id": user_id, "role": role_new, "phone": body.phone})
    return {"ok": True, "user_id": user_id, "role": role_new, "permissions": perms}

@app.post("/church/users/disable")
def church_disable_user(body: DisableUserIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "users.disable")

    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET is_disabled=? WHERE id=? AND church_id=?",
        (1 if body.disabled else 0, body.user_id, church_id)
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "user_disable", {"user_id": body.user_id, "disabled": body.disabled})
    return {"ok": True, "user_id": body.user_id, "disabled": body.disabled}

@app.post("/church/users/permissions/assign")
def church_assign_user_permissions(body: AssignUserPermsIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "permissions.assign")

    church_id = int(ctx["church_id"])
    perms = list(sorted(set(body.permissions)))

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET permissions_json=? WHERE id=? AND church_id=?",
        (json.dumps(perms), body.user_id, church_id)
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "permissions_assign", {"user_id": body.user_id, "permissions": perms})
    return {"ok": True, "user_id": body.user_id, "permissions": perms}

# ---------------------------
# MEMBERS + DONATIONS + ATTENDANCE + PROTOCOL
# ---------------------------
@app.post("/church/members/create")
def create_member(body: MemberCreateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.create")

    church_id = int(ctx["church_id"])
    member_number = next_member_number(church_id)
    phone_norm = normalize_phone_rd_congo(body.phone.strip())

    conn = db()
    cur = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO members(
               church_id, member_number, full_name, phone, sex, quarter, category, presence_status,
               marital_status, partner_member_number, is_validated, created_at,
               status, is_deleted, commune, zone, address_line, neighborhood, region, province
               )
               VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                church_id, member_number,
                body.full_name.strip(),
                phone_norm,
                body.sex.strip(),
                body.quarter.strip(),
                body.category.strip(),
                body.presence_status.strip(),
                body.marital_status.strip(),
                body.partner_member_number.strip() if body.partner_member_number else None,
                0,
                now_ts(),
                "pending",
                0,
                (body.commune or "").strip(),
                (body.zone or "").strip(),
                (body.address_line or "").strip(),
                (body.neighborhood or "").strip(),
                (body.region or "").strip(),
                (body.province or "").strip(),
            )
        )
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=409, detail="Téléphone déjà utilisé dans cette église")

    # Option: create account linked to member
    user_id = None
    if body.create_account:
        role_new = body.account_role.upper()
        pw = (body.account_password or "").strip()
        if not pw:
            conn.close()
            raise HTTPException(status_code=400, detail="account_password requis si create_account=true")

        perms = default_permissions_for_role(role_new)
        perms = apply_role_restrictions(church_id, role_new, perms)

        try:
            cur.execute(
                "INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at) "
                "VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    church_id,
                    phone_norm,
                    body.full_name.strip(),
                    hash_pw(pw),
                    role_new,
                    0,
                    json.dumps(perms),
                    member_number,
                    now_ts()
                )
            )
            user_id = cur.lastrowid
        except sqlite3.IntegrityError:
            # member created but user exists => keep member, return warning
            user_id = None

    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "member_create", {"member_number": member_number, "user_id": user_id})
    return {"ok": True, "member_number": member_number, "user_id": user_id}

@app.post("/public/members/self_register")
def public_member_self_register(body: PublicMemberSelfRegisterIn):
    ensure_members_columns()
    church_code = (body.church_code or "").strip()
    if church_code == "":
        raise HTTPException(status_code=400, detail="church_code requis")
    church_id = resolve_church_id_by_code(church_code)
    ensure_church_active(church_id)
    phone_norm = normalize_phone_rd_congo((body.phone or "").strip())
    if len(phone_norm) != 12 or not phone_norm.startswith("243"):
        raise HTTPException(status_code=400, detail="Numéro RDC invalide")
    pw = (body.password or "").strip()
    if len(pw) < 6:
        raise HTTPException(status_code=400, detail="Mot de passe trop court (min 6)")
    full_name = (body.full_name or "").strip()
    if full_name == "":
        raise HTTPException(status_code=400, detail="Nom complet requis")

    member_number = next_member_number(church_id)
    conn = db()
    cur = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO members(
               church_id, member_number, full_name, phone, sex, quarter, category, presence_status,
               marital_status, partner_member_number, is_validated, created_at, birth_date,
               status, is_deleted, commune, zone, address_line, neighborhood, region, province
               )
               VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                church_id, member_number,
                full_name,
                phone_norm,
                (body.sex or "").strip(),
                (body.quarter or "").strip(),
                (body.category or "member").strip(),
                (body.presence_status or "unknown").strip(),
                (body.marital_status or "").strip(),
                None,
                0,
                now_ts(),
                (body.birth_date or "").strip(),
                "pending",
                0,
                (body.commune or "").strip(),
                (body.zone or "").strip(),
                (body.address_line or "").strip(),
                (body.neighborhood or "").strip(),
                (body.region or "").strip(),
                (body.province or "").strip(),
            )
        )
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=409, detail="Téléphone déjà utilisé dans cette église")

    user_id = None
    try:
        perms = default_permissions_for_role("MEMBRE")
        perms = apply_role_restrictions(church_id, "MEMBRE", perms)
        cur.execute(
            "INSERT INTO users(church_id, phone, full_name, password_hash, role, is_disabled, permissions_json, member_number, created_at) "
            "VALUES(?,?,?,?,?,?,?,?,?)",
            (
                church_id,
                phone_norm,
                full_name,
                hash_pw(pw),
                "MEMBRE",
                0,
                json.dumps(perms),
                member_number,
                now_ts(),
            ),
        )
        user_id = int(cur.lastrowid)
    except sqlite3.IntegrityError:
        pass
    conn.commit()
    conn.close()
    try:
        audit(church_id, None, "public_member_self_register", {"member_number": member_number, "user_id": user_id})
    except Exception:
        pass
    return {"ok": True, "member_number": member_number, "status": "pending", "user_id": user_id}

@app.get("/church/members/list")
def list_members(pending_only: bool = False, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    if pending_only:
        rows = cur.execute(
            "SELECT * FROM members WHERE church_id=? AND is_deleted=0 AND is_validated=0 ORDER BY id DESC",
            (church_id,)
        ).fetchall()
    else:
        rows = cur.execute(
            "SELECT * FROM members WHERE church_id=? AND is_deleted=0 ORDER BY id DESC",
            (church_id,)
        ).fetchall()
    # Build regularity / trend insight from latest attendance events (pastoral pilotage).
    event_rows = cur.execute(
        "SELECT id FROM attendance_events WHERE church_id=? ORDER BY event_date DESC, id DESC LIMIT 8",
        (church_id,),
    ).fetchall()
    event_ids = [int(e["id"]) for e in event_rows]
    att_by_member: Dict[str, Dict[str, int]] = {}
    if event_ids:
        placeholders = ",".join(["?"] * len(event_ids))
        att_rows = cur.execute(
            f"""
            SELECT member_number, SUM(present) AS present_count, COUNT(*) AS marked_count
            FROM attendance_records
            WHERE church_id=? AND member_number<>'' AND event_id IN ({placeholders})
            GROUP BY member_number
            """,
            (church_id, *event_ids),
        ).fetchall()
        for a in att_rows:
            att_by_member[(a["member_number"] or "").strip()] = {
                "present": int(a["present_count"] or 0),
                "marked": int(a["marked_count"] or 0),
            }

    def infer_regularity_tag(member_row: sqlite3.Row, present: int, marked: int) -> str:
        # With no recent data, fallback on historical field.
        if marked <= 0:
            ps = (member_row["presence_status"] or "").strip().lower()
            if ps in {"regular", "regulier", "régulier"}:
                return "regular"
            if ps in {"visitor", "visiteur"}:
                return "irregular"
            return "monitoring"
        ratio = present / max(marked, 1)
        if ratio >= 0.75:
            return "regular"
        if ratio >= 0.45:
            return "monitoring"
        return "irregular"

    out_members: List[Dict[str, Any]] = []
    for r in rows:
        d = dict(r)
        mn = (d.get("member_number") or "").strip()
        stats = att_by_member.get(mn, {"present": 0, "marked": 0})
        present = int(stats["present"])
        marked = int(stats["marked"])
        score = round((present / max(marked, 1)) * 100.0, 1) if marked > 0 else None
        tag = infer_regularity_tag(r, present, marked)
        trend = "stable"
        ps = (d.get("presence_status") or "").strip().lower()
        if ps in {"improving", "en_amelioration", "en amélioration"}:
            trend = "improving"
        elif ps in {"retrograding", "regression", "régression"}:
            trend = "retrograding"
        d["regularity_tag"] = tag
        d["regularity_score"] = score
        d["regularity_trend"] = trend
        d["regularity_present_count"] = present
        d["regularity_marked_count"] = marked
        urow = cur.execute(
            "SELECT role FROM users WHERE church_id=? AND member_number=? LIMIT 1",
            (church_id, mn),
        ).fetchone()
        d["account_role"] = (urow["role"] or "").strip() if urow else None
        out_members.append(d)

    conn.close()
    return {"ok": True, "members": out_members}

@app.post("/church/members/validate")
def validate_member(body: MemberValidateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.validate")
    church_id = int(ctx["church_id"])
    mn = body.member_number.strip()
    sp = actor_user_phone(ctx)

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE members SET is_validated=?, status=? WHERE church_id=? AND member_number=? AND is_deleted=0",
        (1 if body.validated else 0, ("active" if body.validated else "pending"), church_id, mn),
    )
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "member_validate", {"member_number": body.member_number, "validated": body.validated})
    if body.validated:
        try:
            notify_member_number(
                church_id,
                mn,
                "Compte validé",
                "Votre inscription membre a été validée. Vous pouvez utiliser l’application avec votre compte.",
                sp,
            )
        except Exception:
            pass
    return {"ok": True, "member_number": body.member_number, "validated": body.validated}

@app.post("/church/members/status")
def set_member_status(body: MemberStatusIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.update")
    church_id = int(ctx["church_id"])
    mn = body.member_number.strip()

    status = body.status.strip().lower()
    if status not in {"pending", "active", "suspended", "banned"}:
        raise HTTPException(status_code=400, detail="Invalid status")

    conn = db()
    cur = conn.cursor()
    prev = cur.execute(
        "SELECT status FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
        (church_id, mn),
    ).fetchone()
    old_st = (prev["status"] or "").strip().lower() if prev else ""
    cur.execute(
        "UPDATE members SET status=? WHERE church_id=? AND member_number=? AND is_deleted=0",
        (status, church_id, mn),
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "member_status", {"member_number": body.member_number, "status": status})
    if old_st != status:
        try:
            notify_member_number(
                church_id,
                mn,
                "Statut membre",
                f"Votre statut sur l’application a été mis à jour : {status}.",
                actor_user_phone(ctx),
            )
        except Exception:
            pass
    return {"ok": True, "member_number": body.member_number, "status": status}

@app.post("/church/members/delete")
def delete_member(body: MemberDeleteIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.archive")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE members SET is_deleted=1 WHERE church_id=? AND member_number=?",
        (church_id, body.member_number.strip()),
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "member_delete", {"member_number": body.member_number})
    return {"ok": True, "member_number": body.member_number}

@app.post("/church/members/update")
def update_member_fields(body: MemberUpdateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.update")
    church_id = int(ctx["church_id"])
    mn = body.member_number.strip()
    if not mn:
        raise HTTPException(status_code=400, detail="member_number requis")

    phone_norm = normalize_phone_rd_congo((body.phone or "").strip())
    if len(phone_norm) != 12 or not phone_norm.startswith("243"):
        raise HTTPException(status_code=400, detail="Numéro RDC invalide")
    full_name = (body.full_name or "").strip()
    if not full_name:
        raise HTTPException(status_code=400, detail="Nom complet requis")

    conn = db()
    cur = conn.cursor()
    ex = cur.execute(
        "SELECT id FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
        (church_id, mn),
    ).fetchone()
    if not ex:
        conn.close()
        raise HTTPException(status_code=404, detail="Membre introuvable")

    dup = cur.execute(
        "SELECT member_number FROM members WHERE church_id=? AND phone=? AND member_number<>? AND is_deleted=0",
        (church_id, phone_norm, mn),
    ).fetchone()
    if dup:
        conn.close()
        raise HTTPException(status_code=409, detail="Téléphone déjà utilisé par un autre membre")

    cur.execute(
        """
        UPDATE members SET full_name=?, phone=?, commune=?, quarter=?, zone=?, address_line=?
        WHERE church_id=? AND member_number=? AND is_deleted=0
        """,
        (
            full_name,
            phone_norm,
            (body.commune or "").strip(),
            (body.quarter or "").strip(),
            (body.zone or "").strip(),
            (body.address_line or "").strip(),
            church_id,
            mn,
        ),
    )

    u = cur.execute(
        "SELECT id, role FROM users WHERE church_id=? AND member_number=?",
        (church_id, mn),
    ).fetchone()
    old_backend_role = (u["role"] or "").strip().upper() if u else None
    if u:
        uid = int(u["id"])
        try:
            cur.execute(
                "UPDATE users SET full_name=?, phone=? WHERE id=? AND church_id=?",
                (full_name, phone_norm, uid, church_id),
            )
        except sqlite3.IntegrityError:
            conn.close()
            raise HTTPException(status_code=409, detail="Téléphone déjà utilisé par un autre compte")

    role_backend = ui_member_role_to_backend(body.role_name)
    if role_backend and u:
        uid = int(u["id"])
        perms = default_permissions_for_role(role_backend)
        perms = apply_role_restrictions(church_id, role_backend, perms)
        try:
            cur.execute(
                "UPDATE users SET role=?, phone=?, full_name=?, permissions_json=? WHERE id=? AND church_id=?",
                (role_backend, phone_norm, full_name, json.dumps(perms), uid, church_id),
            )
        except sqlite3.IntegrityError:
            conn.close()
            raise HTTPException(status_code=409, detail="Conflit compte utilisateur")

    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "member_update", {"member_number": mn})
    if role_backend and u and old_backend_role and role_backend != old_backend_role:
        try:
            notify_member_number(
                church_id,
                mn,
                "Rôle / fonction",
                f"Votre rôle sur la plateforme est maintenant : {role_backend}. Rouvrez l’onglet Profil pour actualiser le menu.",
                actor_user_phone(ctx),
            )
        except Exception:
            pass
    return {"ok": True, "member_number": mn}

@app.get("/church/relations/list")
def list_pastoral_relations(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "relations.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT payload_json FROM pastoral_relations WHERE church_id=? ORDER BY updated_at DESC",
        (church_id,),
    ).fetchall()
    conn.close()

    out: List[Dict[str, Any]] = []
    for r in rows:
        try:
            out.append(json.loads(r["payload_json"]))
        except Exception:
            pass
    return {"ok": True, "relations": out}

@app.post("/church/relations/sync")
def sync_pastoral_relations(body: PastoralRelationsSyncIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "relations.write")
    church_id = int(ctx["church_id"])
    ts = now_ts()

    def _parse_appointment(v: str) -> Optional[float]:
        s = (v or "").strip()
        if s == "":
            return None
        s = s.replace(" ", "T")
        try:
            dt = time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S")
            return time.mktime(dt)
        except Exception:
            pass
        try:
            dt = time.strptime(s[:16], "%Y-%m-%dT%H:%M")
            return time.mktime(dt)
        except Exception:
            pass
        try:
            dt = time.strptime(s[:10], "%Y-%m-%d")
            return time.mktime(dt)
        except Exception:
            return None

    conn = db()
    cur = conn.cursor()
    members = cur.execute(
        "SELECT member_number, full_name, marital_status FROM members WHERE church_id=? AND is_deleted=0",
        (church_id,),
    ).fetchall()
    marital_by_member: Dict[str, str] = {}
    for m in members:
        marital_by_member[(m["member_number"] or "").strip()] = (m["marital_status"] or "").strip().lower()

    seen_open: Dict[str, str] = {}
    now_ts_float = time.time()
    for rel in body.relations:
        rel_id = str(rel.get("id") or "").strip()
        if rel_id == "":
            continue
        a = str(rel.get("personA") or "").strip()
        b = str(rel.get("personB") or "").strip()
        if a == "" or b == "":
            conn.close()
            raise HTTPException(status_code=400, detail="Relation invalide: personnes obligatoires")
        appointment = str(rel.get("nextAppointment") or "").strip()
        if appointment != "":
            ap_ts = _parse_appointment(appointment)
            if ap_ts is None:
                conn.close()
                raise HTTPException(status_code=400, detail=f"Date rendez-vous invalide ({a} + {b})")
            if ap_ts < (now_ts_float - 60):
                conn.close()
                raise HTTPException(status_code=400, detail=f"Rendez-vous passé interdit ({a} + {b})")
        is_open = bool(rel.get("isOpen") is True)
        if not is_open:
            continue
        for key in ("memberCodeA", "memberCodeB"):
            mc = str(rel.get(key) or "").strip()
            if mc == "":
                continue
            ms = marital_by_member.get(mc, "")
            if ms in {"married", "marié", "marie"}:
                conn.close()
                raise HTTPException(status_code=409, detail=f"Membre {mc} non éligible: déjà marié")
            if mc in seen_open:
                conn.close()
                raise HTTPException(status_code=409, detail=f"Membre {mc} déjà engagé en relation active")
            seen_open[mc] = rel_id

    incoming_ids: List[str] = []
    payloads: Dict[str, dict] = {}
    for rel in body.relations:
        rel_id = str(rel.get("id") or "").strip()
        if not rel_id:
            continue
        incoming_ids.append(rel_id)
        payloads[rel_id] = rel if isinstance(rel, dict) else {}

    if not incoming_ids:
        conn.close()
        audit(church_id, ctx["user_id"], "relations_sync", {"count": 0, "noop": True})
        return {"ok": True, "count": 0}

    prev_rows = cur.execute(
        "SELECT relation_id, payload_json FROM pastoral_relations WHERE church_id=?",
        (church_id,),
    ).fetchall()
    prev_map: Dict[str, dict] = {}
    for r in prev_rows:
        try:
            prev_map[str(r["relation_id"])] = json.loads(r["payload_json"])
        except Exception:
            prev_map[str(r["relation_id"])] = {}

    sp = actor_user_phone(ctx)
    n = 0
    for rel_id, rel in payloads.items():
        cur.execute(
            """
            INSERT INTO pastoral_relations(church_id, relation_id, payload_json, updated_at)
            VALUES(?,?,?,?)
            ON CONFLICT(church_id, relation_id) DO UPDATE SET
              payload_json=excluded.payload_json,
              updated_at=excluded.updated_at
            """,
            (church_id, rel_id, json.dumps(rel, ensure_ascii=False), ts),
        )
        n += 1

    placeholders = ",".join("?" * len(incoming_ids))
    cur.execute(
        f"DELETE FROM pastoral_relations WHERE church_id=? AND relation_id NOT IN ({placeholders})",
        (church_id, *incoming_ids),
    )

    try:
        _notify_relations_diff(church_id, prev_map, payloads, sp)
    except Exception:
        pass

    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "relations_sync", {"count": n})
    return {"ok": True, "count": n}

@app.get("/public/churches/list")
def public_churches_list():
    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT church_code, name, is_suspended FROM churches ORDER BY name"
    ).fetchall()
    conn.close()
    return {
        "ok": True,
        "churches": [
            {"church_code": r["church_code"], "name": r["name"], "is_suspended": int(r["is_suspended"] or 0)}
            for r in rows
        ],
    }

@app.get("/super/churches/list")
def super_churches_list(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")
    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT id, church_code, name, is_suspended, suspend_reason, created_at FROM churches ORDER BY name"
    ).fetchall()
    conn.close()
    return {"ok": True, "churches": [dict(r) for r in rows]}

@app.get("/super/saas/state")
def super_saas_state_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")
    plans = platform_kv_get("saas_plans")
    gl = platform_kv_get("saas_global")
    subs = platform_kv_get("saas_church_subscriptions")
    return {
        "ok": True,
        "plans": plans.get("items", []) if plans else [],
        "saas_global": gl or {},
        "church_subscriptions": subs.get("items", []) if subs else [],
    }

@app.post("/super/saas/state")
def super_saas_state_set(body: SuperSaaSStateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")
    if body.plans is not None:
        platform_kv_set("saas_plans", {"items": body.plans})
    if body.saas_global is not None:
        platform_kv_set("saas_global", body.saas_global)
    if body.church_subscriptions is not None:
        platform_kv_set("saas_church_subscriptions", {"items": body.church_subscriptions})
    audit(None, None, "super_saas_state", {})
    return {"ok": True}

@app.get("/church/users/list")
def church_users_list(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "users.read")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT id, phone, full_name, role, is_disabled, permissions_json, member_number, created_at FROM users WHERE church_id=? ORDER BY id",
        (church_id,),
    ).fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        d["permissions"] = json.loads(d.pop("permissions_json") or "[]")
        out.append(d)
    return {"ok": True, "users": out}

@app.post("/church/users/password_reset")
def church_user_password_reset(body: UserPasswordResetIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "users.create")
    church_id = int(ctx["church_id"])
    pw = body.new_password.strip()
    if len(pw) < 4:
        raise HTTPException(status_code=400, detail="Mot de passe trop court")
    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET password_hash=? WHERE id=? AND church_id=?",
        (hash_pw(pw), body.user_id, church_id),
    )
    if cur.rowcount < 1:
        conn.close()
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "user_password_reset", {"user_id": body.user_id})
    return {"ok": True, "user_id": body.user_id}


@app.post("/super/users/password_reset")
def super_user_password_reset(body: SuperUserPasswordResetIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] != "SUPER_ADMIN":
        raise HTTPException(status_code=403, detail="Forbidden")
    pw = body.new_password.strip()
    if len(pw) < 4:
        raise HTTPException(status_code=400, detail="Mot de passe trop court")
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT id FROM churches WHERE church_code=?", (body.church_code.strip(),)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Église introuvable")
    church_id = int(row["id"])
    phone_norm = normalize_phone_rd_congo(body.phone.strip())
    cur.execute(
        "UPDATE users SET password_hash=? WHERE church_id=? AND phone=?",
        (hash_pw(pw), church_id, phone_norm),
    )
    if cur.rowcount < 1:
        conn.close()
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    conn.commit()
    conn.close()
    audit(church_id, None, "super_user_password_reset", {"phone": phone_norm})
    return {"ok": True, "church_code": body.church_code.strip(), "phone": phone_norm}


@app.get("/church/billing/subscription")
def church_billing_subscription_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    plans_blob = platform_kv_get("saas_plans") or {}
    plan_items = plans_blob.get("items", []) if isinstance(plans_blob, dict) else []
    if ctx["role"] == "SUPER_ADMIN":
        return {"ok": True, "subscription": None, "plans": plan_items}
    require_perm(ctx, "church.read")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT church_code, name FROM churches WHERE id=?", (church_id,)).fetchone()
    conn.close()
    if not row:
        return {"ok": True, "subscription": None, "plans": plan_items}
    cc = str(row["church_code"] or "").strip().upper()
    subs = platform_kv_get("saas_church_subscriptions") or {}
    items = subs.get("items", []) if isinstance(subs, dict) else []
    match = None
    for it in items:
        if str(it.get("churchCode", "")).strip().upper() == cc:
            match = it
            break
    return {"ok": True, "subscription": match, "plans": plan_items}


@app.post("/church/billing/subscription")
def church_billing_subscription_set(body: ChurchBillingUpsertIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    if ctx["role"] == "SUPER_ADMIN":
        raise HTTPException(status_code=400, detail="Utiliser /super/saas/state pour le super admin")
    require_perm(ctx, "members.update")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    row = cur.execute("SELECT church_code, name FROM churches WHERE id=?", (church_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Église introuvable")
    cc = str(row["church_code"] or "").strip()
    church_name = str(row["name"] or "").strip()
    sub = dict(body.subscription or {})
    sub["churchCode"] = cc
    if not str(sub.get("churchName") or "").strip():
        sub["churchName"] = church_name
    subs = platform_kv_get("saas_church_subscriptions") or {"items": []}
    items = list(subs.get("items", [])) if isinstance(subs, dict) else []
    replaced = False
    cc_up = cc.upper()
    for i, it in enumerate(items):
        if str(it.get("churchCode", "")).strip().upper() == cc_up:
            merged = dict(it) if isinstance(it, dict) else {}
            merged.update(sub)
            items[i] = merged
            replaced = True
            break
    if not replaced:
        items.append(sub)
    platform_kv_set("saas_church_subscriptions", {"items": items})
    audit(church_id, ctx["user_id"], "church_billing_subscription_set", {"church_code": cc})
    return {"ok": True}


@app.get("/church/documents/member_groups")
def church_doc_member_groups_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "programs.read")
    church_id = int(ctx["church_id"])
    data = church_document_get(church_id, "member_groups")
    return {"ok": True, "payload": data}

def _notify_member_group_additions(church_id: int, old_payload: Dict[str, Any], new_payload: Dict[str, Any], actor_phone: str) -> None:
    def _group_maps(payload: Dict[str, Any]) -> Dict[str, Tuple[set, str]]:
        out: Dict[str, Tuple[set, str]] = {}
        groups = payload.get("groups")
        if not isinstance(groups, list):
            return out
        for g in groups:
            if not isinstance(g, dict):
                continue
            gid = (g.get("id") or "").strip()
            if not gid:
                continue
            gname = (g.get("name") or gid).strip()
            mids = g.get("memberIds")
            idset = set()
            if isinstance(mids, list):
                for x in mids:
                    s = (str(x) if x is not None else "").strip()
                    if s:
                        idset.add(s)
            out[gid] = (idset, gname)
        return out

    old_m = _group_maps(old_payload)
    new_m = _group_maps(new_payload)
    all_ids = set(old_m.keys()) | set(new_m.keys())
    if not all_ids:
        return

    conn = db()
    cur = conn.cursor()
    ts = now_ts()
    for gid in all_ids:
        old_set, _on = old_m.get(gid, (set(), gid))
        new_set, gname = new_m.get(gid, (set(), gid))
        for mn in new_set - old_set:
            row = cur.execute(
                "SELECT phone, full_name FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
                (church_id, mn),
            ).fetchone()
            if not row:
                continue
            p = normalize_phone_rd_congo((row["phone"] or "").strip())
            if len(p) < 12:
                continue
            nm = (row["full_name"] or "").strip()
            nid = secrets.token_hex(10)
            title = f"Groupe: {gname}"
            body_txt = f"Vous avez été ajouté au groupe « {gname} »."
            cur.execute(
                "INSERT INTO church_notifications(id, church_id, target, title, body, sender_phone, created_at, read_phones_json) VALUES(?,?,?,?,?,?,?,?)",
                (nid, church_id, f"phone:{p}", title, body_txt[:2000], (actor_phone or "").strip(), ts, "[]"),
            )
    conn.commit()
    conn.close()

@app.post("/church/documents/member_groups")
def church_doc_member_groups_set(body: ChurchDocumentSyncIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "programs.write")
    church_id = int(ctx["church_id"])
    prev = church_document_get(church_id, "member_groups")
    church_document_set(church_id, "member_groups", body.payload)
    actor_phone = ""
    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT phone FROM users WHERE id=?", (ctx["user_id"],)).fetchone()
    conn.close()
    if u:
        actor_phone = (u["phone"] or "").strip()
    try:
        _notify_member_group_additions(church_id, prev, body.payload, actor_phone)
    except Exception:
        pass
    audit(church_id, ctx["user_id"], "doc_member_groups", {})
    return {"ok": True}

@app.get("/church/documents/irregulars")
def church_doc_irregulars_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.read")
    church_id = int(ctx["church_id"])
    return {"ok": True, "payload": church_document_get(church_id, "irregulars")}

@app.post("/church/documents/irregulars")
def church_doc_irregulars_set(body: ChurchDocumentSyncIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.update")
    church_id = int(ctx["church_id"])
    prev = church_document_get(church_id, "irregulars")
    church_document_set(church_id, "irregulars", body.payload)
    try:
        _notify_irregulars_diff(church_id, prev, body.payload, actor_user_phone(ctx))
    except Exception:
        pass
    audit(church_id, ctx["user_id"], "doc_irregulars", {})
    return {"ok": True}

@app.get("/church/documents/secretariat")
def church_doc_secretariat_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.read")
    church_id = int(ctx["church_id"])
    return {"ok": True, "payload": church_document_get(church_id, "secretariat")}

@app.post("/church/documents/secretariat")
def church_doc_secretariat_set(body: ChurchDocumentSyncIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "members.update")
    church_id = int(ctx["church_id"])
    church_document_set(church_id, "secretariat", body.payload)
    audit(church_id, ctx["user_id"], "doc_secretariat", {})
    return {"ok": True}

@app.get("/church/role_policy")
def church_role_policy_get(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "church.read")
    church_id = int(ctx["church_id"])
    return {"ok": True, "policy": church_document_get(church_id, "role_policy")}

@app.post("/church/role_policy")
def church_role_policy_set(body: ChurchDocumentSyncIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "permissions.assign")
    church_id = int(ctx["church_id"])
    church_document_set(church_id, "role_policy", body.payload)
    audit(church_id, ctx["user_id"], "role_policy_set", {})
    return {"ok": True}

@app.get("/church/feed/list")
def church_feed_list(kind: Optional[str] = None, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "announcements.read")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    if kind and kind.strip().lower() in ("announcement", "message"):
        rows = cur.execute(
            "SELECT * FROM church_feed_items WHERE church_id=? AND kind=? ORDER BY created_at DESC",
            (church_id, kind.strip().lower()),
        ).fetchall()
    else:
        rows = cur.execute(
            "SELECT * FROM church_feed_items WHERE church_id=? ORDER BY created_at DESC",
            (church_id,),
        ).fetchall()
    conn.close()
    return {"ok": True, "items": [dict(r) for r in rows]}

@app.post("/church/feed/create")
def church_feed_create(body: FeedCreateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    church_id = int(ctx["church_id"])
    k = body.kind.strip().lower()
    if k not in ("announcement", "message"):
        raise HTTPException(status_code=400, detail="kind invalide")

    can_broadcast = ctx["role"] == "SUPER_ADMIN" or user_has_permission(church_id, ctx["user_id"], "announcements.write")
    # Rôle MEMBRE: réponse autorisée même si permissions_json figé (terrain sans re-login)
    can_reply_msg = (
        ctx["role"] == "SUPER_ADMIN"
        or user_has_permission(church_id, ctx["user_id"], "messages.reply")
        or ctx["role"] == "MEMBRE"
    )

    if k == "announcement":
        if not can_broadcast:
            require_perm(ctx, "announcements.write")
    else:
        if not (can_broadcast or can_reply_msg):
            raise HTTPException(status_code=403, detail="Permission manquante pour ce message")

    audience_raw = (body.audience or "all").strip()
    audience_final = audience_raw
    if audience_raw in {"all", "admins", "members"}:
        audience_final = audience_raw
    elif audience_raw.startswith("phone:"):
        p = normalize_phone_rd_congo(audience_raw.split(":", 1)[1].strip())
        if p == "":
            raise HTTPException(status_code=400, detail="Audience téléphone invalide")
        audience_final = f"phone:{p}"
    elif audience_raw.startswith("member:"):
        member_number = audience_raw.split(":", 1)[1].strip()
        conn_tmp = db()
        cur_tmp = conn_tmp.cursor()
        row = cur_tmp.execute(
            "SELECT phone FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
            (church_id, member_number),
        ).fetchone()
        conn_tmp.close()
        if not row:
            raise HTTPException(status_code=404, detail="Membre destinataire introuvable")
        audience_final = f"phone:{normalize_phone_rd_congo((row['phone'] or '').strip())}"
    else:
        raise HTTPException(status_code=400, detail="Audience invalide")

    if k == "message" and can_reply_msg and not can_broadcast:
        if not audience_final.startswith("phone:"):
            raise HTTPException(status_code=400, detail="Réponse: destinataire (téléphone) obligatoire")
        tp = audience_final.split(":", 1)[1].strip()
        if not phone_is_church_non_member_staff(church_id, tp):
            raise HTTPException(status_code=403, detail="Réponse réservée vers un responsable (staff)")

    fid = secrets.token_hex(12)
    ts = now_ts()
    phone_ctx = ""
    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT phone FROM users WHERE id=?", (ctx["user_id"],)).fetchone()
    if u:
        phone_ctx = (u["phone"] or "").strip()
    cur.execute(
        "INSERT INTO church_feed_items(id, church_id, kind, body, audience, sender_phone, created_at) VALUES(?,?,?,?,?,?,?)",
        (fid, church_id, k, body.body.strip(), audience_final, phone_ctx, ts),
    )
    nid = secrets.token_hex(10)
    title = "Nouvelle annonce" if k == "announcement" else "Nouveau message"
    cur.execute(
        "INSERT INTO church_notifications(id, church_id, target, title, body, sender_phone, created_at, read_phones_json) VALUES(?,?,?,?,?,?,?,?)",
        (nid, church_id, audience_final, title, body.body.strip()[:2000], phone_ctx, ts, "[]"),
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "feed_create", {"kind": k, "id": fid})
    return {"ok": True, "id": fid, "notification_id": nid}

@app.get("/church/notifications/list")
def church_notifications_list(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.notifications.read")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT * FROM church_notifications WHERE church_id=? ORDER BY created_at DESC LIMIT 500",
        (church_id,),
    ).fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        try:
            d["readByPhones"] = json.loads(d.pop("read_phones_json") or "[]")
        except Exception:
            d["readByPhones"] = []
        out.append(d)
    return {"ok": True, "notifications": out}

@app.post("/church/notifications/mark_read")
def church_notifications_mark_read(body: NotificationMarkReadIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.notifications.read")
    church_id = int(ctx["church_id"])
    conn = db()
    cur = conn.cursor()
    row = cur.execute(
        "SELECT read_phones_json FROM church_notifications WHERE id=? AND church_id=?",
        (body.notification_id.strip(), church_id),
    ).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Notification introuvable")
    u = cur.execute("SELECT phone FROM users WHERE id=?", (ctx["user_id"],)).fetchone()
    phone = (u["phone"] or "").strip() if u else ""
    try:
        cur_list = json.loads(row["read_phones_json"] or "[]")
        if not isinstance(cur_list, list):
            cur_list = []
    except Exception:
        cur_list = []
    if phone and phone not in cur_list:
        cur_list.append(phone)
    cur.execute(
        "UPDATE church_notifications SET read_phones_json=? WHERE id=? AND church_id=?",
        (json.dumps(cur_list), body.notification_id.strip(), church_id),
    )
    conn.commit()
    conn.close()
    return {"ok": True}

@app.post("/church/donations/create")
def create_donation(body: DonationCreateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.write")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    # ensure member exists
    m = cur.execute("SELECT id FROM members WHERE church_id=? AND member_number=?", (church_id, body.member_number.strip())).fetchone()
    if not m:
        conn.close()
        raise HTTPException(status_code=404, detail="Membre introuvable")

    cur.execute(
        """INSERT INTO donations(church_id, member_number, type, label, amount, currency, nature_desc, created_at)
           VALUES(?,?,?,?,?,?,?,?)""",
        (
            church_id,
            body.member_number.strip(),
            body.type.strip().upper(),
            body.label.strip(),
            float(body.amount),
            body.currency.strip().upper(),
            body.nature_desc.strip(),
            now_ts()
        )
    )
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "donation_create", {"member_number": body.member_number, "type": body.type, "label": body.label})
    return {"ok": True}

@app.get("/church/donations/list")
def list_donations(member_number: Optional[str] = None, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    if member_number:
        rows = cur.execute(
            "SELECT * FROM donations WHERE church_id=? AND member_number=? ORDER BY id DESC",
            (church_id, member_number.strip())
        ).fetchall()
    else:
        rows = cur.execute(
            "SELECT * FROM donations WHERE church_id=? ORDER BY id DESC",
            (church_id,)
        ).fetchall()
    conn.close()

    return {"ok": True, "donations": [dict(r) for r in rows]}

# ---------------------------
# Finance module (entrées / sorties)
# ---------------------------

def _normalize_finance_direction(direction: str) -> str:
    d = (direction or "").strip().lower()
    if d in {"in", "entree", "entrée", "entrées"}:
        return "in"
    if d in {"out", "sortie", "sorties"}:
        return "out"
    raise HTTPException(status_code=400, detail="direction invalide (in/out)")

def _resolve_finance_church_id(ctx: Dict[str, Any], church_code: Optional[str]) -> int:
    if ctx["church_id"] is not None:
        return int(ctx["church_id"])
    if not church_code:
        raise HTTPException(status_code=400, detail="church_code requis pour SUPER_ADMIN")
    return resolve_church_id_by_code(church_code)

@app.get("/church/finance/categories/list")
def finance_categories_list(
    direction: Optional[str] = None,
    church_code: Optional[str] = None,
    Authorization: Optional[str] = Header(default=None),
):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.read")
    church_id = _resolve_finance_church_id(ctx, church_code)
    ensure_finance_defaults_for_church(church_id)

    conn = db()
    cur = conn.cursor()

    if direction:
        d = _normalize_finance_direction(direction)
        rows = cur.execute(
            "SELECT id, name, direction FROM finance_categories WHERE church_id=? AND direction=? ORDER BY name ASC",
            (church_id, d),
        ).fetchall()
    else:
        rows = cur.execute(
            "SELECT id, name, direction FROM finance_categories WHERE church_id=? ORDER BY direction ASC, name ASC",
            (church_id,),
        ).fetchall()
    conn.close()
    return {"ok": True, "categories": [dict(r) for r in rows]}

@app.post("/church/finance/categories/create")
def finance_category_create(
    body: FinanceCategoryCreateIn,
    church_code: Optional[str] = None,
    Authorization: Optional[str] = Header(default=None),
):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.write")
    church_id = _resolve_finance_church_id(ctx, church_code)

    ensure_finance_defaults_for_church(church_id)
    name = body.name.strip()
    direction = _normalize_finance_direction(body.direction)

    conn = db()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO finance_categories(church_id, name, direction, created_at) VALUES(?,?,?,?)",
            (church_id, name, direction, now_ts()),
        )
        cid = cur.lastrowid
    except sqlite3.IntegrityError:
        # Déjà existant => on renvoie la catégorie existante
        row = cur.execute(
            "SELECT id FROM finance_categories WHERE church_id=? AND name=?",
            (church_id, name),
        ).fetchone()
        cid = int(row["id"]) if row else -1
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "finance_category_create", {"name": name, "direction": direction, "category_id": cid})
    return {"ok": True, "category_id": cid, "name": name, "direction": direction}

@app.post("/church/finance/transactions/create")
def finance_transaction_create(
    body: FinanceTransactionCreateIn,
    church_code: Optional[str] = None,
    Authorization: Optional[str] = Header(default=None),
):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.write")
    church_id = _resolve_finance_church_id(ctx, church_code)

    ensure_finance_defaults_for_church(church_id)

    conn = db()
    cur = conn.cursor()

    cat = cur.execute(
        "SELECT id, direction FROM finance_categories WHERE church_id=? AND id=?",
        (church_id, int(body.category_id)),
    ).fetchone()
    if not cat:
        conn.close()
        raise HTTPException(status_code=404, detail="Catégorie introuvable")

    member_number = (body.member_number or "").strip()
    if member_number == "":
        member_number = None

    if member_number is not None:
        m = cur.execute(
            "SELECT id FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
            (church_id, member_number),
        ).fetchone()
        if not m:
            conn.close()
            raise HTTPException(status_code=404, detail="Membre introuvable")

    amount = float(body.amount)
    if amount <= 0:
        conn.close()
        raise HTTPException(status_code=400, detail="Montant invalide")

    cur.execute(
        """INSERT INTO finance_transactions(
           church_id, category_id, direction, member_number,
           amount, currency, note, created_at
        ) VALUES(?,?,?,?,?,?,?,?)""",
        (
            church_id,
            int(body.category_id),
            cat["direction"],
            member_number,
            amount,
            (body.currency or "CDF").strip().upper(),
            (body.note or "").strip(),
            now_ts(),
        ),
    )
    tid = cur.lastrowid
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "finance_transaction_create", {"transaction_id": tid, "category_id": body.category_id, "amount": amount})
    return {"ok": True, "transaction_id": tid}

@app.get("/church/finance/transactions/list")
def finance_transactions_list(
    direction: Optional[str] = None,
    category_id: Optional[int] = None,
    member_number: Optional[str] = None,
    limit: int = 200,
    offset: int = 0,
    church_code: Optional[str] = None,
    Authorization: Optional[str] = Header(default=None),
):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.read")
    church_id = _resolve_finance_church_id(ctx, church_code)
    ensure_finance_defaults_for_church(church_id)

    conn = db()
    cur = conn.cursor()

    where = ["t.church_id=?"]
    params: List[Any] = [church_id]

    if direction:
        where.append("t.direction=?")
        params.append(_normalize_finance_direction(direction))
    if category_id is not None:
        where.append("t.category_id=?")
        params.append(int(category_id))
    if member_number:
        where.append("t.member_number=?")
        params.append(member_number.strip())

    where_sql = " AND ".join(where)
    rows = cur.execute(
        f"""
        SELECT
          t.id, t.category_id, c.name AS category_name, t.direction,
          t.member_number, t.amount, t.currency, t.note, t.created_at
        FROM finance_transactions t
        JOIN finance_categories c ON c.id=t.category_id
        WHERE {where_sql}
        ORDER BY t.id DESC
        LIMIT ? OFFSET ?
        """,
        (*params, int(limit), int(offset)),
    ).fetchall()
    conn.close()
    return {"ok": True, "transactions": [dict(r) for r in rows]}

@app.get("/church/finance/summary")
def finance_summary(
    church_code: Optional[str] = None,
    Authorization: Optional[str] = Header(default=None),
):
    ctx = actor_context(Authorization)
    require_perm(ctx, "finance.read")
    church_id = _resolve_finance_church_id(ctx, church_code)
    ensure_finance_defaults_for_church(church_id)

    conn = db()
    cur = conn.cursor()

    in_total = cur.execute(
        "SELECT COALESCE(SUM(amount),0) AS s FROM finance_transactions WHERE church_id=? AND direction='in'",
        (church_id,),
    ).fetchone()["s"]
    out_total = cur.execute(
        "SELECT COALESCE(SUM(amount),0) AS s FROM finance_transactions WHERE church_id=? AND direction='out'",
        (church_id,),
    ).fetchone()["s"]
    net_total = float(in_total) - float(out_total)

    by_cat = cur.execute(
        """
        SELECT c.id, c.name, c.direction, COALESCE(SUM(t.amount),0) AS total
        FROM finance_transactions t
        JOIN finance_categories c ON c.id=t.category_id
        WHERE t.church_id=?
        GROUP BY c.id, c.name, c.direction
        ORDER BY c.direction ASC, c.name ASC
        """,
        (church_id,),
    ).fetchall()

    conn.close()
    return {
        "ok": True,
        "in_total": float(in_total),
        "out_total": float(out_total),
        "net_total": net_total,
        "by_category": [dict(r) for r in by_cat],
    }

@app.post("/church/attendance/event/create")
def create_attendance_event(body: AttendanceEventCreateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "attendance.write")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO attendance_events(church_id, title, event_date, created_at, status, closed_at) VALUES(?,?,?,?,?,?)",
        (church_id, body.title.strip(), body.event_date.strip(), now_ts(), "open", None)
    )
    event_id = cur.lastrowid
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "attendance_event_create", {"event_id": event_id, "title": body.title})
    return {"ok": True, "event_id": event_id}

@app.get("/church/attendance/events/list")
def list_attendance_events(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "attendance.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT * FROM attendance_events WHERE church_id=? ORDER BY id DESC",
        (church_id,),
    ).fetchall()
    conn.close()
    return {"ok": True, "events": [dict(r) for r in rows]}

@app.post("/church/attendance/event/close")
def close_attendance_event(body: AttendanceEventCloseIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "attendance.write")
    church_id = int(ctx["church_id"])

    status = "closed" if body.closed else "open"
    closed_at = now_ts() if body.closed else None

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE attendance_events SET status=?, closed_at=? WHERE church_id=? AND id=?",
        (status, closed_at, church_id, int(body.event_id)),
    )
    conn.commit()
    conn.close()
    audit(church_id, ctx["user_id"], "attendance_event_close", {"event_id": body.event_id, "status": status})
    return {"ok": True, "event_id": body.event_id, "status": status}

@app.post("/church/attendance/mark")
def mark_attendance(body: AttendanceMarkIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "attendance.write")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()

    ev = cur.execute("SELECT id FROM attendance_events WHERE church_id=? AND id=?", (church_id, body.event_id)).fetchone()
    if not ev:
        conn.close()
        raise HTTPException(status_code=404, detail="Event introuvable")

    member_number = (body.member_number or "").strip()
    guest_name = (body.guest_name or "").strip()

    if not member_number and not guest_name:
        conn.close()
        raise HTTPException(status_code=400, detail="member_number ou guest_name requis")

    # Anti-doublon strict
    if member_number:
        # Membre connu obligatoire
        m = cur.execute(
            "SELECT id FROM members WHERE church_id=? AND member_number=? AND is_deleted=0",
            (church_id, member_number),
        ).fetchone()
        if not m:
            conn.close()
            raise HTTPException(status_code=404, detail="Membre introuvable")

        dup = cur.execute(
            "SELECT id FROM attendance_records WHERE church_id=? AND event_id=? AND member_number=?",
            (church_id, body.event_id, member_number),
        ).fetchone()
        if dup:
            conn.close()
            raise HTTPException(status_code=409, detail="Présence déjà enregistrée pour ce membre")

        cur.execute(
            "INSERT INTO attendance_records(church_id, event_id, member_number, present, created_at) VALUES(?,?,?,?,?)",
            (church_id, body.event_id, member_number, 1 if body.present else 0, now_ts()),
        )
    else:
        # Invité : pas de membre_number, mais guest_name requis
        if not guest_name:
            conn.close()
            raise HTTPException(status_code=400, detail="guest_name requis pour un invité")

        # Normalisation forte pour anti-doublon invité (Jean / JEAN / jean  => même personne)
        normalized = " ".join(guest_name.split()).lower()
        dup = cur.execute(
            "SELECT id FROM attendance_records WHERE church_id=? AND event_id=? AND lower(trim(guest_name))=?",
            (church_id, body.event_id, normalized),
        ).fetchone()
        if dup:
            conn.close()
            raise HTTPException(status_code=409, detail="Présence déjà enregistrée pour cet invité")

        cur.execute(
            "INSERT INTO attendance_records(church_id, event_id, member_number, guest_name, present, created_at) VALUES(?,?,?,?,?,?)",
            (church_id, body.event_id, "", guest_name, 1 if body.present else 0, now_ts()),
        )
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "attendance_mark", {"event_id": body.event_id, "member_number": body.member_number, "present": body.present})
    return {"ok": True}

@app.get("/church/attendance/list")
def list_attendance(event_id: int, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "attendance.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT * FROM attendance_records WHERE church_id=? AND event_id=? ORDER BY id DESC",
        (church_id, event_id)
    ).fetchall()
    conn.close()

    out = []
    for r in rows:
        d = dict(r)
        # Normalise guest_name pour compatibilité frontend
        if "guest_name" not in d:
            d["guest_name"] = ""
        out.append(d)

    return {"ok": True, "records": out}

@app.post("/church/protocol/service/create")
def create_protocol_service(body: ProtocolServiceCreateIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "protocol.write")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO protocol_services(church_id, title, service_date, created_at) VALUES(?,?,?,?)",
        (church_id, body.title.strip(), body.service_date.strip(), now_ts())
    )
    sid = cur.lastrowid
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "protocol_service_create", {"service_id": sid, "title": body.title})
    return {"ok": True, "service_id": sid}

@app.post("/church/protocol/assign")
def protocol_assign(body: ProtocolAssignIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "protocol.assign")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    svc = cur.execute("SELECT id FROM protocol_services WHERE church_id=? AND id=?", (church_id, body.service_id)).fetchone()
    if not svc:
        conn.close()
        raise HTTPException(status_code=404, detail="Service introuvable")

    m = cur.execute("SELECT id FROM members WHERE church_id=? AND member_number=?", (church_id, body.member_number.strip())).fetchone()
    if not m:
        conn.close()
        raise HTTPException(status_code=404, detail="Membre introuvable")

    cur.execute(
        "INSERT INTO protocol_assignments(church_id, service_id, member_number, task, checked_in, created_at) VALUES(?,?,?,?,?,?)",
        (church_id, body.service_id, body.member_number.strip(), body.task.strip(), 0, now_ts())
    )
    aid = cur.lastrowid
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "protocol_assign", {"assignment_id": aid, "member_number": body.member_number, "task": body.task})
    return {"ok": True, "assignment_id": aid}

@app.post("/church/protocol/checkin")
def protocol_checkin(body: ProtocolCheckinIn, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "protocol.checkin")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE protocol_assignments SET checked_in=? WHERE church_id=? AND id=?",
        (1 if body.checked_in else 0, church_id, body.assignment_id)
    )
    conn.commit()
    conn.close()

    audit(church_id, ctx["user_id"], "protocol_checkin", {"assignment_id": body.assignment_id, "checked_in": body.checked_in})
    return {"ok": True}

@app.get("/church/protocol/assignments")
def protocol_list_assignments(service_id: int, Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "protocol.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT * FROM protocol_assignments WHERE church_id=? AND service_id=? ORDER BY id DESC",
        (church_id, service_id)
    ).fetchall()
    conn.close()

    return {"ok": True, "assignments": [dict(r) for r in rows]}

# ---------------------------
# ME (Espace membre)
# ---------------------------
@app.get("/me/profile")
def me_profile(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT id, phone, full_name, role, member_number FROM users WHERE id=? AND church_id=?", (ctx["user_id"], church_id)).fetchone()
    if not u:
        conn.close()
        raise HTTPException(status_code=404, detail="User introuvable")
    member_number = u["member_number"]
    m = None
    if member_number:
        mrow = cur.execute("SELECT * FROM members WHERE church_id=? AND member_number=?", (church_id, member_number)).fetchone()
        m = dict(mrow) if mrow else None
    conn.close()
    return {"ok": True, "user": dict(u), "member": m}

@app.get("/me/donations")
def me_donations(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.finance.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT member_number FROM users WHERE id=? AND church_id=?", (ctx["user_id"], church_id)).fetchone()
    if not u or not u["member_number"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Compte non lié à un membre")
    member_number = u["member_number"]

    rows = cur.execute(
        "SELECT * FROM donations WHERE church_id=? AND member_number=? ORDER BY id DESC",
        (church_id, member_number)
    ).fetchall()
    conn.close()
    return {"ok": True, "member_number": member_number, "donations": [dict(r) for r in rows]}

@app.get("/me/attendance")
def me_attendance(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.attendance.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT member_number FROM users WHERE id=? AND church_id=?", (ctx["user_id"], church_id)).fetchone()
    if not u or not u["member_number"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Compte non lié à un membre")
    member_number = u["member_number"]

    rows = cur.execute(
        """
        SELECT ar.id AS id, ar.church_id AS church_id, ar.event_id AS event_id, ar.member_number AS member_number,
               ar.present AS present, ar.created_at AS created_at,
               COALESCE(ar.guest_name, '') AS guest_name,
               COALESCE(ae.title, '') AS event_title,
               COALESCE(ae.event_date, '') AS event_date,
               COALESCE(ae.status, '') AS event_status
        FROM attendance_records ar
        LEFT JOIN attendance_events ae ON ae.id = ar.event_id AND ae.church_id = ar.church_id
        WHERE ar.church_id=? AND ar.member_number=?
        ORDER BY ar.id DESC
        """,
        (church_id, member_number),
    ).fetchall()
    conn.close()
    return {"ok": True, "member_number": member_number, "records": [dict(r) for r in rows]}

@app.get("/me/protocol")
def me_protocol(Authorization: Optional[str] = Header(default=None)):
    ctx = actor_context(Authorization)
    require_perm(ctx, "me.assignments.read")
    church_id = int(ctx["church_id"])

    conn = db()
    cur = conn.cursor()
    u = cur.execute("SELECT member_number FROM users WHERE id=? AND church_id=?", (ctx["user_id"], church_id)).fetchone()
    if not u or not u["member_number"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Compte non lié à un membre")
    member_number = u["member_number"]

    rows = cur.execute(
        "SELECT * FROM protocol_assignments WHERE church_id=? AND member_number=? ORDER BY id DESC",
        (church_id, member_number)
    ).fetchall()
    conn.close()
    return {"ok": True, "member_number": member_number, "assignments": [dict(r) for r in rows]}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("server_multichurch:app", host="0.0.0.0", port=port)
