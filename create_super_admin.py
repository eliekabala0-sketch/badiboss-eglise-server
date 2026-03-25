# create_super_admin.py
from sqlalchemy.orm import Session

# IMPORTANT:
# - si tes fichiers s'appellent autrement, dis-moi les noms exacts et j'adapte.
from db import SessionLocal
from models import User

def main():
    db: Session = SessionLocal()
    try:
        phone = "0990000000"         # <-- choisis TON numéro admin (ex: 0812345678)
        password = "1234"            # <-- mets un mot de passe fort ensuite
        full_name = "Super Admin"
        role = "SUPER_ADMIN"

        # Cherche si existe déjà
        u = db.query(User).filter(User.phone == phone).first()
        if u:
            u.full_name = full_name
            u.password = password
            u.role = role
            print("Super Admin existant: mis à jour ✅")
        else:
            u = User(full_name=full_name, phone=phone, password=password, role=role)
            db.add(u)
            print("Super Admin créé ✅")

        db.commit()
        print("LOGIN SERVEUR -> phone:", phone, " password:", password)

    finally:
        db.close()

if __name__ == "__main__":
    main()
