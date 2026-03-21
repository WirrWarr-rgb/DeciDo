import pytest
from sqlalchemy import select
from app.models.list import ItemList, ListItem

class TestListsEndpoints:
    """Тесты для эндпоинтов списков."""
    
    @pytest.mark.asyncio
    async def test_create_list_success(self, client, auth_headers):
        """Тест успешного создания списка."""
        response = await client.post(
            "/api/v1/lists/",
            json={"name": "My Test List"},
            headers=auth_headers
        )
        
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "My Test List"
        assert "id" in data
        assert "user_id" in data
    
    @pytest.mark.asyncio
    async def test_create_list_without_auth(self, client):
        """Тест создания списка без авторизации."""
        response = await client.post(
            "/api/v1/lists/",
            json={"name": "My Test List"}
        )
        assert response.status_code == 403
    
    @pytest.mark.asyncio
    async def test_get_my_lists(self, client, auth_headers, test_user, db_session):
        """Тест получения списков пользователя."""
        # Создаем тестовые списки
        for i in range(3):
            list_item = ItemList(
                name=f"List {i}",
                user_id=test_user.id
            )
            db_session.add(list_item)
        await db_session.commit()
        
        response = await client.get("/api/v1/lists/", headers=auth_headers)
        
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 3
        assert all("name" in item for item in data)
    
    @pytest.mark.asyncio
    async def test_update_list(self, client, auth_headers, test_user, db_session):
        """Тест обновления списка."""
        # Создаем список
        list_item = ItemList(
            name="Original Name",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        # Обновляем
        response = await client.put(
            f"/api/v1/lists/{list_item.id}",
            json={"name": "Updated Name"},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        
        # Проверяем в БД
        result = await db_session.execute(
            select(ItemList).where(ItemList.id == list_item.id)
        )
        updated = result.scalar_one()
        assert updated.name == "Updated Name"
    
    @pytest.mark.asyncio
    async def test_delete_list(self, client, auth_headers, test_user, db_session):
        """Тест удаления списка."""
        # Создаем список
        list_item = ItemList(
            name="To Delete",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        # Удаляем
        response = await client.delete(
            f"/api/v1/lists/{list_item.id}",
            headers=auth_headers
        )
        
        assert response.status_code == 204
        
        # Проверяем, что список удален
        result = await db_session.execute(
            select(ItemList).where(ItemList.id == list_item.id)
        )
        assert result.scalar_one_or_none() is None
    
    @pytest.mark.asyncio
    async def test_add_list_item(self, client, auth_headers, test_user, db_session):
        """Тест добавления пункта в список."""
        # Создаем список
        list_item = ItemList(
            name="Test List",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        # Добавляем пункт
        response = await client.post(
            f"/api/v1/lists/{list_item.id}/items",
            json={
                "name": "Test Item",
                "description": "Test Description",
                "order_index": 0
            },
            headers=auth_headers
        )
        
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test Item"
        assert data["description"] == "Test Description"
        assert data["list_id"] == list_item.id
    
    @pytest.mark.asyncio
    async def test_get_list_items(self, client, auth_headers, test_user, db_session):
        """Тест получения пунктов списка."""
        # Создаем список и пункты
        list_item = ItemList(
            name="List With Items",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        for i in range(3):
            item = ListItem(
                list_id=list_item.id,
                name=f"Item {i}",
                order_index=i
            )
            db_session.add(item)
        await db_session.commit()
        
        response = await client.get(
            f"/api/v1/lists/{list_item.id}/items",
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 3
        assert data[0]["order_index"] == 0
    
    @pytest.mark.asyncio
    async def test_update_list_item(self, client, auth_headers, test_user, db_session):
        """Тест обновления пункта списка."""
        # Создаем список и пункт
        list_item = ItemList(
            name="Test List",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        list_item_obj = ListItem(
            list_id=list_item.id,
            name="Original Item",
            order_index=0
        )
        db_session.add(list_item_obj)
        await db_session.commit()
        await db_session.refresh(list_item_obj)
        
        # Обновляем
        response = await client.put(
            f"/api/v1/lists/items/{list_item_obj.id}",
            json={
                "name": "Updated Item",
                "description": "New Description"
            },
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Item"
        assert data["description"] == "New Description"
    
    @pytest.mark.asyncio
    async def test_delete_list_item(self, client, auth_headers, test_user, db_session):
        """Тест удаления пункта списка."""
        # Создаем список и пункт
        list_item = ItemList(
            name="Test List",
            user_id=test_user.id
        )
        db_session.add(list_item)
        await db_session.commit()
        await db_session.refresh(list_item)
        
        list_item_obj = ListItem(
            list_id=list_item.id,
            name="To Delete",
            order_index=0
        )
        db_session.add(list_item_obj)
        await db_session.commit()
        await db_session.refresh(list_item_obj)
        
        # Удаляем
        response = await client.delete(
            f"/api/v1/lists/items/{list_item_obj.id}",
            headers=auth_headers
        )
        
        assert response.status_code == 204
        
        # Проверяем, что пункт удален
        result = await db_session.execute(
            select(ListItem).where(ListItem.id == list_item_obj.id)
        )
        assert result.scalar_one_or_none() is None
    
    @pytest.mark.asyncio
    async def test_search_lists(self, client, auth_headers, test_user, db_session):
        """Тест поиска списков."""
        # Создаем списки с разными названиями
        lists_names = ["Movie List", "Game List", "Book List"]
        for name in lists_names:
            list_item = ItemList(
                name=name,
                user_id=test_user.id
            )
            db_session.add(list_item)
        await db_session.commit()
        
        # Ищем списки со словом "List"
        response = await client.get(
            "/api/v1/lists/search/?q=List&limit=10",
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 3
        assert all("List" in item["name"] for item in data)