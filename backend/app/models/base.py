"""
Базовые утилиты для моделей
"""
import uuid

def generate_mrid():
    """Генерация mRID (Master Resource Identifier) по стандарту IEC 61970-552:2016"""
    return str(uuid.uuid4())


