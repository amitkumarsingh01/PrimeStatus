import databases
import sqlalchemy
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from passlib.context import CryptContext
from typing import Optional

# --- Configuration ---
DATABASE_URL = "sqlite:///./crafto_users.db"
database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()

# --- Database Model ---
users = sqlalchemy.Table(
    "users",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("mobile_number", sqlalchemy.String, unique=True, index=True),
    sqlalchemy.Column("language", sqlalchemy.String),
    sqlalchemy.Column("usage_type", sqlalchemy.String),
    sqlalchemy.Column("name", sqlalchemy.String),
    sqlalchemy.Column("profile_photo_url", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("religion", sqlalchemy.String),
    sqlalchemy.Column("state", sqlalchemy.String),
    sqlalchemy.Column("subscription", sqlalchemy.String, default="free"),
)

# --- FastAPI App Instance ---
app = FastAPI(title="QuoteCraft Backend")

# --- Database Connection Events ---
@app.on_event("startup")
async def startup():
    engine = sqlalchemy.create_engine(DATABASE_URL)
    metadata.create_all(engine)
    await database.connect()

@app.on_event("shutdown")
async def shutdown():
    await database.disconnect()

# --- Pydantic Schemas ---
class UserCreate(BaseModel):
    mobile_number: str
    language: str
    usage_type: str
    name: str
    profile_photo_url: Optional[str] = None
    religion: str
    state: str
    subscription: Optional[str] = "free"

class UserDisplay(BaseModel):
    id: int
    mobile_number: str
    name: str
    language: str
    usage_type: str
    religion: str
    state: str
    subscription: str
    profile_photo_url: Optional[str] = None

class UserUpdate(BaseModel):
    language: Optional[str] = None
    usage_type: Optional[str] = None
    name: Optional[str] = None
    profile_photo_url: Optional[str] = None
    religion: Optional[str] = None
    state: Optional[str] = None
    subscription: Optional[str] = None

# --- API Endpoints ---
@app.post("/register/", response_model=UserDisplay)
async def create_user(user: UserCreate):
    """
    Registers a new user. Checks if a user with the given mobile number
    already exists.
    """
    query = users.select().where(users.c.mobile_number == user.mobile_number)
    existing_user = await database.fetch_one(query)

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="User with this mobile number already exists."
        )

    query = users.insert().values(
        mobile_number=user.mobile_number,
        language=user.language,
        usage_type=user.usage_type,
        name=user.name,
        profile_photo_url=user.profile_photo_url,
        religion=user.religion,
        state=user.state,
        subscription=user.subscription,
    )
    last_record_id = await database.execute(query)
    
    return UserDisplay(
        id=last_record_id,
        mobile_number=user.mobile_number,
        name=user.name,
        language=user.language,
        usage_type=user.usage_type,
        religion=user.religion,
        state=user.state,
        subscription=user.subscription or "free",
        profile_photo_url=user.profile_photo_url
    )

@app.get("/user/{mobile_number}", response_model=UserDisplay)
async def get_user(mobile_number: str):
    """
    Retrieves user details by mobile number.
    """
    query = users.select().where(users.c.mobile_number == mobile_number)
    user = await database.fetch_one(query)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/user/{mobile_number}", response_model=UserDisplay)
async def update_user(mobile_number: str, user: UserCreate):
    """
    Fully update a user's details by mobile number.
    """
    query = users.select().where(users.c.mobile_number == mobile_number)
    existing_user = await database.fetch_one(query)
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")

    update_query = users.update().where(users.c.mobile_number == mobile_number).values(
        language=user.language,
        usage_type=user.usage_type,
        name=user.name,
        profile_photo_url=user.profile_photo_url,
        religion=user.religion,
        state=user.state,
        subscription=user.subscription,
    )
    await database.execute(update_query)
    return await get_user(mobile_number)

@app.patch("/user/{mobile_number}", response_model=UserDisplay)
async def patch_user(mobile_number: str, user: UserUpdate):
    """
    Partially update a user's details by mobile number.
    """
    query = users.select().where(users.c.mobile_number == mobile_number)
    existing_user = await database.fetch_one(query)
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")

    update_data = user.dict(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update.")

    update_query = users.update().where(users.c.mobile_number == mobile_number).values(**update_data)
    await database.execute(update_query)
    return await get_user(mobile_number)

@app.delete("/user/{mobile_number}")
async def delete_user(mobile_number: str):
    """
    Delete a user by mobile number.
    """
    query = users.select().where(users.c.mobile_number == mobile_number)
    existing_user = await database.fetch_one(query)
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")

    delete_query = users.delete().where(users.c.mobile_number == mobile_number)
    await database.execute(delete_query)
    return {"detail": "User deleted successfully."}
