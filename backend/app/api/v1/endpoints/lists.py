from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import List
from app.core.database import get_db
from app.models.user import User
from app.models.list import ItemList, ListItem
from app.schemas.list import (
    ListCreate, ListResponse, ListUpdate,
    ListItemCreate, ListItemUpdate, ListItemResponse,
    BulkOrderUpdate
)
from app.api.v1.endpoints.auth import get_current_user

router = APIRouter(prefix="/lists", tags=["lists"])

# ============= Эндпоинты для списков =============

@router.post("/", response_model=ListResponse, status_code=status.HTTP_201_CREATED)
async def create_list(
    list_data: ListCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создать новый список."""
    new_list = ItemList(
        name=list_data.name,
        user_id=current_user.id
    )
    db.add(new_list)
    await db.commit()
    await db.refresh(new_list)
    return new_list

@router.get("/", response_model=List[ListResponse])
async def get_my_lists(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 100
):
    """Получить все списки текущего пользователя."""
    result = await db.execute(
        select(ItemList)
        .where(ItemList.user_id == current_user.id)
        .offset(skip)
        .limit(limit)
        .order_by(ItemList.created_at.desc())
    )
    lists = result.scalars().all()
    return lists

@router.get("/{list_id}", response_model=ListResponse)
async def get_list(
    list_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить список по ID."""
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    return list_item

@router.put("/{list_id}", response_model=ListResponse)
async def update_list(
    list_id: int,
    list_data: ListUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить список."""
    # Находим список
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Обновляем только переданные поля
    if list_data.name is not None:
        list_item.name = list_data.name
    
    await db.commit()
    await db.refresh(list_item)
    return list_item

@router.delete("/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_list(
    list_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить список (и все его пункты)."""
    # Находим список
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Удаляем список (каскадно удалятся и пункты, благодаря ForeignKey)
    await db.delete(list_item)
    await db.commit()

# ============= Эндпоинты для пунктов списка =============

@router.post("/{list_id}/items", response_model=ListItemResponse, status_code=status.HTTP_201_CREATED)
async def create_list_item(
    list_id: int,
    item_data: ListItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Добавить пункт в список."""
    # Проверяем, что список существует и принадлежит пользователю
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Если order_index не указан, ставим в конец
    if item_data.order_index == 0:
        # Находим максимальный order_index
        max_order_result = await db.execute(
            select(ListItem.order_index)
            .where(ListItem.list_id == list_id)
            .order_by(ListItem.order_index.desc())
            .limit(1)
        )
        max_order = max_order_result.scalar_one_or_none()
        order_index = (max_order + 1) if max_order is not None else 0
    else:
        order_index = item_data.order_index
    
    new_item = ListItem(
        list_id=list_id,
        name=item_data.name,
        description=item_data.description,
        image_url=item_data.image_url,
        order_index=order_index
    )
    
    db.add(new_item)
    await db.commit()
    await db.refresh(new_item)
    return new_item

@router.get("/{list_id}/items", response_model=List[ListItemResponse])
async def get_list_items(
    list_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить все пункты списка, отсортированные по order_index."""
    # Проверяем, что список существует и принадлежит пользователю
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Получаем пункты, отсортированные по order_index
    result = await db.execute(
        select(ListItem)
        .where(ListItem.list_id == list_id)
        .order_by(ListItem.order_index)
    )
    items = result.scalars().all()
    return items

@router.put("/items/{item_id}", response_model=ListItemResponse)
async def update_list_item(
    item_id: int,
    item_data: ListItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить пункт списка."""
    # Находим пункт
    result = await db.execute(
        select(ListItem).where(ListItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found"
        )
    
    # Проверяем, что список принадлежит пользователю
    list_result = await db.execute(
        select(ItemList).where(ItemList.id == item.list_id)
    )
    list_item = list_result.scalar_one_or_none()
    
    if not list_item or list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Обновляем только переданные поля
    if item_data.name is not None:
        item.name = item_data.name
    if item_data.description is not None:
        item.description = item_data.description
    if item_data.image_url is not None:
        item.image_url = item_data.image_url
    if item_data.order_index is not None:
        item.order_index = item_data.order_index
    
    await db.commit()
    await db.refresh(item)
    return item

@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_list_item(
    item_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить пункт списка."""
    # Находим пункт
    result = await db.execute(
        select(ListItem).where(ListItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found"
        )
    
    # Проверяем, что список принадлежит пользователю
    list_result = await db.execute(
        select(ItemList).where(ItemList.id == item.list_id)
    )
    list_item = list_result.scalar_one_or_none()
    
    if not list_item or list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    await db.delete(item)
    await db.commit()

# ============= Дополнительные эндпоинты =============

@router.post("/items/bulk-order", response_model=List[ListItemResponse])
async def bulk_update_order(
    list_id: int,
    order_data: BulkOrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Массовое обновление порядка пунктов.
    Используется для drag-and-drop сортировки.
    """
    # Проверяем, что список принадлежит пользователю
    list_result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = list_result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Обновляем order_index для каждого пункта
    for item_update in order_data.items:
        await db.execute(
            update(ListItem)
            .where(ListItem.id == item_update["id"])
            .where(ListItem.list_id == list_id)
            .values(order_index=item_update["order_index"])
        )
    
    await db.commit()
    
    # Возвращаем обновленный список пунктов
    result = await db.execute(
        select(ListItem)
        .where(ListItem.list_id == list_id)
        .order_by(ListItem.order_index)
    )
    items = result.scalars().all()
    return items

@router.get("/search/", response_model=List[ListResponse])
async def search_lists(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = 20
):
    """
    Поиск списков по названию.
    """
    result = await db.execute(
        select(ItemList)
        .where(ItemList.user_id == current_user.id)
        .where(ItemList.name.ilike(f"%{q}%"))
        .limit(limit)
        .order_by(ItemList.created_at.desc())
    )
    lists = result.scalars().all()
    return lists

@router.get("/items/search/", response_model=List[ListItemResponse])
async def search_list_items(
    list_id: int,
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = 20
):
    """
    Поиск пунктов в списке по названию.
    """
    # Проверяем доступ к списку
    list_result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    list_item = list_result.scalar_one_or_none()
    
    if not list_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if list_item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Поиск по названию
    result = await db.execute(
        select(ListItem)
        .where(ListItem.list_id == list_id)
        .where(ListItem.name.ilike(f"%{q}%"))
        .limit(limit)
        .order_by(ListItem.order_index)
    )
    items = result.scalars().all()
    return items

@router.get("/stats/", response_model=dict)
async def get_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Получить статистику по спискам пользователя.
    """
    # Общее количество списков
    lists_count_result = await db.execute(
        select(ItemList).where(ItemList.user_id == current_user.id)
    )
    lists_count = len(lists_count_result.scalars().all())
    
    # Общее количество пунктов во всех списках
    items_count_result = await db.execute(
        select(ListItem)
        .join(ItemList)
        .where(ItemList.user_id == current_user.id)
    )
    items_count = len(items_count_result.scalars().all())
    
    # Список с наибольшим количеством пунктов
    top_list_result = await db.execute(
        select(ItemList)
        .where(ItemList.user_id == current_user.id)
        .order_by(ItemList.id)
    )
    
    # Считаем количество пунктов для каждого списка
    list_items_counts = {}
    for list_item in top_list_result.scalars().all():
        count_result = await db.execute(
            select(ListItem).where(ListItem.list_id == list_item.id)
        )
        list_items_counts[list_item.name] = len(count_result.scalars().all())
    
    top_list = max(list_items_counts.items(), key=lambda x: x[1]) if list_items_counts else ("None", 0)
    
    return {
        "total_lists": lists_count,
        "total_items": items_count,
        "list_with_most_items": {
            "name": top_list[0],
            "items_count": top_list[1]
        }
    }

@router.post("/{list_id}/copy", response_model=ListResponse)
async def copy_list(
    list_id: int,
    new_name: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Скопировать список (со всеми пунктами).
    Полезно для создания шаблонов.
    """
    # Находим исходный список
    result = await db.execute(
        select(ItemList).where(ItemList.id == list_id)
    )
    original_list = result.scalar_one_or_none()
    
    if not original_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="List not found"
        )
    
    if original_list.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # Создаем копию списка
    copied_list = ItemList(
        name=new_name or f"{original_list.name} (copy)",
        user_id=current_user.id
    )
    db.add(copied_list)
    await db.flush()  # Получаем ID нового списка
    
    # Копируем все пункты
    items_result = await db.execute(
        select(ListItem).where(ListItem.list_id == list_id)
    )
    original_items = items_result.scalars().all()
    
    for item in original_items:
        new_item = ListItem(
            list_id=copied_list.id,
            name=item.name,
            description=item.description,
            image_url=item.image_url,
            order_index=item.order_index
        )
        db.add(new_item)
    
    await db.commit()
    await db.refresh(copied_list)
    
    return copied_list