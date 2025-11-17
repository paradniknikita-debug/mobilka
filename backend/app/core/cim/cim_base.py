"""
Базовые классы и утилиты для работы с CIM моделью
Соответствует стандартам IEC 61970-301 и IEC 61968-11
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from datetime import datetime


class CIMObject(ABC):
    """Базовый класс для всех CIM объектов"""
    
    # CIM namespace
    CIM_NAMESPACE = "http://iec.ch/TC57/2013/CIM-schema-cim16#"
    RDF_NAMESPACE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    RDFS_NAMESPACE = "http://www.w3.org/2000/01/rdf-schema#"
    
    def __init__(self, mrid: str, name: Optional[str] = None):
        self.mrid = mrid  # Master Resource Identifier (IEC 61970-552:2016)
        self.name = name
    
    @abstractmethod
    def to_cim_dict(self) -> Dict[str, Any]:
        """Преобразование в словарь CIM"""
        pass
    
    @abstractmethod
    def get_cim_class(self) -> str:
        """Получить имя CIM класса"""
        pass


class CIMExporter(ABC):
    """Базовый класс для экспорта CIM в различные форматы"""
    
    @abstractmethod
    def export(self, objects: List[CIMObject], output_path: Optional[str] = None) -> str:
        """Экспорт объектов в формат"""
        pass


class CIMImporter(ABC):
    """Базовый класс для импорта CIM из различных форматов"""
    
    @abstractmethod
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """Импорт объектов из файла"""
        pass


