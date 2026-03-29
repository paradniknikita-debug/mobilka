"""
Экспорт/импорт CIM в формате XML с использованием библиотеки CIMpy
Альтернативная реализация с использованием специализированной библиотеки
"""
from typing import List, Dict, Any, Optional, Union
import os
import tempfile

try:
    import cimpy
    CIMPY_AVAILABLE = True
except ImportError:
    CIMPY_AVAILABLE = False
    cimpy = None

from .cim_base import CIMExporter, CIMImporter


class CIMpyXMLExporter:
    """
    Экспорт CIM в XML формат с использованием библиотеки CIMpy
    
    Требует установки: pip install cimpy
    Работает напрямую с моделями БД (Substation, PowerLine и т.д.)
    """
    
    def __init__(self, cim_version: str = "cgmes_v2_4_15"):
        """
        Инициализация экспортера
        
        Args:
            cim_version: Версия CIM схемы (cgmes_v2_4_15, cgmes_v3_0_0 и т.д.)
        """
        if not CIMPY_AVAILABLE:
            raise ImportError(
                "CIMpy library is not installed. Install it with: pip install cimpy"
            )
        self.cim_version = cim_version
        self._import_cimpy_modules()
    
    def _import_cimpy_modules(self):
        """Импорт модулей CIMpy в зависимости от версии"""
        try:
            if self.cim_version == "cgmes_v2_4_15":
                from cimpy.cgmes_v2_4_15 import set_of_resources
            elif self.cim_version == "cgmes_v3_0_0":
                from cimpy.cgmes_v3_0_0 import set_of_resources
            else:
                # По умолчанию используем cgmes_v2_4_15
                from cimpy.cgmes_v2_4_15 import set_of_resources
            self.set_of_resources = set_of_resources
        except ImportError as e:
            raise ImportError(f"Could not import CIMpy modules for version {self.cim_version}: {e}")
    
    def export_models(self, substations: List = None, power_lines: List = None, output_path: Optional[str] = None) -> str:
        """
        Экспорт моделей БД в CIM XML
        
        Args:
            substations: Список объектов Substation из БД
            power_lines: Список объектов PowerLine из БД
            output_path: Путь для сохранения файла (опционально)
        
        Returns:
            XML строка
        """
        # Создаем CIM модель
        cim_model = cimpy.CIM()
        
        # Преобразуем подстанции
        if substations:
            for substation in substations:
                cimpy_objs = self._substation_to_cimpy(substation)
                for obj in cimpy_objs:
                    if obj:
                        cim_model.add(obj)
        
        # Преобразуем ЛЭП
        if power_lines:
            for power_line in power_lines:
                cimpy_objs = self._power_line_to_cimpy(power_line)
                for obj in cimpy_objs:
                    if obj:
                        cim_model.add(obj)
        
        # Экспортируем в XML
        try:
            if output_path:
                cimpy.cim_writer(cim_model, output_path, self.cim_version)
                with open(output_path, 'r', encoding='utf-8') as f:
                    return f.read()
            else:
                # Временный файл для получения XML строки
                with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False, encoding='utf-8') as f:
                    temp_path = f.name
                
                try:
                    cimpy.cim_writer(cim_model, temp_path, self.cim_version)
                    with open(temp_path, 'r', encoding='utf-8') as f:
                        return f.read()
                finally:
                    if os.path.exists(temp_path):
                        try:
                            os.remove(temp_path)
                        except Exception:
                            pass  # Игнорируем ошибки удаления временного файла
        except Exception as e:
            # Логируем детальную ошибку
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Ошибка при экспорте CIM XML через CIMpy: {str(e)}", exc_info=True)
            raise Exception(f"Ошибка экспорта CIM XML: {str(e)}") from e
    
    def _substation_to_cimpy(self, substation) -> List:
        """Преобразование Substation в CIMpy объекты"""
        cimpy_objs = []
        
        try:
            # Создаем Substation
            SubstationClass = getattr(self.set_of_resources, "Substation", None)
            if not SubstationClass:
                return cimpy_objs
            
            cimpy_substation = SubstationClass()
            cimpy_substation.mRID = substation.mrid
            if substation.name:
                cimpy_substation.name = substation.name
            cimpy_objs.append(cimpy_substation)
            
            # Создаем Location и PositionPoint если есть координаты
            if substation.location and substation.location.position_points:
                LocationClass = getattr(self.set_of_resources, "Location", None)
                if LocationClass:
                    cimpy_location = LocationClass()
                    cimpy_location.mRID = substation.location.mrid
                    if substation.location.address:
                        cimpy_location.mainAddress = substation.location.address
                    cimpy_objs.append(cimpy_location)
                    
                    # Создаем PositionPoint
                    PositionPointClass = getattr(self.set_of_resources, "PositionPoint", None)
                    if PositionPointClass:
                        for pp in substation.location.position_points:
                            cimpy_pp = PositionPointClass()
                            cimpy_pp.mRID = pp.mrid
                            cimpy_pp.xPosition = pp.x_position
                            cimpy_pp.yPosition = pp.y_position
                            if pp.z_position is not None:
                                cimpy_pp.zPosition = pp.z_position
                            cimpy_pp.Location = cimpy_location
                            cimpy_objs.append(cimpy_pp)
                    
                    # Связываем Location с Substation
                    cimpy_substation.Location = cimpy_location
            
            # Создаем VoltageLevel
            VoltageLevelClass = getattr(self.set_of_resources, "VoltageLevel", None)
            if VoltageLevelClass:
                for vl in substation.voltage_levels:
                    cimpy_vl = VoltageLevelClass()
                    cimpy_vl.mRID = vl.mrid
                    if vl.name:
                        cimpy_vl.name = vl.name
                    cimpy_vl.nominalVoltage = vl.nominal_voltage
                    cimpy_vl.Substation = cimpy_substation
                    cimpy_objs.append(cimpy_vl)
            
        except Exception as e:
            print(f"Warning: Could not convert Substation {substation.id} to CIMpy: {e}")
        
        return cimpy_objs
    
    def _power_line_to_cimpy(self, power_line) -> List:
        """Преобразование PowerLine в CIMpy объекты"""
        cimpy_objs = []
        
        try:
            # Создаем Line
            LineClass = getattr(self.set_of_resources, "Line", None)
            if not LineClass:
                return cimpy_objs
            
            cimpy_line = LineClass()
            cimpy_line.mRID = power_line.mrid
            if power_line.name:
                cimpy_line.name = power_line.name
            cimpy_objs.append(cimpy_line)
            
            # Создаем ACLineSegment
            ACLineSegmentClass = getattr(self.set_of_resources, "ACLineSegment", None)
            if ACLineSegmentClass:
                for segment in power_line.acline_segments:
                    cimpy_segment = ACLineSegmentClass()
                    cimpy_segment.mRID = segment.mrid
                    if segment.name:
                        cimpy_segment.name = segment.name
                    if segment.length is not None:
                        cimpy_segment.length = segment.length
                    if segment.r is not None:
                        cimpy_segment.r = segment.r
                    if segment.x is not None:
                        cimpy_segment.x = segment.x
                    if segment.b is not None:
                        cimpy_segment.b = segment.b
                    if segment.g is not None:
                        cimpy_segment.g = segment.g
                    cimpy_segment.Line = cimpy_line
                    cimpy_objs.append(cimpy_segment)
                    
                    # Создаем ConnectivityNode для опор
                    ConnectivityNodeClass = getattr(self.set_of_resources, "ConnectivityNode", None)
                    if ConnectivityNodeClass:
                        if segment.from_node:
                            cimpy_node = ConnectivityNodeClass()
                            cimpy_node.mRID = segment.from_node.mrid
                            if segment.from_node.name:
                                cimpy_node.name = segment.from_node.name
                            cimpy_segment.Terminal = [cimpy_node]  # Упрощенная связь
                            cimpy_objs.append(cimpy_node)
                        
                        if segment.to_node:
                            cimpy_node = ConnectivityNodeClass()
                            cimpy_node.mRID = segment.to_node.mrid
                            if segment.to_node.name:
                                cimpy_node.name = segment.to_node.name
                            if not hasattr(cimpy_segment, 'Terminal') or not cimpy_segment.Terminal:
                                cimpy_segment.Terminal = []
                            cimpy_segment.Terminal.append(cimpy_node)
                            cimpy_objs.append(cimpy_node)
            
        except Exception as e:
            print(f"Warning: Could not convert PowerLine {power_line.id} to CIMpy: {e}")
        
        return cimpy_objs


class CIMpyXMLImporter(CIMImporter):
    """
    Импорт CIM из XML формата с использованием библиотеки CIMpy
    
    Требует установки: pip install cimpy
    """
    
    def __init__(self, cim_version: str = "cgmes_v2_4_15"):
        """
        Инициализация импортера
        
        Args:
            cim_version: Версия CIM схемы
        """
        if not CIMPY_AVAILABLE:
            raise ImportError(
                "CIMpy library is not installed. Install it with: pip install cimpy"
            )
        self.cim_version = cim_version
    
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """
        Импорт объектов из XML файла с использованием CIMpy
        
        Args:
            file_path: Путь к XML файлу
        
        Returns:
            Список словарей с данными объектов
        """
        # Читаем CIM XML файл
        cim_model = cimpy.cim_reader(file_path, self.cim_version)
        
        # Преобразуем CIMpy объекты в словари
        objects = []
        
        # Получаем все типы объектов
        object_types = [
            "Substation", "VoltageLevel", "BaseVoltage",
            "Location", "PositionPoint",
            "Line", "ACLineSegment", "ConnectivityNode"
        ]
        
        for obj_type in object_types:
            cimpy_objects = cim_model.get_all_objects(obj_type)
            for cimpy_obj in cimpy_objects:
                obj_dict = self._convert_from_cimpy(cimpy_obj, obj_type)
                if obj_dict:
                    objects.append(obj_dict)
        
        return objects
    
    def _convert_from_cimpy(self, cimpy_obj, obj_type: str) -> Optional[Dict[str, Any]]:
        """
        Преобразование CIMpy объекта в словарь
        
        Args:
            cimpy_obj: CIMpy объект
            obj_type: Тип объекта
        
        Returns:
            Словарь с данными объекта или None
        """
        try:
            obj_dict = {
                "type": obj_type,
                "mRID": getattr(cimpy_obj, "mRID", ""),
            }
            
            # Добавляем основные поля
            if hasattr(cimpy_obj, "name"):
                obj_dict["name"] = cimpy_obj.name
            
            # Добавляем специфичные поля в зависимости от типа
            if obj_type == "Substation":
                if hasattr(cimpy_obj, "VoltageLevel"):
                    obj_dict["VoltageLevel"] = [
                        {"mRID": vl.mRID} for vl in cimpy_obj.VoltageLevel
                    ]
                if hasattr(cimpy_obj, "Location"):
                    obj_dict["Location"] = {"mRID": cimpy_obj.Location.mRID}
            
            elif obj_type == "VoltageLevel":
                if hasattr(cimpy_obj, "nominalVoltage"):
                    obj_dict["nominalVoltage"] = cimpy_obj.nominalVoltage
                if hasattr(cimpy_obj, "BaseVoltage"):
                    obj_dict["BaseVoltage"] = {"mRID": cimpy_obj.BaseVoltage.mRID}
            
            elif obj_type == "PositionPoint":
                if hasattr(cimpy_obj, "xPosition"):
                    obj_dict["xPosition"] = cimpy_obj.xPosition
                if hasattr(cimpy_obj, "yPosition"):
                    obj_dict["yPosition"] = cimpy_obj.yPosition
                if hasattr(cimpy_obj, "zPosition"):
                    obj_dict["zPosition"] = cimpy_obj.zPosition
            
            elif obj_type == "ACLineSegment":
                if hasattr(cimpy_obj, "length"):
                    obj_dict["length"] = cimpy_obj.length
                if hasattr(cimpy_obj, "r"):
                    obj_dict["r"] = cimpy_obj.r
                if hasattr(cimpy_obj, "x"):
                    obj_dict["x"] = cimpy_obj.x
            
            return obj_dict
            
        except Exception as e:
            print(f"Warning: Could not convert {obj_type} from CIMpy: {e}")
            return None

