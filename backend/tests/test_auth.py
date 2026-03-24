@pytest.mark.asyncio
async def test_login_success(self, client, test_user_data):
    """Тест успешного входа по email."""
    response = await client.post(
        "/api/v1/auth/login",
        data={
            "email": test_user_data["email"],
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
            "email": test_user_data["email"],
            "password": "wrongpassword"
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    assert response.status_code == 401
    assert "Incorrect email or password" in response.text

@pytest.mark.asyncio
async def test_login_wrong_email(self, client):
    """Тест входа с несуществующим email."""
    response = await client.post(
        "/api/v1/auth/login",
        data={
            "email": "nonexistent@example.com",  # <-- Несуществующий email
            "password": "anypassword"
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    assert response.status_code == 401
    assert "Incorrect email or password" in response.text