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
        md_namespace = "http://iec.ch/TC57/61970-552/ModelDescription/1#"
        
        # Регистрируем namespace'ы ПЕРЕД созданием элементов для использования правильных префиксов (cim:, md:, rdf:)
        # Это нужно делать ДО создания элементов, чтобы ElementTree использовал правильные префиксы
        ET.register_namespace("rdf", CIMObject.RDF_NAMESPACE)
        ET.register_namespace("cim", CIMObject.CIM_NAMESPACE)
        ET.register_namespace("md", md_namespace)
        
        # Дополнительные namespace'ы (опциональные, для расширений)
        # Можно раскомментировать при необходимости интеграции с российскими системами
        # ET.register_namespace("cim17", "http://iec.ch/TC57/CIM100#")
        # ET.register_namespace("me", "http://monitel.com/2014/schema-cim16#")
        # ET.register_namespace("rf", "http://gost.ru/2019/schema-cim01#")
        # ET.register_namespace("rh", "http://rushydro.ru/2015/schema-cim16#")
        # ET.register_namespace("so", "http://so-ups.ru/2015/schema-cim16#")
        
        # Создаем корневой элемент RDF с namespace в фигурных скобках
        # При использовании зарегистрированных namespace'ов ElementTree автоматически добавит все необходимые xmlns атрибуты
        # НЕ устанавливаем их явно, чтобы избежать дублирования
        rdf = ET.Element(f"{{{CIMObject.RDF_NAMESPACE}}}RDF")
        
        # Добавляем FullModel (метаданные экспорта) - соответствует стандарту IEC 61970-552
        full_model_id = f"_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        full_model = ET.SubElement(rdf, f"{{{md_namespace}}}FullModel")
        full_model.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"#{full_model_id}")
        
        # Время создания модели
        created_elem = ET.SubElement(full_model, f"{{{md_namespace}}}Model.created")
        created_elem.text = datetime.now().isoformat() + "Z"
        
        # Версия модели
        version_elem = ET.SubElement(full_model, f"{{{md_namespace}}}Model.version")
        version_elem.text = "1.0"
        
        # Имя модели (версия CIM)
        name_elem = ET.SubElement(full_model, f"{{{CIMObject.CIM_NAMESPACE}}}Model.name")
        name_elem.text = "CIM16"
        
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
        
        # Создаем элемент для объекта с префиксом cim: 
        obj_elem = ET.Element(f"{{{CIMObject.CIM_NAMESPACE}}}{cim_class}")
        # Используем формат rdf:about="#_mrid" 
        obj_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"#_{obj.mrid}")
        
        # Добавляем свойства объекта
        for key, value in cim_dict.items():
            if key == "mRID":  # mRID уже в атрибуте about
                continue
            
            prop_elem = ET.SubElement(obj_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{key}")
            
            if isinstance(value, dict):
                # Вложенный объект
                if "mRID" in value:
                    # Используем формат rdf:resource="#_mrid" 
                    prop_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"#_{value['mRID']}")
                else:
                    # Вложенный объект без mRID - создаем inline
                    nested = self._dict_to_xml(value, prop_elem)
            elif isinstance(value, list):
                # Список объектов или значений
                for item in value:
                    if isinstance(item, dict):
                        if "mRID" in item:
                            item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            # Используем формат rdf:resource="#_mrid" 
                            item_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"#_{item['mRID']}")
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
                if "mRID" in value:
                    # Используем формат rdf:resource="#_mrid" 
                    elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"#_{value['mRID']}")
                else:
                    self._dict_to_xml(value, elem)
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        if "mRID" in item:
                            item_elem = ET.SubElement(elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            # Используем формат rdf:resource="#_mrid"
                            item_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", f"#_{item['mRID']}")
                        else:
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
            # Генерируем XML строку
            rough_string = ET.tostring(elem, encoding='utf-8', xml_declaration=True)
            
            # Парсим через minidom для форматирования
            reparsed = minidom.parseString(rough_string)
            pretty = reparsed.toprettyxml(indent="  ", encoding='utf-8').decode('utf-8')
            
            # Убираем пустые строки между элементами
            lines = [line for line in pretty.split('\n') if line.strip()]
            return '\n'.join(lines)
        except Exception as e:
            # Если prettify не работает, используем простое форматирование
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Ошибка при форматировании XML: {str(e)}")
            
            rough_string = ET.tostring(elem, encoding='utf-8', xml_declaration=True)
            return rough_string.decode('utf-8')


class CIMXMLImporter(CIMImporter):
    """
    Импорт CIM из XML формата (RDF/XML)
    Поддерживает формат FromPlatform_.xml
    """
    
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """Импорт объектов из XML файла"""
        tree = ET.parse(file_path)
        root = tree.getroot()
        
        objects = []
        full_model = None
        
        # Парсим FullModel (метаданные)
        for elem in root:
            if 'FullModel' in elem.tag:
                full_model = self._parse_full_model(elem)
                break
        
        # Находим все CIM объекты (все элементы с namespace CIM)
        # Игнорируем FullModel и другие служебные элементы
        for elem in root.iter():
            tag = elem.tag
            # Пропускаем служебные элементы
            if 'FullModel' in tag or 'Description' in tag or 'ExportMetadata' in tag:
                continue
            
            # Ищем элементы с namespace CIM
            if CIMObject.CIM_NAMESPACE in tag:
                obj_dict = self._xml_to_dict(elem)
                if obj_dict:
                    objects.append(obj_dict)
        
        return objects
    
    def _parse_full_model(self, elem: ET.Element) -> Dict[str, Any]:
        """Парсинг FullModel (метаданные экспорта)"""
        full_model = {
            'about': elem.get(f"{{{CIMObject.RDF_NAMESPACE}}}about", ""),
            'created': None,
            'version': None,
            'name': None
        }
        
        for child in elem:
            tag = child.tag
            if 'Model.created' in tag:
                full_model['created'] = child.text
            elif 'Model.version' in tag:
                full_model['version'] = child.text
            elif 'Model.name' in tag:
                full_model['name'] = child.text
        
        return full_model
    
    def _xml_to_dict(self, elem: ET.Element) -> Dict[str, Any]:
        """
        Преобразование XML элемента в словарь
        Поддерживает формат 
        """
        obj_dict = {}
        
        # Получаем mRID из атрибута about
        about = elem.get(f"{{{CIMObject.RDF_NAMESPACE}}}about", "")
        if about:
            # Извлекаем mRID из urn:uuid:... или #_...
            if about.startswith("urn:uuid:"):
                obj_dict["mRID"] = about.replace("urn:uuid:", "")
            elif about.startswith("#_"):
                obj_dict["mRID"] = about.replace("#_", "")
            else:
                obj_dict["mRID"] = about
        else:
            return {}  # Нет mRID - пропускаем
        
        # Получаем имя класса
        tag = elem.tag
        if CIMObject.CIM_NAMESPACE in tag:
            class_name = tag.replace(CIMObject.CIM_NAMESPACE, "").replace("{", "").replace("}", "")
            obj_dict["_class"] = class_name
        
        # Парсим свойства
        for child in elem:
            tag = child.tag
            # Обрабатываем только элементы с namespace CIM или без namespace
            if CIMObject.CIM_NAMESPACE in tag or not tag.startswith("{"):
                # Извлекаем имя свойства (может быть с префиксом, например cim:IdentifiedObject.name)
                prop_name = tag
                if CIMObject.CIM_NAMESPACE in tag:
                    prop_name = tag.replace(CIMObject.CIM_NAMESPACE, "").replace("{", "").replace("}", "")
                # Убираем префикс класса, если есть (например, IdentifiedObject.name -> name)
                if "." in prop_name:
                    prop_name = prop_name.split(".")[-1]
                
                # Проверяем на ссылку (rdf:resource)
                resource = child.get(f"{{{CIMObject.RDF_NAMESPACE}}}resource", None)
                if resource:
                    # Это ссылка на другой объект
                    if resource.startswith("urn:uuid:"):
                        mrid = resource.replace("urn:uuid:", "")
                    elif resource.startswith("#_"):
                        mrid = resource.replace("#_", "")
                    else:
                        mrid = resource
                    
                    # Если свойство уже есть (множественные ссылки), делаем список
                    if prop_name in obj_dict:
                        if not isinstance(obj_dict[prop_name], list):
                            obj_dict[prop_name] = [obj_dict[prop_name]]
                        obj_dict[prop_name].append({"mRID": mrid})
                    else:
                        obj_dict[prop_name] = {"mRID": mrid}
                elif child.text and child.text.strip():
                    # Простое значение
                    text = child.text.strip()
                    # Пытаемся преобразовать в число или boolean
                    if text.lower() == "true":
                        value = True
                    elif text.lower() == "false":
                        value = False
                    else:
                        try:
                            # Пытаемся преобразовать в число
                            if "." in text:
                                value = float(text)
                            else:
                                value = int(text)
                        except ValueError:
                            value = text
                    
                    # Если свойство уже есть (множественные значения), делаем список
                    if prop_name in obj_dict:
                        if not isinstance(obj_dict[prop_name], list):
                            obj_dict[prop_name] = [obj_dict[prop_name]]
                        obj_dict[prop_name].append(value)
                    else:
                        obj_dict[prop_name] = value
                elif len(child) > 0:
                    # Вложенный объект или список
                    nested = self._xml_to_dict(child)
                    if nested:  # Только если есть данные
                        if prop_name in obj_dict:
                            if not isinstance(obj_dict[prop_name], list):
                                obj_dict[prop_name] = [obj_dict[prop_name]]
                            obj_dict[prop_name].append(nested)
                        else:
                            obj_dict[prop_name] = nested
        
        return obj_dict

