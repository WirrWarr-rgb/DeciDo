# app/main.py
from fastapi import FastAPI, WebSocket
from app.api.v1 import router as v1_router
from app.api.v1.endpoints.sessions_ws import sessions_websocket
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.endpoints.global_ws import global_websocket

app = FastAPI(
    title="Decido API",
    version="1.0.0",
    description="API for collaborative decision making"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключаем v1 API
app.include_router(v1_router)

# WebSocket эндпоинт
@app.websocket("/api/v1/sessions/{session_id}/ws")
async def websocket_endpoint(websocket: WebSocket, session_id: int, token: str = None):
    await sessions_websocket(websocket, session_id, token)

@app.websocket("/api/v1/global")
async def global_ws_endpoint(websocket: WebSocket, token: str = None):
    await global_websocket(websocket, token)

@app.get("/")
async def root():
    return {"message": "Hello from Decido API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}