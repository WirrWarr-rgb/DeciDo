import pytest
import pytest_asyncio
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool
from sqlalchemy import text
from sqlalchemy import select
from httpx import AsyncClient, ASGITransport
import asyncio

from app.main import app
from app.core.database import Base, get_db
from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User
from app.models.list import ItemList, ListItem
TEST_DATABASE_URL = r"postgresql+asyncpg://postgres:n8cePEPE=_pw&a%terb~\uM27$UB7@localhost:5432/decido_test_db"

# Создаем тестовый движок
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
    poolclass=NullPool
)

TestSessionLocal = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False
)

@pytest_asyncio.fixture(scope="session")
async def test_db_setup():
    """Создаем тестовую базу данных перед запуском тестов."""
    # Создаем все таблицы
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield
    
    # Очищаем после тестов
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest_asyncio.fixture(scope="function")
async def db_session():
    """Фикстура для сессии базы данных с очисткой после каждого теста."""
    # Создаем таблицы перед тестом
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    async with TestSessionLocal() as session:
        # Очищаем все таблицы перед тестом - используем text()
        await session.execute(text("TRUNCATE TABLE users CASCADE"))
        await session.execute(text("TRUNCATE TABLE lists CASCADE"))
        await session.execute(text("TRUNCATE TABLE list_items CASCADE"))
        await session.commit()
        
        yield session
    
    # Очищаем после теста
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Фикстура для HTTP клиента."""
    # Используем ASGITransport для FastAPI приложения
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest.fixture
def test_user_data():
    """Тестовые данные пользователя."""
    return {
        "username": "testuser",
        "email": "test@example.com",
        "password": "testpassword123"
    }

@pytest_asyncio.fixture
async def test_user(db_session, test_user_data):
    """Создает тестового пользователя в БД."""
    user = User(
        username=test_user_data["username"],
        email=test_user_data["email"],
        hashed_password=get_password_hash(test_user_data["password"]),
        is_active=True
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user

@pytest_asyncio.fixture
async def auth_token(client, test_user_data, db_session):
    """Получает JWT токен для тестового пользователя."""
    # Убедимся, что пользователь существует
    result = await db_session.execute(
        select(User).where(User.username == test_user_data["username"])
    )
    user = result.scalar_one_or_none()
    
    if not user:
        # Создаем пользователя если его нет
        user = User(
            username=test_user_data["username"],
            email=test_user_data["email"],
            hashed_password=get_password_hash(test_user_data["password"]),
            is_active=True
        )
        db_session.add(user)
        await db_session.commit()
    
    response = await client.post(
        "/api/v1/auth/login",
        data={
            "username": test_user_data["username"],
            "password": test_user_data["password"]
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    # Добавим отладочную информацию
    if response.status_code != 200:
        print(f"Login failed: {response.status_code} - {response.text}")
    
    data = response.json()
    return data.get("access_token")

@pytest_asyncio.fixture
async def auth_headers(auth_token):
    """Заголовки авторизации для запросов."""
    return {"Authorization": f"Bearer {auth_token}"}