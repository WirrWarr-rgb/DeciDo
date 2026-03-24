from fastapi import FastAPI
from app.api.v1 import router as v1_router
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Decido API", version="1.0.0")

# Подключаем v1 API
app.include_router(v1_router)

@app.get("/")
async def root():
    return {"message": "Hello from Decido API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# Добавь CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене замени на конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)