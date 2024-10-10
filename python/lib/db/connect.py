from typing import Any

from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy import text

default_port = 3306


def connect_to_db(credentials: dict[str, Any]):
    host     = credentials['host']
    port     = credentials['port']
    username = credentials['username']
    password = credentials['passwd']
    database = credentials['database']
    port     = int(port) if port else default_port
    engine = create_engine(f'mysql+mysqldb://{username}:{password}@{host}:{port}/{database}', pool_pre_ping=True)
    session = Session(engine)
    session.execute(text("SELECT 1"))
    exit()
    return Session(engine)
