import os

SECRET_KEY = os.getenv("COFLY_SECRET_KEY", "cofly-dev-secret-key-change-in-prod-16543")
DB_PATH = os.getenv("COFLY_DB_PATH", "cofly.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"
TOKEN_EXPIRE_SECONDS = 7200
REGISTRATION_TOKEN = os.getenv("COFLY_REGISTRATION_TOKEN", "cofly-registration-token-17754")
