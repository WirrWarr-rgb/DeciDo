# app/main.py
from fastapi import FastAPI, WebSocket
from app.api.v1 import router as v1_router
from app.api.v1.endpoints.sessions_ws import sessions_websocket
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Decido API",
    version="1.0.0",
    description="API for collaborative decision making"
)

# Подключаем v1 API
app.include_router(v1_router)

# WebSocket эндпоинт
@app.websocket("/api/v1/sessions/{session_id}/ws")
async def websocket_endpoint(websocket: WebSocket, session_id: int, token: str = None):
    await sessions_websocket(websocket, session_id, token)

@app.get("/")
async def root():
    return {"message": "Hello from Decido API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене замени на конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)