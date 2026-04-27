"""
Экспорт/импорт CIM в формате XML (RDF/XML)
Соответствует стандартам IEC 61970-301 и IEC 61970-552
"""
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import List, Dict, Any, Optional
from .cim_base import CIMObject, CIMExporter, CIMImporter

# IEC 61970-552 Difference Model
DM_NAMESPACE = "http://iec.ch/TC57/61970-552/DifferenceModel/1#"
MD_NAMESPACE = "http://iec.ch/TC57/61970-552/ModelDescription/1#"
ME_EXTENSION_NS = "http://monitel.com/2014/schema-cim16#"
RF_EXTENSION_NS = "http://gost.ru/2019/schema-cim01#"
ITS_EXTENSION_NS = "http://intechs.by/2025/schema-cim16#"


class CIMXMLExporter(CIMExporter):
    """
    Экспорт CIM в XML формат (RDF/XML)
    Соответствует стандарту IEC 61970-552:2016
    """
    
    def export(
        self,
        objects: List[CIMObject],
        output_path: Optional[str] = None,
        *,
        wrap_as_difference_model: bool = True,
        model_description: str = "LEPM CIM export",
        model_version: str = "1.0",
        difference_model_comment: str = " ",
    ) -> str:
        """
        Экспорт объектов в CIM XML (RDF/XML формат)

        Формат соответствует:
        - IEC 61970-301 (CIM Base)
        - IEC 61970-552:2016 (mRID и обмен данными)

        При wrap_as_difference_model=True (по умолчанию) корень — dm:DifferenceModel с
        dm:forwardDifferences / dm:reverseDifferences (как в типовом профиле 552 diff).
        При False — классическая обёртка md:FullModel и объекты как прямые дочерние rdf:RDF.
        """
        md_namespace = MD_NAMESPACE
        me_namespace = ME_EXTENSION_NS
        rf_namespace = RF_EXTENSION_NS
        dm_namespace = DM_NAMESPACE

        ET.register_namespace("rdf", CIMObject.RDF_NAMESPACE)
        ET.register_namespace("cim", CIMObject.CIM_NAMESPACE)
        ET.register_namespace("md", md_namespace)
        ET.register_namespace("dm", dm_namespace)
        ET.register_namespace("me", me_namespace)
        ET.register_namespace("rf", rf_namespace)
        ET.register_namespace("cim17", "http://iec.ch/TC57/CIM100#")
        ET.register_namespace("rh", "http://rushydro.ru/2015/schema-cim16#")
        ET.register_namespace("so", "http://so-ups.ru/2015/schema-cim16#")
        ET.register_namespace("its", ITS_EXTENSION_NS)

        rdf = ET.Element(f"{{{CIMObject.RDF_NAMESPACE}}}RDF")

        if wrap_as_difference_model:
            diff_mrid = str(uuid.uuid4())
            dm_el = ET.SubElement(rdf, f"{{{dm_namespace}}}DifferenceModel")
            dm_el.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"#_{diff_mrid}")
            dm_el.set("comment", difference_model_comment)

            created_elem = ET.SubElement(dm_el, f"{{{md_namespace}}}Model.created")
            created_elem.text = datetime.now().isoformat() + "Z"

            desc_elem = ET.SubElement(dm_el, f"{{{md_namespace}}}Model.description")
            desc_elem.text = model_description

            ver_elem = ET.SubElement(dm_el, f"{{{md_namespace}}}Model.version")
            ver_elem.text = model_version

            name_elem = ET.SubElement(dm_el, f"{{{me_namespace}}}Model.name")
            name_elem.text = "CIM16"

            forward = ET.SubElement(dm_el, f"{{{dm_namespace}}}forwardDifferences")
            for obj in objects:
                forward.append(self._object_to_xml(obj))

            ET.SubElement(dm_el, f"{{{dm_namespace}}}reverseDifferences")
        else:
            full_model_id = f"_{datetime.now().strftime('%Y%m%d%H%M%S')}"
            full_model = ET.SubElement(rdf, f"{{{md_namespace}}}FullModel")
            full_model.set(f"{{{CIMObject.RDF_NAMESPACE}}}about", f"#{full_model_id}")

            created_elem = ET.SubElement(full_model, f"{{{md_namespace}}}Model.created")
            created_elem.text = datetime.now().isoformat() + "Z"

            version_elem = ET.SubElement(full_model, f"{{{md_namespace}}}Model.version")
            version_elem.text = model_version

            name_elem = ET.SubElement(full_model, f"{{{CIMObject.CIM_NAMESPACE}}}Model.name")
            name_elem.text = "CIM16"

            for obj in objects:
                rdf.append(self._object_to_xml(obj))

        xml_str = self._prettify_xml(rdf)
        if wrap_as_difference_model:
            xml_str = self._prepend_552_processing_instructions(xml_str)

        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(xml_str)

        return xml_str

    @staticmethod
    def _prepend_552_processing_instructions(xml_str: str) -> str:
        """Добавляет типовые PI после XML-декларации (как в FromPlatform / floatExporter)."""
        lines = xml_str.split("\n", 1)
        if len(lines) == 2 and lines[0].strip().startswith("<?xml"):
            return (
                lines[0]
                + "\n<?iec61970-552 version=\"2.0\"?>\n<?floatExporter 1?>\n"
                + lines[1]
            )
        return '<?iec61970-552 version="2.0"?>\n<?floatExporter 1?>\n' + xml_str
    
    def _object_to_xml(self, obj: CIMObject) -> ET.Element:
        """Преобразование CIM объекта в XML элемент"""
        cim_dict = obj.to_cim_dict()
        cim_class = obj.get_cim_class()
        me_namespace = ME_EXTENSION_NS
        rf_namespace = RF_EXTENSION_NS
        its_namespace = ITS_EXTENSION_NS

        # Поддержка классов с namespace-префиксами (me:, rf:, cim:, its:).
        class_ns = CIMObject.CIM_NAMESPACE
        class_name = cim_class
        if isinstance(cim_class, str):
            if cim_class.startswith("me:"):
                class_ns = me_namespace
                class_name = cim_class.split(":", 1)[1]
            elif cim_class.startswith("rdf:"):
                class_ns = CIMObject.RDF_NAMESPACE
                class_name = cim_class.split(":", 1)[1]
            elif cim_class.startswith("rf:"):
                class_ns = rf_namespace
                class_name = cim_class.split(":", 1)[1]
            elif cim_class.startswith("cim:"):
                class_ns = CIMObject.CIM_NAMESPACE
                class_name = cim_class.split(":", 1)[1]
            elif cim_class.startswith("its:"):
                class_ns = its_namespace
                class_name = cim_class.split(":", 1)[1]

        def _resource_value(ref: Dict[str, Any]) -> str:
            if "resource" in ref:
                return str(ref["resource"])
            return f"#_{ref['mRID']}"

        # Создаем элемент для объекта с префиксом cim:/me:
        obj_elem = ET.Element(f"{{{class_ns}}}{class_name}")
        obj_elem.set(
            f"{{{CIMObject.RDF_NAMESPACE}}}about",
            getattr(obj, "about_override", None) or f"#_{obj.mrid}",
        )
        
        def _ns_and_localname(prop_key: str) -> (str, str):
            # Поддержка расширений в namespace me: через префикс в ключе словаря.
            # Пример ключа: "me:IdentifiedObject.ParentObject"
            if prop_key.startswith("me:"):
                return me_namespace, prop_key.split(":", 1)[1]
            if prop_key.startswith("rf:"):
                return rf_namespace, prop_key.split(":", 1)[1]
            if prop_key.startswith("its:"):
                return its_namespace, prop_key.split(":", 1)[1]
            if prop_key.startswith("cim:"):
                return CIMObject.CIM_NAMESPACE, prop_key.split(":", 1)[1]
            return CIMObject.CIM_NAMESPACE, prop_key

        def _is_ref_dict(d: Any) -> bool:
            if not isinstance(d, dict):
                return False
            if "resource" in d and len(d.keys()) == 1:
                return True
            return "mRID" in d and all(k in {"mRID", "resource"} for k in d.keys())

        # Добавляем свойства объекта
        for key, value in cim_dict.items():
            if key == "mRID":  # mRID уже в атрибуте about
                continue

            ns_uri, localname = _ns_and_localname(key)

            # Список ссылок вида [{"mRID": "..."}] -> несколько элементов свойства с rdf:resource
            # Это нужно, чтобы получалось: <cim:Substation.VoltageLevels rdf:resource="#_..."/>
            if isinstance(value, list) and value and all(_is_ref_dict(it) for it in value):
                for item in value:
                    prop_elem = ET.SubElement(obj_elem, f"{{{ns_uri}}}{localname}")
                    prop_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", _resource_value(item))
                continue

            prop_elem = ET.SubElement(obj_elem, f"{{{ns_uri}}}{localname}")

            if isinstance(value, dict):
                # Вложенный объект как ссылка на другой CIM объект
                if _is_ref_dict(value):
                    prop_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", _resource_value(value))
                else:
                    nested = self._dict_to_xml(value, prop_elem)
            elif isinstance(value, list):
                # Список объектов или значений (случаи, когда элементы не только ссылки)
                for item in value:
                    if isinstance(item, dict):
                        if _is_ref_dict(item):
                            # Ссылка на объект, а не inline
                            item_elem = ET.SubElement(
                                prop_elem,
                                f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}"
                            )
                            item_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", _resource_value(item))
                        else:
                            item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            self._dict_to_xml(item, item_elem)
                    else:
                        item_elem = ET.SubElement(prop_elem, f"{{{CIMObject.CIM_NAMESPACE}}}value")
                        item_elem.text = str(item)
            elif value is not None:
                prop_elem.text = str(value)
        
        return obj_elem
    
    def _dict_to_xml(self, data: Dict[str, Any], parent: ET.Element) -> ET.Element:
        """Рекурсивное преобразование словаря в XML"""
        def _resource_value(ref: Dict[str, Any]) -> str:
            if "resource" in ref:
                return str(ref["resource"])
            return f"#_{ref['mRID']}"

        for key, value in data.items():
            if key == "mRID":
                continue
            elem = ET.SubElement(parent, f"{{{CIMObject.CIM_NAMESPACE}}}{key}")
            if isinstance(value, dict):
                if "mRID" in value or "resource" in value:
                    # Используем формат rdf:resource="#_mrid" 
                    elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", _resource_value(value))
                else:
                    self._dict_to_xml(value, elem)
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        if "mRID" in item or "resource" in item:
                            item_elem = ET.SubElement(elem, f"{{{CIMObject.CIM_NAMESPACE}}}{item.get('type', 'Object')}")
                            # Используем формат rdf:resource="#_mrid"
                            item_elem.set(f"{{{CIMObject.RDF_NAMESPACE}}}resource", _resource_value(item))
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
        """Форматирование XML для читаемости (без minidom — он давал некорректную вложенность dm:forward/reverse)."""
        try:
            if hasattr(ET, "indent"):
                ET.indent(elem, space="  ")
            rough_string = ET.tostring(elem, encoding="utf-8", xml_declaration=True)
            return rough_string.decode("utf-8")
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning("Ошибка при форматировании XML: %s", str(e))
            rough_string = ET.tostring(elem, encoding="utf-8", xml_declaration=True)
            return rough_string.decode("utf-8")


class CIMXMLImporter(CIMImporter):
    """
    Импорт CIM из XML формата (RDF/XML)
    Поддерживает формат FromPlatform_.xml, md:FullModel и dm:DifferenceModel.
    """

    _RESOURCE_NS = (
        CIMObject.CIM_NAMESPACE,
        ME_EXTENSION_NS,
        RF_EXTENSION_NS,
        ITS_EXTENSION_NS,
        "http://iec.ch/TC57/CIM100#",
    )
    
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """Импорт объектов из XML файла"""
        tree = ET.parse(file_path)
        root = tree.getroot()

        objects: List[Dict[str, Any]] = []

        # dm:DifferenceModel: ресурсы в forwardDifferences; при ошибочной выгрузке могут оказаться в reverseDifferences
        for elem in root:
            if elem.tag == f"{{{DM_NAMESPACE}}}DifferenceModel":
                seen_mrids: set = set()
                for child in elem:
                    if child.tag == f"{{{DM_NAMESPACE}}}forwardDifferences":
                        for obj_el in child:
                            obj_dict = self._xml_to_dict(obj_el)
                            if obj_dict:
                                obj_dict["_diff_section"] = "forward"
                                m = obj_dict.get("mRID")
                                if m and m in seen_mrids:
                                    continue
                                if m:
                                    seen_mrids.add(m)
                                objects.append(obj_dict)
                    elif child.tag == f"{{{DM_NAMESPACE}}}reverseDifferences":
                        for obj_el in child:
                            obj_dict = self._xml_to_dict(obj_el)
                            if obj_dict:
                                obj_dict["_diff_section"] = "reverse"
                                m = obj_dict.get("mRID")
                                if m and m in seen_mrids:
                                    continue
                                if m:
                                    seen_mrids.add(m)
                                objects.append(obj_dict)
                return objects

        # md:FullModel или плоский список под rdf:RDF
        for elem in root:
            if "FullModel" in elem.tag:
                self._parse_full_model(elem)
                continue
            if self._is_resource_element(elem):
                obj_dict = self._xml_to_dict(elem)
                if obj_dict:
                    objects.append(obj_dict)

        return objects

    def _is_resource_element(self, elem: ET.Element) -> bool:
        if not elem.tag or elem.tag.endswith("RDF"):
            return False
        if "FullModel" in elem.tag or "DifferenceModel" in elem.tag:
            return False
        about = elem.get(f"{{{CIMObject.RDF_NAMESPACE}}}about")
        return bool(about)

    def _tag_namespace(self, tag: str) -> Optional[str]:
        if tag.startswith("{") and "}" in tag:
            return tag[1 : tag.index("}")]
        return None
    
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
        
        # Имя класса (cim:, me:, rf:, its:, cim17:)
        tag = elem.tag
        ns = self._tag_namespace(tag)
        if ns and ns in self._RESOURCE_NS:
            local = tag.split("}", 1)[-1] if "}" in tag else tag
            obj_dict["_class"] = local
        
        # Парсим свойства (cim:, me:, rf:, its:, cim17:)
        for child in elem:
            tag = child.tag
            if not (
                CIMObject.CIM_NAMESPACE in tag
                or ME_EXTENSION_NS in tag
                or RF_EXTENSION_NS in tag
                or ITS_EXTENSION_NS in tag
                or "http://iec.ch/TC57/CIM100#" in tag
                or not tag.startswith("{")
            ):
                continue

            prop_name = tag
            for ns in (
                CIMObject.CIM_NAMESPACE,
                ME_EXTENSION_NS,
                RF_EXTENSION_NS,
                ITS_EXTENSION_NS,
                "http://iec.ch/TC57/CIM100#",
            ):
                if tag.startswith("{" + ns + "}"):
                    prop_name = tag.split("}", 1)[1]
                    break
            if "." in prop_name:
                prop_name = prop_name.split(".")[-1]

            # Проверяем на ссылку (rdf:resource)
            resource = child.get(f"{{{CIMObject.RDF_NAMESPACE}}}resource", None)
            if resource:
                if resource.startswith("urn:uuid:"):
                    mrid = resource.replace("urn:uuid:", "")
                elif resource.startswith("#_"):
                    mrid = resource.replace("#_", "")
                else:
                    mrid = resource

                if prop_name in obj_dict:
                    if not isinstance(obj_dict[prop_name], list):
                        obj_dict[prop_name] = [obj_dict[prop_name]]
                    obj_dict[prop_name].append({"mRID": mrid})
                else:
                    obj_dict[prop_name] = {"mRID": mrid}
            elif child.text and child.text.strip():
                text = child.text.strip()
                if text.lower() == "true":
                    value = True
                elif text.lower() == "false":
                    value = False
                else:
                    try:
                        if "." in text:
                            value = float(text)
                        else:
                            value = int(text)
                    except ValueError:
                        value = text

                if prop_name in obj_dict:
                    if not isinstance(obj_dict[prop_name], list):
                        obj_dict[prop_name] = [obj_dict[prop_name]]
                    obj_dict[prop_name].append(value)
                else:
                    obj_dict[prop_name] = value
            elif len(child) > 0:
                nested = self._xml_to_dict(child)
                if nested:
                    if prop_name in obj_dict:
                        if not isinstance(obj_dict[prop_name], list):
                            obj_dict[prop_name] = [obj_dict[prop_name]]
                        obj_dict[prop_name].append(nested)
                    else:
                        obj_dict[prop_name] = nested

        return obj_dict

