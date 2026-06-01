"""Единые ограничения пароля для API (admin, register, mobile, web)."""

MIN_PASSWORD_LENGTH = 6
MAX_PASSWORD_LENGTH = 128

MIN_PASSWORD_LENGTH_MSG = (
    f"Пароль должен содержать не менее {MIN_PASSWORD_LENGTH} символов"
)
