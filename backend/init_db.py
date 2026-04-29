import asyncio
from app.core.database import engine, Base
from app.models.user import User
from app.models.friend import Friend
from app.models.list import ItemList, ListItem
from app.models.session import Session, SessionList, SessionListItem, SessionParticipant, SessionResult

async def init():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print('Tables created!')

if __name__ == '__main__':
    asyncio.run(init())