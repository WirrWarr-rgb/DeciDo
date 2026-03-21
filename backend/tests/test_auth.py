import pytest
from app.models.user import User
from sqlalchemy import select, delete

class TestAuthEndpoints:
    """Тесты для эндпоинтов авторизации."""
    
    @pytest.mark.asyncio
    async def test_register_success(self, client, db_session):
        """Тест успешной регистрации."""
        user_data = {
            "username": "newuser",
            "email": "newuser@example.com",
            "password": "securepass123"
        }
        
        # Сначала удаляем пользователя, если он существует
        await db_session.execute(
            delete(User).where(User.username == user_data["username"])
        )
        await db_session.commit()
        
        response = await client.post("/api/v1/auth/register", json=user_data)
        
        assert response.status_code == 201
        data = response.json()
        assert data["username"] == user_data["username"]
        assert data["email"] == user_data["email"]
        assert "id" in data
        assert data["is_active"] is True
    
    @pytest.mark.asyncio
    async def test_register_duplicate_email(self, client, test_user):
        """Тест регистрации с уже существующим email."""
        user_data = {
            "username": "anotheruser",
            "email": "test@example.com",  # email уже существует
            "password": "password123"
        }
        
        response = await client.post("/api/v1/auth/register", json=user_data)
        
        assert response.status_code == 400
        assert "User with this email already exists" in response.text
    
    @pytest.mark.asyncio
    async def test_register_duplicate_username(self, client, test_user):
        """Тест регистрации с уже существующим username."""
        user_data = {
            "username": "testuser",  # username уже существует
            "email": "unique@example.com",
            "password": "password123"
        }
        
        response = await client.post("/api/v1/auth/register", json=user_data)
        
        assert response.status_code == 400
        assert "Username already taken" in response.text
    
    @pytest.mark.asyncio
    async def test_register_invalid_data(self, client):
        """Тест регистрации с невалидными данными."""
        # Слишком короткий username
        response = await client.post("/api/v1/auth/register", json={
            "username": "ab",  # меньше 3 символов
            "email": "test@example.com",
            "password": "password123"
        })
        assert response.status_code == 422
        
        # Невалидный email
        response = await client.post("/api/v1/auth/register", json={
            "username": "validuser",
            "email": "invalid-email",
            "password": "password123"
        })
        assert response.status_code == 422
        
        # Слишком короткий пароль
        response = await client.post("/api/v1/auth/register", json={
            "username": "validuser",
            "email": "test@example.com",
            "password": "123"  # меньше 6 символов
        })
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_login_success(self, client, test_user_data):
        """Тест успешного входа."""
        response = await client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["username"],
                "password": test_user_data["password"]
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert len(data["access_token"]) > 0
    
    @pytest.mark.asyncio
    async def test_login_wrong_password(self, client, test_user_data):
        """Тест входа с неправильным паролем."""
        response = await client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user_data["username"],
                "password": "wrongpassword"
            },
             headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        assert response.status_code == 401
        assert "Incorrect username or password" in response.text
    
    @pytest.mark.asyncio
    async def test_login_wrong_username(self, client):
        """Тест входа с несуществующим пользователем."""
        response = await client.post(
            "/api/v1/auth/login",
            data={
                "username": "nonexistentuser",
                "password": "anypassword"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        assert response.status_code == 401
        assert "Incorrect username or password" in response.text
    
    @pytest.mark.asyncio
    async def test_get_current_user(self, client, test_user_data, auth_token):
        """Тест получения текущего пользователя."""
        response = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == test_user_data["username"]
        assert data["email"] == test_user_data["email"]
    
    @pytest.mark.asyncio
    async def test_access_without_token(self, client):
        """Тест доступа без токена."""
        response = await client.get("/api/v1/users/me")
        assert response.status_code == 403
    
    @pytest.mark.asyncio
    async def test_access_with_invalid_token(self, client):
        """Тест доступа с невалидным токеном."""
        response = await client.get(
            "/api/v1/users/me",
            headers={"Authorization": "Bearer invalid_token"}
        )
        assert response.status_code == 401