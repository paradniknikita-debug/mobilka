"""
CIM объекты для преобразования моделей БД в CIM формат
Соответствует стандартам IEC 61970-301 и IEC 61970-552
"""
from typing import Dict, Any, List, Optional
from .cim_base import CIMObject


class RDFDescriptionCIMObject(CIMObject):
    """rdf:Description для внешних ссылок, уже существующих в системе."""

    def __init__(self, about_override: str, properties: Dict[str, Any]):
        super().__init__(mrid="", about_override=about_override)
        self.properties = properties

    def get_cim_class(self) -> str:
        return "rdf:Description"

    def to_cim_dict(self) -> Dict[str, Any]:
        return self.properties


class HyperGeoRegionCIMObject(CIMObject):
    """me:HyperGeoRegion - внешний контейнер географии."""

    def __init__(
        self,
        mrid: str,
        name: str,
        parent_object: Optional[Dict[str, str]] = None,
        child_objects: Optional[List[Dict[str, str]]] = None,
        sub_region_refs: Optional[List[Dict[str, str]]] = None,
    ):
        super().__init__(mrid, name)
        self.parent_object = parent_object
        self.child_objects = child_objects or []
        self.sub_region_refs = sub_region_refs or []

    def get_cim_class(self) -> str:
        return "me:HyperGeoRegion"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {"mRID": self.mrid}
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        if self.sub_region_refs:
            result["me:HyperGeoRegion.SubRegions"] = self.sub_region_refs
        return result


class GeographicalRegionCIMObject(CIMObject):
    """cim:GeographicalRegion — регион в географическом дереве."""

    def __init__(
        self,
        mrid: str,
        name: str,
        parent_object: Optional[Dict[str, str]] = None,
        child_objects: Optional[List[Dict[str, str]]] = None,
        hyper_region: Optional[Dict[str, str]] = None,
        region_refs: Optional[List[Dict[str, str]]] = None,
    ):
        super().__init__(mrid, name)
        self.parent_object = parent_object
        self.child_objects = child_objects or []
        self.hyper_region = hyper_region
        self.region_refs = region_refs or []

    def get_cim_class(self) -> str:
        return "GeographicalRegion"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {"mRID": self.mrid}
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        if self.hyper_region:
            result["GeographicalRegion.HyperRegion"] = self.hyper_region
        if self.region_refs:
            result["GeographicalRegion.Regions"] = self.region_refs
        return result


class SubGeographicalRegionCIMObject(CIMObject):
    """cim:SubGeographicalRegion — субрегион."""

    def __init__(
        self,
        mrid: str,
        name: str,
        parent_object: Optional[Dict[str, str]] = None,
        child_objects: Optional[List[Dict[str, str]]] = None,
        region: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.parent_object = parent_object
        self.child_objects = child_objects or []
        self.region = region

    def get_cim_class(self) -> str:
        return "SubGeographicalRegion"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {"mRID": self.mrid}
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        if self.region:
            result["SubGeographicalRegion.Region"] = self.region
        return result


class SubstationCIMObject(CIMObject):
    """CIM представление подстанции"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        voltage_levels: List[Any] = None,
        location: Optional[Dict] = None,
        parent_object: Optional[Dict[str, str]] = None,
        child_objects: Optional[List[Dict[str, str]]] = None,
        psr_type: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.voltage_levels = voltage_levels or []
        self.location = location
        self.parent_object = parent_object
        self.child_objects = child_objects or []
        self.psr_type = psr_type
    
    def get_cim_class(self) -> str:
        return "Substation"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        
        if self.voltage_levels:
            result["Substation.VoltageLevels"] = self.voltage_levels
        
        if self.location:
            result["PowerSystemResource.Location"] = self.location
        if self.psr_type:
            result["PowerSystemResource.PSRType"] = self.psr_type

        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        
        return result


class VoltageLevelCIMObject(CIMObject):
    """CIM представление уровня напряжения"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        nominal_voltage: float,
        base_voltage: Optional[Dict] = None,
        parent_object: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.nominal_voltage = nominal_voltage
        self.base_voltage = base_voltage
        self.parent_object = parent_object
    
    def get_cim_class(self) -> str:
        return "VoltageLevel"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name,
            "nominalVoltage": self.nominal_voltage
        }
        
        if self.base_voltage:
            result["VoltageLevel.BaseVoltage"] = self.base_voltage
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        
        return result


class BaseVoltageCIMObject(CIMObject):
    """CIM представление базового уровня напряжения"""
    
    def __init__(self, mrid: str, name: str, nominal_voltage: float):
        super().__init__(mrid, name)
        self.nominal_voltage = nominal_voltage
    
    def get_cim_class(self) -> str:
        return "BaseVoltage"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        return {
            "mRID": self.mrid,
            "name": self.name,
            "nominalVoltage": self.nominal_voltage
        }


class GenericNamedCIMObject(CIMObject):
    """Упрощённый CIM объект для справочников вроде PSRType/ControlArea."""

    def __init__(
        self,
        mrid: str,
        name: str,
        cim_class: str,
        extra_properties: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(mrid, name)
        self.cim_class = cim_class
        self.extra_properties = extra_properties or {}

    def get_cim_class(self) -> str:
        return self.cim_class

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        result.update(self.extra_properties)
        return result


class LocationCIMObject(CIMObject):
    """CIM представление местоположения"""
    
    def __init__(
        self,
        mrid: str,
        position_points: List[Dict] = None,
        parent_object: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid)
        self.position_points = position_points or []
        self.parent_object = parent_object
    
    def get_cim_class(self) -> str:
        return "Location"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid
        }
        
        if self.position_points:
            result["PositionPoint"] = self.position_points
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        
        return result


class PositionPointCIMObject(CIMObject):
    """CIM представление точки координат"""
    
    def __init__(
        self,
        mrid: str,
        x_position: float,
        y_position: float,
        z_position: Optional[float] = None,
        parent_object: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid)
        self.x_position = x_position
        self.y_position = y_position
        self.z_position = z_position
        self.parent_object = parent_object
    
    def get_cim_class(self) -> str:
        return "PositionPoint"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "xPosition": self.x_position,
            "yPosition": self.y_position
        }
        
        if self.z_position is not None:
            result["zPosition"] = self.z_position
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        
        return result


class PowerLineCIMObject(CIMObject):
    """CIM представление линии электропередачи"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        acline_segments: List[Any] = None,
        base_voltage: Optional[Dict] = None,
        parent_object: Optional[Dict] = None,
        extra_child_objects: List[Dict] = None,
        psr_type: Optional[Dict[str, str]] = None,
        region: Optional[Dict[str, str]] = None,
        connectivity_nodes: Optional[List[Dict[str, str]]] = None,
    ):
        super().__init__(mrid, name)
        self.acline_segments = acline_segments or []
        self.base_voltage = base_voltage
        self.parent_object = parent_object
        self.extra_child_objects = extra_child_objects or []
        self.psr_type = psr_type
        self.region = region
        self.connectivity_nodes = connectivity_nodes or []
    
    def get_cim_class(self) -> str:
        return "Line"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name

        # Иерархия: Line -> ACLineSegment + папка опор и др. только ссылками (отдельные ресурсы в forwardDifferences)
        if self.acline_segments or self.extra_child_objects:
            child_refs: List[Dict[str, str]] = []
            for seg in self.acline_segments:
                if isinstance(seg, dict) and "mRID" in seg:
                    child_refs.append({"mRID": seg["mRID"]})
                elif hasattr(seg, "mrid"):
                    child_refs.append({"mRID": getattr(seg, "mrid")})
            for child in self.extra_child_objects:
                if isinstance(child, dict) and "mRID" in child:
                    child_refs.append({"mRID": child["mRID"]})
            if child_refs:
                result["me:IdentifiedObject.ChildObjects"] = child_refs
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object

        if self.base_voltage:
            result["ConductingEquipment.BaseVoltage"] = self.base_voltage
        if self.psr_type:
            result["PowerSystemResource.PSRType"] = self.psr_type
        if self.region:
            result["Line.Region"] = self.region
        if self.connectivity_nodes:
            result["ConnectivityNodeContainer.ConnectivityNodes"] = self.connectivity_nodes
        
        return result


class AClineSegmentCIMObject(CIMObject):
    """CIM представление сегмента линии переменного тока"""

    def __init__(
        self,
        mrid: str,
        name: str,
        from_node: Optional[Dict] = None,
        to_node: Optional[Dict] = None,
        length: Optional[float] = None,
        r: Optional[float] = None,
        x: Optional[float] = None,
        b: Optional[float] = None,
        g: Optional[float] = None,
        parent_object: Optional[Dict] = None,
        description: Optional[str] = None,
        child_object_refs: Optional[List[Dict[str, str]]] = None,
        series_section_refs: Optional[List[Dict[str, str]]] = None,
        terminal_refs: Optional[List[Dict[str, str]]] = None,
        r0: Optional[float] = None,
        x0: Optional[float] = None,
        bch: Optional[float] = None,
        b0ch: Optional[float] = None,
        gch: Optional[float] = None,
        g0ch: Optional[float] = None,
        model_detail: Optional[str] = None,
        sections_blob: Optional[str] = None,
        energisable_with_disconnector: Optional[bool] = None,
        i_max_summer: Optional[str] = None,
        i_max_winter: Optional[str] = None,
        short_circuit_end_temperature: Optional[str] = None,
        wire_splitting_factor: Optional[str] = None,
        normally_in_service: Optional[bool] = True,
        equipment_container: Optional[Dict[str, str]] = None,
        base_voltage: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.from_node = from_node
        self.to_node = to_node
        self.length = length
        self.r = r
        self.x = x
        self.b = b
        self.g = g
        self.parent_object = parent_object
        self.description = description
        self.child_object_refs = child_object_refs or []
        self.series_section_refs = series_section_refs or []
        self.terminal_refs = terminal_refs or []
        self.r0 = r0
        self.x0 = x0
        self.bch = bch
        self.b0ch = b0ch
        self.gch = gch
        self.g0ch = g0ch
        self.model_detail = model_detail
        self.sections_blob = sections_blob
        self.energisable_with_disconnector = energisable_with_disconnector
        self.i_max_summer = i_max_summer
        self.i_max_winter = i_max_winter
        self.short_circuit_end_temperature = short_circuit_end_temperature
        self.wire_splitting_factor = wire_splitting_factor
        self.normally_in_service = normally_in_service
        self.equipment_container = equipment_container
        self.base_voltage = base_voltage

    def get_cim_class(self) -> str:
        return "ACLineSegment"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.description:
            result["IdentifiedObject.description"] = self.description

        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_object_refs:
            result["me:IdentifiedObject.ChildObjects"] = self.child_object_refs
        if self.equipment_container:
            result["Equipment.EquipmentContainer"] = self.equipment_container

        if self.from_node:
            result["Terminal.ConnectivityNode"] = self.from_node

        if self.to_node:
            if "Terminal.ConnectivityNode" in result:
                if not isinstance(result["Terminal.ConnectivityNode"], list):
                    result["Terminal.ConnectivityNode"] = [result["Terminal.ConnectivityNode"]]
                result["Terminal.ConnectivityNode"].append(self.to_node)
            else:
                result["Terminal.ConnectivityNode"] = self.to_node

        if self.length is not None:
            result["Conductor.length"] = self.length

        if self.r is not None:
            result["ACLineSegment.r"] = self.r
        if self.x is not None:
            result["ACLineSegment.x"] = self.x
        if self.r0 is not None:
            result["ACLineSegment.r0"] = self.r0
        if self.x0 is not None:
            result["ACLineSegment.x0"] = self.x0
        if self.bch is not None:
            result["ACLineSegment.bch"] = self.bch
        if self.b0ch is not None:
            result["ACLineSegment.b0ch"] = self.b0ch
        if self.gch is not None:
            result["ACLineSegment.gch"] = self.gch
        if self.g0ch is not None:
            result["ACLineSegment.g0ch"] = self.g0ch
        if self.b is not None:
            result["b"] = self.b
        if self.g is not None:
            result["g"] = self.g

        if self.model_detail is not None:
            result["me:ACLineSegment.modelDetail"] = str(self.model_detail)
        if self.sections_blob is not None:
            result["me:ACLineSegment.sections"] = self.sections_blob
        if self.energisable_with_disconnector is not None:
            result["energisableWithDisconnector"] = self.energisable_with_disconnector
        if self.i_max_summer is not None:
            result["iMaxSummer"] = self.i_max_summer
        if self.i_max_winter is not None:
            result["iMaxWinter"] = self.i_max_winter
        if self.short_circuit_end_temperature is not None:
            result["shortCircuitEndTemperature"] = self.short_circuit_end_temperature
        if self.wire_splitting_factor is not None:
            result["wireSplittingFactor"] = self.wire_splitting_factor
        if self.normally_in_service is not None:
            result["Equipment.normallyInService"] = self.normally_in_service
        if self.base_voltage:
            result["ConductingEquipment.BaseVoltage"] = self.base_voltage

        if self.series_section_refs:
            result["ACLineSeriesSection"] = self.series_section_refs
        if self.terminal_refs:
            result["ConductingEquipment.Terminals"] = self.terminal_refs

        return result


class ConnectivityNodeCIMObject(CIMObject):
    """CIM представление узла соединения (опоры)"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        location: Optional[Dict] = None,
        parent_object: Optional[Dict[str, str]] = None,
        terminal_refs: Optional[List[Dict[str, str]]] = None,
        connectivity_node_container: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.location = location
        self.parent_object = parent_object
        self.terminal_refs = terminal_refs or []
        self.connectivity_node_container = connectivity_node_container
    
    def get_cim_class(self) -> str:
        return "ConnectivityNode"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        
        if self.location:
            result["PowerSystemResource.Location"] = self.location
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.terminal_refs:
            result["ConnectivityNode.Terminals"] = self.terminal_refs
        if self.connectivity_node_container:
            result["ConnectivityNode.ConnectivityNodeContainer"] = self.connectivity_node_container
        
        return result


class LineSectionCIMObject(CIMObject):
    """CIM представление секции линии (группа пролётов с одинаковыми параметрами провода)"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        conductor_type: Optional[str] = None,
        conductor_material: Optional[str] = None,
        conductor_section: Optional[str] = None,
        r: Optional[float] = None,
        x: Optional[float] = None,
        b: Optional[float] = None,
        g: Optional[float] = None,
        total_length: Optional[float] = None,
        wire_info: Optional[Dict] = None,
        spans: List[Any] = None,
        parent_object: Optional[Dict] = None,
        section_number: Optional[int] = None,
        r0: Optional[float] = None,
        x0: Optional[float] = None,
        bch: Optional[float] = None,
        b0ch: Optional[float] = None,
        gch: Optional[float] = None,
        g0ch: Optional[float] = None,
        is_cable: Optional[bool] = None,
        short_circuit_end_temperature: Optional[str] = None,
        t_th: Optional[str] = None,
        section_type: Optional[str] = None,
    ):
        super().__init__(mrid, name)
        self.conductor_type = conductor_type
        self.conductor_material = conductor_material
        self.conductor_section = conductor_section
        self.r = r
        self.x = x
        self.b = b
        self.g = g
        self.total_length = total_length
        self.wire_info = wire_info
        self.spans = spans or []
        self.parent_object = parent_object
        self.section_number = section_number
        self.r0 = r0
        self.x0 = x0
        self.bch = bch
        self.b0ch = b0ch
        self.gch = gch
        self.g0ch = g0ch
        self.is_cable = is_cable
        self.short_circuit_end_temperature = short_circuit_end_temperature
        self.t_th = t_th
        self.section_type = section_type
    
    def get_cim_class(self) -> str:
        # В профиле FromPlatform секции пролёта представлены как ACLineSeriesSection
        return "rf:ACLineSeriesSection"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
            "IdentifiedObject.name": self.name,
        }
        
        if self.conductor_type:
            result["conductorType"] = self.conductor_type
        if self.conductor_material:
            result["conductorMaterial"] = self.conductor_material
        if self.conductor_section:
            result["conductorSection"] = self.conductor_section
        if self.r is not None:
            result["r"] = self.r
        if self.x is not None:
            result["x"] = self.x
        if self.r0 is not None:
            result["r0"] = self.r0
        if self.x0 is not None:
            result["x0"] = self.x0
        if self.b is not None:
            result["b"] = self.b
        if self.bch is not None:
            result["bch"] = self.bch
        if self.b0ch is not None:
            result["b0ch"] = self.b0ch
        if self.g is not None:
            result["g"] = self.g
        if self.gch is not None:
            result["gch"] = self.gch
        if self.g0ch is not None:
            result["g0ch"] = self.g0ch
        if self.total_length is not None:
            result["length"] = self.total_length
            result["distance"] = self.total_length
        if self.section_number is not None:
            result["sectionNumber"] = self.section_number
        if self.is_cable is not None:
            result["isCable"] = self.is_cable
        if self.short_circuit_end_temperature is not None:
            result["ShortCircuitEndTemperature"] = self.short_circuit_end_temperature
        if self.t_th is not None:
            result["TTh"] = self.t_th
        if self.section_type is not None:
            result["type"] = self.section_type
        if self.wire_info:
            result["WireInfo"] = self.wire_info
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.spans:
            result["me:IdentifiedObject.ChildObjects"] = [
                {"mRID": (s["mRID"] if isinstance(s, dict) else getattr(s, "mrid", None))}
                for s in self.spans
                if (isinstance(s, dict) and s.get("mRID")) or hasattr(s, "mrid")
            ]
        
        return result


class SpanCIMObject(CIMObject):
    """Deprecated: оставлено для обратной совместимости (используйте LineSpanCIMObject)."""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        length: float,
        from_node: Optional[Dict] = None,
        to_node: Optional[Dict] = None,
        tension: Optional[float] = None,
        sag: Optional[float] = None,
        conductor_type: Optional[str] = None,
        conductor_material: Optional[str] = None,
        conductor_section: Optional[str] = None
    ):
        super().__init__(mrid, name)
        self.length = length
        self.from_node = from_node
        self.to_node = to_node
        self.tension = tension
        self.sag = sag
        self.conductor_type = conductor_type
        self.conductor_material = conductor_material
        self.conductor_section = conductor_section
    
    def get_cim_class(self) -> str:
        return "Span"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name,
            "length": self.length
        }
        
        if self.from_node:
            result["fromConnectivityNode"] = self.from_node
        if self.to_node:
            result["toConnectivityNode"] = self.to_node
        if self.tension is not None:
            result["tension"] = self.tension
        if self.sag is not None:
            result["sag"] = self.sag
        if self.conductor_type:
            result["conductorType"] = self.conductor_type
        if self.conductor_material:
            result["conductorMaterial"] = self.conductor_material
        if self.conductor_section:
            result["conductorSection"] = self.conductor_section
        
        return result


class LineSpanCIMObject(CIMObject):
    """
    Профиль its:LineSpan (intechs) / cim:LineSpan — пролёт с привязкой к сегменту и опорам.
    """

    def __init__(
        self,
        mrid: str,
        name: str,
        length: float,
        from_node: Optional[Dict] = None,
        to_node: Optional[Dict] = None,
        description: Optional[str] = None,
        a_wire_type_name: Optional[str] = None,
        b_wire_type_name: Optional[str] = None,
        c_wire_type_name: Optional[str] = None,
        is_from_substation: Optional[bool] = None,
        is_to_substation: Optional[bool] = None,
        parent_object: Optional[Dict] = None,
        start_tower: Optional[Dict[str, str]] = None,
        end_tower: Optional[Dict[str, str]] = None,
        line_ref: Optional[Dict[str, str]] = None,
        acline_segment_ref: Optional[Dict[str, str]] = None,
        switches: Optional[List[Dict[str, str]]] = None,
        child_object_refs: Optional[List[Dict[str, str]]] = None,
    ):
        super().__init__(mrid, name)
        self.length = length
        self.from_node = from_node
        self.to_node = to_node
        self.description = description
        self.a_wire_type_name = a_wire_type_name
        self.b_wire_type_name = b_wire_type_name
        self.c_wire_type_name = c_wire_type_name
        self.is_from_substation = is_from_substation
        self.is_to_substation = is_to_substation
        self.parent_object = parent_object
        self.start_tower = start_tower
        self.end_tower = end_tower
        self.line_ref = line_ref
        self.acline_segment_ref = acline_segment_ref
        self.switches = switches or []
        self.child_object_refs = child_object_refs or []

    def get_cim_class(self) -> str:
        return "its:LineSpan"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
        }

        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.description:
            result["IdentifiedObject.description"] = self.description

        result["length"] = self.length

        if self.a_wire_type_name:
            result["AWireTypeName"] = self.a_wire_type_name
        if self.b_wire_type_name:
            result["BWireTypeName"] = self.b_wire_type_name
        if self.c_wire_type_name:
            result["CWireTypeName"] = self.c_wire_type_name

        if self.is_from_substation is not None:
            result["isFromSubstation"] = self.is_from_substation
        if self.is_to_substation is not None:
            result["isToSubstation"] = self.is_to_substation
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_object_refs:
            result["me:IdentifiedObject.ChildObjects"] = self.child_object_refs

        if self.start_tower:
            result["its:LineSpan.StartTower"] = self.start_tower
        if self.end_tower:
            result["its:LineSpan.EndTower"] = self.end_tower
        if self.line_ref:
            result["its:LineSpan.Line"] = self.line_ref
        if self.acline_segment_ref:
            result["its:LineSpan.ACLineSegment"] = self.acline_segment_ref
        if self.switches:
            result["its:LineSpan.Switches"] = self.switches

        if self.from_node:
            result["fromConnectivityNode"] = self.from_node
        if self.to_node:
            result["toConnectivityNode"] = self.to_node

        return result


class WireInfoCIMObject(CIMObject):
    """CIM представление информации о проводе"""
    
    def __init__(
        self,
        mrid: str,
        name: str,
        material: str,
        section: float,
        r: Optional[float] = None,
        x: Optional[float] = None,
        b: Optional[float] = None,
        g: Optional[float] = None,
        diameter: Optional[float] = None,
        breaking_load: Optional[float] = None,
        weight_per_length: Optional[float] = None
    ):
        super().__init__(mrid, name)
        self.material = material
        self.section = section
        self.r = r
        self.x = x
        self.b = b
        self.g = g
        self.diameter = diameter
        self.breaking_load = breaking_load
        self.weight_per_length = weight_per_length
    
    def get_cim_class(self) -> str:
        return "WireInfo"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name,
            "material": self.material,
            "section": self.section
        }
        
        if self.r is not None:
            result["r"] = self.r
        if self.x is not None:
            result["x"] = self.x
        if self.b is not None:
            result["b"] = self.b
        if self.g is not None:
            result["g"] = self.g
        if self.diameter is not None:
            result["diameter"] = self.diameter
        if self.breaking_load is not None:
            result["breakingLoad"] = self.breaking_load
        if self.weight_per_length is not None:
            result["weightPerLength"] = self.weight_per_length
        
        return result


class TerminalCIMObject(CIMObject):
    """CIM представление терминала (точка подключения оборудования)"""
    
    def __init__(
        self,
        mrid: str,
        name: Optional[str] = None,
        connectivity_node: Optional[Dict] = None,
        conducting_equipment: Optional[Dict] = None,
        sequence_number: Optional[int] = None,
        parent_object: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.connectivity_node = connectivity_node
        self.conducting_equipment = conducting_equipment
        self.sequence_number = sequence_number
        self.parent_object = parent_object
    
    def get_cim_class(self) -> str:
        return "Terminal"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid
        }
        
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.connectivity_node:
            result["Terminal.ConnectivityNode"] = self.connectivity_node
        if self.conducting_equipment:
            result["Terminal.ConductingEquipment"] = self.conducting_equipment
        if self.sequence_number is not None:
            result["ACDCTerminal.sequenceNumber"] = self.sequence_number
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        
        return result


class ConductingEquipmentCIMObject(CIMObject):
    """CIM представление проводящего оборудования (например разъединители, ЗН и т.п.)"""

    def __init__(
        self,
        mrid: str,
        name: str,
        equipment_type: Optional[str] = None,
        location: Optional[Dict] = None,
        normal_in_service: Optional[bool] = None,
        parent_object: Optional[Dict[str, str]] = None,
        equipment_container: Optional[Dict[str, str]] = None,
        child_object_refs: Optional[List[Dict[str, str]]] = None,
        terminal_refs: Optional[List[Dict[str, str]]] = None,
        base_voltage: Optional[Dict[str, str]] = None,
        psr_type: Optional[Dict[str, str]] = None,
        control_area: Optional[Dict[str, str]] = None,
        cim_class: str = "ConductingEquipment",
        defect_note: Optional[str] = None,
        criticality: Optional[str] = None,
    ):
        super().__init__(mrid, name)
        self.equipment_type = equipment_type
        self.location = location
        self.normal_in_service = normal_in_service
        self.parent_object = parent_object
        self.equipment_container = equipment_container
        self.child_object_refs = child_object_refs or []
        self.terminal_refs = terminal_refs or []
        self.base_voltage = base_voltage
        self.psr_type = psr_type
        self.control_area = control_area
        self.cim_class = cim_class
        self.defect_note = defect_note
        self.criticality = criticality

    def get_cim_class(self) -> str:
        return self.cim_class

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
            "name": self.name,
        }
        if self.equipment_type:
            # CIM свойство может называться по-разному в разных профилях,
            # но для ручной выгрузки нам важен сам факт присутствия equipment_type.
            result["equipmentType"] = self.equipment_type
        if self.location:
            # ConductingEquipment наследует PowerSystemResource, поэтому Location должно писаться как
            # PowerSystemResource.Location (а не просто Location).
            result["PowerSystemResource.Location"] = self.location
        if self.normal_in_service is not None:
            result["Equipment.normallyInService"] = self.normal_in_service
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_object_refs:
            result["me:IdentifiedObject.ChildObjects"] = self.child_object_refs
        if self.equipment_container:
            result["Equipment.EquipmentContainer"] = self.equipment_container
        if self.terminal_refs:
            result["ConductingEquipment.Terminals"] = self.terminal_refs
        if self.base_voltage:
            result["ConductingEquipment.BaseVoltage"] = self.base_voltage
        if self.psr_type:
            result["PowerSystemResource.PSRType"] = self.psr_type
        if self.control_area:
            result["me:ConductingEquipment.ControlArea"] = self.control_area
        if self.defect_note:
            result["me:Equipment.defectDescription"] = self.defect_note
        if self.criticality:
            result["me:Equipment.defectCriticality"] = self.criticality
        return result


class FolderCIMObject(CIMObject):
    """Monitel extension: me:Folder с дочерними объектами."""

    def __init__(
        self,
        mrid: str,
        name: str,
        child_objects: Optional[List[Dict[str, str]]] = None,
        creating_node: Optional[Dict[str, str]] = None,
        parent_object: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.child_objects = child_objects or []
        self.creating_node = creating_node
        self.parent_object = parent_object

    def get_cim_class(self) -> str:
        return "me:Folder"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.creating_node:
            result["me:Folder.CreatingNode"] = self.creating_node
        return result


class PoleCIMObject(CIMObject):
    """CIM Pole с me:-ссылками на иерархию."""

    def __init__(
        self,
        mrid: str,
        name: str,
        location: Optional[Dict[str, str]] = None,
        parent_object: Optional[Dict[str, str]] = None,
        child_objects: Optional[List[Dict[str, str]]] = None,
        pole_type: Optional[str] = None,
        material: Optional[str] = None,
        height: Optional[float] = None,
        department_role: Optional[Dict[str, str]] = None,
        asset_power_system_resource: Optional[Dict[str, str]] = None,
    ):
        super().__init__(mrid, name)
        self.location = location
        self.parent_object = parent_object
        self.child_objects = child_objects or []
        self.pole_type = pole_type
        self.material = material
        self.height = height
        self.department_role = department_role
        self.asset_power_system_resource = asset_power_system_resource

    def get_cim_class(self) -> str:
        return "cim:Pole"

    def to_cim_dict(self) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "mRID": self.mrid,
        }
        if self.name:
            result["IdentifiedObject.name"] = self.name
        if self.location:
            result["PowerSystemResource.Location"] = self.location
        if self.parent_object:
            result["me:IdentifiedObject.ParentObject"] = self.parent_object
        if self.child_objects:
            result["me:IdentifiedObject.ChildObjects"] = self.child_objects
        if self.department_role:
            result["me:IdentifiedObject.DepartmentRoles"] = self.department_role
        if self.pole_type:
            result["cim:Asset.type"] = self.pole_type
        if self.material:
            result["me:Pole.material"] = self.material
        if self.height is not None:
            result["me:Pole.height"] = self.height
        if self.asset_power_system_resource:
            result["cim:Asset.PowerSystemResources"] = self.asset_power_system_resource
        return result

