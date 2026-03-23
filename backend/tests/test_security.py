import pytest
from app.core.security import get_password_hash, verify_password, create_access_token
from jose import jwt
from app.core.config import settings

class TestSecurity:
    """Тесты для функций безопасности (хеширование, JWT)."""
    
    def test_password_hashing(self):
        """Тест хеширования пароля."""
        password = "mysecretpassword123"
        
        # Хешируем пароль
        hashed = get_password_hash(password)
        
        # Проверяем, что хеш не равен исходному паролю
        assert hashed != password
        
        # Проверяем, что хеш имеет правильный формат (bcrypt начинается с $2b$)
        assert hashed.startswith("$2b$")
        
        # Проверяем, что разные пароли дают разные хеши
        another_hashed = get_password_hash("different_password")
        assert hashed != another_hashed
    
    def test_password_verification(self):
        """Тест проверки пароля."""
        password = "mysecretpassword123"
        hashed = get_password_hash(password)
        
        # Правильный пароль
        assert verify_password(password, hashed) is True
        
        # Неправильный пароль
        assert verify_password("wrongpassword", hashed) is False
        
        # Пустой пароль
        assert verify_password("", hashed) is False
    
    def test_password_hash_is_deterministic(self):
        """Тест, что хеширование одного пароля дает разные хеши (из-за соли)."""
        password = "samepassword"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        
        # Даже для одного пароля хеши должны быть разными из-за соли
        assert hash1 != hash2
        
        # Но проверка должна проходить для обоих
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True
    
    def test_jwt_token_creation(self):
        """Тест создания JWT токена."""
        data = {"sub": "testuser"}
        
        token = create_access_token(data)
        
        # Проверяем, что токен создан
        assert token is not None
        assert isinstance(token, str)
        assert len(token) > 0
        
        # Декодируем и проверяем содержимое
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        assert decoded["sub"] == "testuser"
        assert "exp" in decoded  # Проверяем наличие expiration time
    
    def test_jwt_token_expiration(self):
        """Тест срока действия JWT токена."""
        from datetime import timedelta
        
        # Создаем токен с коротким сроком действия
        token = create_access_token(
            data={"sub": "testuser"},
            expires_delta=timedelta(seconds=1)
        )
        
        # Проверяем, что токен валиден сразу после создания
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        assert decoded["sub"] == "testuser"
    
    def test_jwt_token_with_custom_data(self):
        """Тест JWT токена с дополнительными данными."""
        custom_data = {
            "sub": "testuser",
            "user_id": 123,
            "role": "admin"
        }
        
        token = create_access_token(data=custom_data)
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        assert decoded["sub"] == "testuser"
        assert decoded["user_id"] == 123
        assert decoded["role"] == "admin"