"""
Экспорт/импорт CIM в формате XML (RDF/XML)
Соответствует стандартам IEC 61970-301 и IEC 61970-552
"""
import xml.etree.ElementTree as ET
from xml.dom import minidom
from datetime import datetime
from typing import List, Dict, Any, Optional
from .cim_base import CIMObject, CIMExporter, CIMImporter


class CIMXMLExporter(CIMExporter):
    """
    Экспорт CIM в XML формат (RDF/XML)
    Соответствует стандарту IEC 61970-552:2016
    """
    
    def export(self, objects: List[CIMObject], output_path: Optional[str] = None) -> str:
        """
        Экспорт объектов в CIM XML (RDF/XML формат)
        
        Формат соответствует:
        - IEC 61970-301 (CIM Base)
        - IEC 61970-552:2016 (mRID и обмен данными)
        """
        # Создаем корневой элемент RDF
        # Важно: не устанавливаем xmlns и xmlns:cim с одинаковым значением
        # xmlns используется как default namespace, а xmlns:cim - как префикс
        rdf = ET.Element(
            f"{{{CIMObject.RDF_NAMESPACE}}}RDF"
        )
        # Устанавливаем namespace атрибуты
        # xmlns - default namespace для CIM (элементы без префикса будут использовать этот namespace)
        rdf.set("xmlns", CIMObject.CIM_NAMESPACE)
        # xmlns:rdf - namespace для RDF элементов
        rdf.set("xmlns:rdf", CIMObject.RDF_NAMESPACE)
        # xmlns:rdfs - namespace для RDFS
        rdf.set("xmlns:rdfs", CIMObject.RDFS_NAMESPACE)
        # НЕ устанавливаем xmlns:cim, так как xmlns уже устанавливает default namespace
        # Если нужен префикс cim, можно установить отдельно, но с другим значением
        
        # Добавляем описание (Description)
        description = ET.SubElement(rdf, f"{{{CIMObject.RDF_NAMESPACE}}}Description")
        description.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", "")
        
        # Метаданные экспорта
        metadata = ET.SubElement(description, f"{{{CIMObject.CIM_NAMESPACE}}}ExportMetadata")
        metadata.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"urn:uuid:{datetime.now().strftime('%Y%m%d-%H%M%S')}")
        
        version_elem = ET.SubElement(metadata, f"{{{CIMObject.CIM_NAMESPACE}}}version")
        version_elem.text = "CIM16"
        
        export_time = ET.SubElement(metadata, f"{{{CIMObject.CIM_NAMESPACE}}}exportedAt")
        export_time.text = datetime.now().isoformat()
        
        # Экспортируем все объекты
        for obj in objects:
            cim_obj = self._object_to_xml(obj)
            rdf.append(cim_obj)
        
        # Форматируем XML
        xml_str = self._prettify_xml(rdf)
        
        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(xml_str)
        
        return xml_str
    
    def _object_to_xml(self, obj: CIMObject) -> ET.Element:
        """Преобразование CIM объекта в XML элемент"""
        cim_dict = obj.to_cim_dict()
        cim_class = obj.get_cim_class()
        
        # Создаем элемент для объекта
        obj_elem = ET.Element(f"{{{CIMObject.CIM_NAMESPACE}}}{cim_class}")
        obj_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"urn:uuid:{obj.mrid}")
        
        # Добавляем свойства объекта
        for key, value in cim_dict.items():
            if key == "mRID":  # mRID уже в атрибуте about
                continue
            
            prop_elem = ET.SubElement(obj_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{key}")
            
            if isinstance(value, dict):
                # Вложенный объект
                if "mRID" in value:
                    prop_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"urn:uuid:{value['mRID']}")
                else:
                    # Вложенный объект без mRID - создаем inline
                    nested = self._dict_to_xml(value, prop_elem)
            elif isinstance(value, list):
                # Список объектов или значений
                for item in value:
                    if isinstance(item, dict):
                        if "mRID" in item:
                            item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            item_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"urn:uuid:{item['mRID']}")
                        else:
                            item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            self._dict_to_xml(item, item_elem)
                    else:
                        # Простое значение
                        item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}value")
                        item_elem.text = str(item)
            elif value is not None:
                # Простое значение
                prop_elem.text = str(value)
        
        return obj_elem
    
    def _dict_to_xml(self, data: Dict[str, Any], parent: ET.Element) -> ET.Element:
        """Рекурсивное преобразование словаря в XML"""
        for key, value in data.items():
            if key == "mRID":
                continue
            elem = ET.SubElement(parent, f"{{{CIMObject.CIM_NAMESPACE}}}{key}")
            if isinstance(value, dict):
                self._dict_to_xml(value, elem)
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        item_elem = ET.SubElement(elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                        self._dict_to_xml(item, item_elem)
                    else:
                        item_elem = ET.SubElement(elem, f"{{{CIMObject.CIM_NAMESPACE}}}value")
                        item_elem.text = str(item)
            elif value is not None:
                elem.text = str(value)
        return parent
    
    def _prettify_xml(self, elem: ET.Element) -> str:
        """Форматирование XML для читаемости"""
        try:
            # Используем метод, который не вызывает проблем с дублирующимися атрибутами
            rough_string = ET.tostring(elem, encoding='utf-8', xml_declaration=True)
            
            # Проверяем на дублирующиеся атрибуты перед парсингом
            rough_str = rough_string.decode('utf-8')
            
            # Парсим через minidom
            reparsed = minidom.parseString(rough_string)
            pretty = reparsed.toprettyxml(indent="  ", encoding='utf-8').decode('utf-8')
            
            # Убираем пустые строки между элементами
            lines = [line for line in pretty.split('\n') if line.strip()]
            return '\n'.join(lines)
        except Exception as e:
            # Если prettify не работает из-за дублирующихся атрибутов, используем простое форматирование
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Ошибка при форматировании XML: {str(e)}")
            
            # Пробуем исправить дублирующиеся атрибуты вручную
            rough_string = ET.tostring(elem, encoding='utf-8', xml_declaration=True)
            rough_str = rough_string.decode('utf-8')
            
            # Удаляем дублирующиеся атрибуты xmlns
            import re
            # Находим все xmlns атрибуты и удаляем дубликаты
            xmlns_pattern = r'xmlns(?:[:]\w+)?="[^"]*"'
            matches = re.findall(xmlns_pattern, rough_str)
            seen = set()
            for match in matches:
                if match in seen:
                    rough_str = rough_str.replace(match, '', 1)
                else:
                    seen.add(match)
            
            try:
                reparsed = minidom.parseString(rough_str.encode('utf-8'))
                pretty = reparsed.toprettyxml(indent="  ", encoding='utf-8').decode('utf-8')
                lines = [line for line in pretty.split('\n') if line.strip()]
                return '\n'.join(lines)
            except Exception:
                # Если всё ещё не работает, возвращаем без форматирования
                return rough_str


class CIMXMLImporter(CIMImporter):
    """Импорт CIM из XML формата (RDF/XML)"""
    
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """Импорт объектов из XML файла"""
        tree = ET.parse(file_path)
        root = tree.getroot()
        
        objects = []
        
        # Находим все CIM объекты (все элементы с namespace CIM)
        for elem in root.iter():
            if CIMObject.CIM_NAMESPACE in elem.tag:
                obj_dict = self._xml_to_dict(elem)
                if obj_dict:
                    objects.append(obj_dict)
        
        return objects
    
    def _xml_to_dict(self, elem: ET.Element) -> Dict[str, Any]:
        """Преобразование XML элемента в словарь"""
        # Извлекаем mRID из атрибута rdf:about
        mrid = elem.get(f"{{{CIMObject.RDF_NAMESPACE}}}about", "").replace("urn:uuid:", "")
        if not mrid:
            return {}
        
        obj_dict = {"mRID": mrid}
        
        # Извлекаем имя класса
        tag = elem.tag.replace(f"{{{CIMObject.CIM_NAMESPACE}}}", "")
        obj_dict["type"] = tag
        
        # Извлекаем свойства
        for child in elem:
            prop_name = child.tag.replace(f"{{{CIMObject.CIM_NAMESPACE}}}", "")
            
            # Проверяем, является ли это ссылкой на другой объект
            resource = child.get(f"{{{CIMObject.RDF_NAMESPACE}}}resource")
            if resource:
                obj_dict[prop_name] = {"mRID": resource.replace("urn:uuid:", "")}
            elif len(child) > 0:
                # Вложенный объект
                obj_dict[prop_name] = self._xml_to_dict(child)
            else:
                # Простое значение
                obj_dict[prop_name] = child.text
        
        return obj_dict

