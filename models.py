from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    phone = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)
    role = Column(String, nullable=False, default="ADMIN")
    created_at = Column(DateTime, server_default=func.now())

class Setting(Base):
    __tablename__ = "settings"
    id = Column(Integer, primary_key=True)
    member_counter = Column(Integer, nullable=False, default=0)

class Member(Base):
    __tablename__ = "members"
    id = Column(Integer, primary_key=True, index=True)
    member_code = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    phone = Column(String, index=True, nullable=True)
    quartier = Column(String, nullable=True)
    sexe = Column(String, nullable=True)
    categorie = Column(String, nullable=True)
    presence_status = Column(String, nullable=True)
    marital_status = Column(String, nullable=True)
    is_validated = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, server_default=func.now())
    donations = relationship("Donation", back_populates="member")

class Donation(Base):
    __tablename__ = "donations"
    id = Column(Integer, primary_key=True, index=True)
    member_id = Column(Integer, ForeignKey("members.id"), nullable=False)
    type = Column(String, nullable=False)
    currency = Column(String, nullable=True)
    amount = Column(Float, nullable=True)
    circumstance = Column(String, nullable=True)
    note = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    member = relationship("Member", back_populates="donations")
