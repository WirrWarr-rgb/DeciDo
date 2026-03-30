# Модели SQLAlchemy

import bcrypt
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    plain_password_bytes = plain_password.encode('utf-8')[:72]
    return bcrypt.checkpw(plain_password_bytes, hashed_password.encode('utf-8'))

#def verify_password(plain_password: str, hashed_password: str) -> bool:
#    """Проверка пароля."""
#    return pwd_context.verify(plain_password, hashed_password)
#

# Полностью отключаем использование passlib и используем прямой bcrypt
def get_password_hash(password: str) -> str:
    """Хэширование пароля с помощью bcrypt"""
    # Ограничение bcrypt - 72 байта
    password_bytes = password.encode('utf-8')[:72]
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password_bytes, salt).decode('utf-8')

#def get_password_hash(password: str) -> str:
#    #"""Хеширование пароля."""
#    #return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Создание JWT токена."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt