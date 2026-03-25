from database import Base, engine, SessionLocal
import models

def init_db():
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        s = db.query(models.Setting).first()
        if not s:
            db.add(models.Setting(member_counter=0))
            db.commit()

        admin = db.query(models.User).filter(models.User.phone=="0990000000").first()
        if not admin:
            db.add(models.User(full_name="Super Admin", phone="0990000000", password="1234", role="SUPER_ADMIN"))
            db.commit()
    finally:
        db.close()

if __name__ == "__main__":
    init_db()
    print("DB initialized OK")
