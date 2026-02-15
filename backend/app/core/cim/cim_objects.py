"""
CIM объекты для преобразования моделей БД в CIM формат
Соответствует стандартам IEC 61970-301 и IEC 61970-552
"""
from typing import Dict, Any, List, Optional
from .cim_base import CIMObject


class SubstationCIMObject(CIMObject):
    """CIM представление подстанции"""
    
    def __init__(self, mrid: str, name: str, voltage_levels: List[Any] = None, location: Optional[Dict] = None):
        super().__init__(mrid, name)
        self.voltage_levels = voltage_levels or []
        self.location = location
    
    def get_cim_class(self) -> str:
        return "Substation"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name
        }
        
        if self.voltage_levels:
            result["VoltageLevel"] = [vl.to_cim_dict() if hasattr(vl, 'to_cim_dict') else vl for vl in self.voltage_levels]
        
        if self.location:
            result["Location"] = self.location
        
        return result


class VoltageLevelCIMObject(CIMObject):
    """CIM представление уровня напряжения"""
    
    def __init__(self, mrid: str, name: str, nominal_voltage: float, base_voltage: Optional[Dict] = None):
        super().__init__(mrid, name)
        self.nominal_voltage = nominal_voltage
        self.base_voltage = base_voltage
    
    def get_cim_class(self) -> str:
        return "VoltageLevel"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name,
            "nominalVoltage": self.nominal_voltage
        }
        
        if self.base_voltage:
            result["BaseVoltage"] = self.base_voltage
        
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


class LocationCIMObject(CIMObject):
    """CIM представление местоположения"""
    
    def __init__(self, mrid: str, position_points: List[Dict] = None):
        super().__init__(mrid)
        self.position_points = position_points or []
    
    def get_cim_class(self) -> str:
        return "Location"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid
        }
        
        if self.position_points:
            result["PositionPoint"] = self.position_points
        
        return result


class PositionPointCIMObject(CIMObject):
    """CIM представление точки координат"""
    
    def __init__(self, mrid: str, x_position: float, y_position: float, z_position: Optional[float] = None):
        super().__init__(mrid)
        self.x_position = x_position
        self.y_position = y_position
        self.z_position = z_position
    
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
        
        return result


class PowerLineCIMObject(CIMObject):
    """CIM представление линии электропередачи"""
    
    def __init__(self, mrid: str, name: str, acline_segments: List[Any] = None, base_voltage: Optional[Dict] = None):
        super().__init__(mrid, name)
        self.acline_segments = acline_segments or []
        self.base_voltage = base_voltage
    
    def get_cim_class(self) -> str:
        return "Line"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name
        }
        
        if self.acline_segments:
            result["ACLineSegment"] = [
                seg.to_cim_dict() if hasattr(seg, 'to_cim_dict') else seg 
                for seg in self.acline_segments
            ]
        
        if self.base_voltage:
            result["BaseVoltage"] = self.base_voltage
        
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
        g: Optional[float] = None
    ):
        super().__init__(mrid, name)
        self.from_node = from_node
        self.to_node = to_node
        self.length = length
        self.r = r
        self.x = x
        self.b = b
        self.g = g
    
    def get_cim_class(self) -> str:
        return "ACLineSegment"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name
        }
        
        if self.from_node:
            result["ConnectivityNode"] = self.from_node
        
        if self.to_node:
            # Если уже есть ConnectivityNode, делаем массив
            if "ConnectivityNode" in result:
                if not isinstance(result["ConnectivityNode"], list):
                    result["ConnectivityNode"] = [result["ConnectivityNode"]]
                result["ConnectivityNode"].append(self.to_node)
            else:
                result["ConnectivityNode"] = self.to_node
        
        if self.length is not None:
            result["length"] = self.length
        
        if self.r is not None:
            result["r"] = self.r
        
        if self.x is not None:
            result["x"] = self.x
        
        if self.b is not None:
            result["b"] = self.b
        
        if self.g is not None:
            result["g"] = self.g
        
        return result


class ConnectivityNodeCIMObject(CIMObject):
    """CIM представление узла соединения (опоры)"""
    
    def __init__(self, mrid: str, name: str, location: Optional[Dict] = None):
        super().__init__(mrid, name)
        self.location = location
    
    def get_cim_class(self) -> str:
        return "ConnectivityNode"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name
        }
        
        if self.location:
            result["Location"] = self.location
        
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
        spans: List[Any] = None
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
    
    def get_cim_class(self) -> str:
        return "LineSection"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid,
            "name": self.name
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
        if self.b is not None:
            result["b"] = self.b
        if self.g is not None:
            result["g"] = self.g
        if self.total_length is not None:
            result["totalLength"] = self.total_length
        if self.wire_info:
            result["WireInfo"] = self.wire_info
        if self.spans:
            result["Span"] = [
                span.to_cim_dict() if hasattr(span, 'to_cim_dict') else span
                for span in self.spans
            ]
        
        return result


class SpanCIMObject(CIMObject):
    """CIM представление пролёта (соединение между двумя опорами)"""
    
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
        sequence_number: Optional[int] = None
    ):
        super().__init__(mrid, name)
        self.connectivity_node = connectivity_node
        self.sequence_number = sequence_number
    
    def get_cim_class(self) -> str:
        return "Terminal"
    
    def to_cim_dict(self) -> Dict[str, Any]:
        result = {
            "mRID": self.mrid
        }
        
        if self.name:
            result["name"] = self.name
        if self.connectivity_node:
            result["ConnectivityNode"] = self.connectivity_node
        if self.sequence_number is not None:
            result["sequenceNumber"] = self.sequence_number
        
        return result

