# Точка входа в приложение

from fastapi import FastAPI
from app.api.v1.endpoints import auth

app = FastAPI(title="Decido API", version="1.0.0")

# Подключаем роутеры
app.include_router(auth.router)

@app.get("/")
async def root():
    return {"message": "Hello from Decido API"}