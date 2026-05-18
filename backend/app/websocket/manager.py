import json
import asyncio
from typing import Dict, Set, Any, Optional
from fastapi import WebSocket, WebSocketDisconnect

import redis.asyncio as redis
from app.core.config import settings


class ConnectionManager:
    """
    Менеджер WebSocket подключений с поддержкой Redis Pub/Sub
    для масштабирования на несколько инстансов сервера.
    """
    
    def __init__(self, redis_url: str = "redis://localhost:6379"):
        # Локальные подключения: session_id -> {user_id: WebSocket}
        self.local_connections: Dict[int, Dict[int, WebSocket]] = {}
        
        # Redis клиент для pub/sub
        self.redis_client: Optional[redis.Redis] = None
        self.redis_url = redis_url
        self.pubsub: Optional[redis.client.PubSub] = None
        
        # Флаг инициализации
        self._initialized = False
    
    async def initialize(self):
        """Инициализировать подключение к Redis."""
        if not self._initialized:
            try:
                self.redis_client = await redis.from_url(
                    self.redis_url,
                    decode_responses=True
                )
                self.pubsub = self.redis_client.pubsub()
                self._initialized = True
                asyncio.create_task(self._listen_redis())
            except Exception as e:
                print(f"⚠️ Redis connection failed: {e}, continuing without Redis")
                self._initialized = True  # Помечаем как инициализированный, даже если Redis не работает
    
    async def _listen_redis(self):
        """Слушать сообщения из Redis и рассылать локальным клиентам."""
        if not self.pubsub:
            return
            
        # Подписываемся на паттерн session:*
        await self.pubsub.psubscribe("session:*")
        
        async for message in self.pubsub.listen():
            if message["type"] == "pmessage":
                channel = message["channel"]  # session:{session_id}
                data = message["data"]
                
                try:
                    session_id = int(channel.split(":")[1])
                    payload = json.loads(data)
                    
                    # Рассылаем локальным клиентам в этой сессии
                    if session_id in self.local_connections:
                        for ws in self.local_connections[session_id].values():
                            try:
                                await ws.send_json(payload)
                            except:
                                pass  # Игнорируем ошибки отправки
                except (ValueError, json.JSONDecodeError):
                    pass  # Игнорируем некорректные сообщения
    
    async def connect(self, session_id: int, user_id: int, websocket: WebSocket):
        """Подключить нового клиента."""
        print(f"🔌 [CONNECT] START: user {user_id} to session {session_id}")
        print(f"   Current local_connections before: {self.local_connections}")
        
        if session_id not in self.local_connections:
            self.local_connections[session_id] = {}
            print(f"   Created new session {session_id} in local_connections")
        
        self.local_connections[session_id][user_id] = websocket
        print(f"   Added user {user_id} to session {session_id}")
        print(f"   Current local_connections after: {self.local_connections}")
        print(f"🔌 [CONNECT] END")

    def disconnect(self, session_id: int, user_id: int):
        """Отключить клиента."""
        print(f"🔌 [DISCONNECT] START: user {user_id} from session {session_id}")
        print(f"   Current local_connections before: {self.local_connections}")
        
        if session_id in self.local_connections:
            if user_id in self.local_connections[session_id]:
                del self.local_connections[session_id][user_id]
                print(f"   Removed user {user_id} from session {session_id}")
            
            # Если в сессии не осталось клиентов, удаляем запись
            if not self.local_connections[session_id]:
                del self.local_connections[session_id]
                print(f"   Removed empty session {session_id}")
        
        print(f"   Current local_connections after: {self.local_connections}")
        print(f"🔌 [DISCONNECT] END")
    
    async def broadcast_to_session(self, session_id: int, message: Dict[str, Any]):
        """
        Отправить сообщение всем клиентам в сессии.
        """
        session_id = int(session_id)
        
        print(f"------------- broadcast_to_session: session_id={session_id}")
        print(f"------------- local_connections keys: {list(self.local_connections.keys())}")
        print(f"------------- message: {message}")
        
        # Проверяем, есть ли подключения
        if session_id not in self.local_connections:
            print(f"------------- No connections for session {session_id}, skipping broadcast")
            print(f"------------- Available sessions: {list(self.local_connections.keys())}")
            return
        
        if not self.local_connections[session_id]:
            print(f"------------- Empty connections for session {session_id}")
            return
        
        # Сохраняем копию словаря, так как он может измениться во время итерации
        connections = dict(self.local_connections[session_id])
        
        disconnected = []
        for user_id, ws in connections.items():
            print(f"------------- sending to user {user_id}")
            try:
                await ws.send_json(message)
                print(f"------------- successfully sent to user {user_id}")
            except Exception as e:
                print(f"------------- error sending to user {user_id}: {e}")
                disconnected.append(user_id)
        
        for user_id in disconnected:
            self.disconnect(session_id, user_id)
    
    async def send_personal(
        self, 
        session_id: int, 
        user_id: int, 
        message: Dict[str, Any]
    ):
        """Отправить сообщение конкретному клиенту."""
        if (session_id in self.local_connections and 
            user_id in self.local_connections[session_id]):
            try:
                await self.local_connections[session_id][user_id].send_json(message)
            except:
                self.disconnect(session_id, user_id)

    async def send_to_user(self, user_id: int, message: Dict[str, Any]):
        """Отправить сообщение конкретному пользователю"""
        print(f"🔍 Looking for user {user_id} in connections...")
        print(f"   Global connections (session 0): {0 in self.local_connections}")
        if 0 in self.local_connections:
            print(f"   Users in global: {list(self.local_connections[0].keys())}")
        
        # Сначала проверяем глобальное подключение (session_id = 0)
        if 0 in self.local_connections and user_id in self.local_connections[0]:
            try:
                await self.local_connections[0][user_id].send_json(message)
                print(f"✅ Sent message to user {user_id} via global channel: {message['type']}")
                return  # Отправили через глобальный канал
            except Exception as e:
                print(f"❌ Failed to send via global: {e}")
        
        # Потом ищем по сессиям
        for session_id, connections in self.local_connections.items():
            if user_id in connections:
                try:
                    await connections[user_id].send_json(message)
                    print(f"✅ Sent message to user {user_id} in session {session_id}")
                except Exception as e:
                    print(f"❌ Failed to send: {e}")


# Глобальный экземпляр менеджера
manager = ConnectionManager(redis_url=getattr(settings, 'REDIS_URL', 'redis://localhost:6379'))