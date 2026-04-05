"""
Экспорт/импорт CIM в формате JSON
"""
import json
from datetime import datetime
from typing import List, Dict, Any, Optional
from .cim_base import CIMObject, CIMExporter, CIMImporter


class CIMJSONExporter(CIMExporter):
    """Экспорт CIM в JSON формат"""
    
    def export(self, objects: List[CIMObject], output_path: Optional[str] = None) -> str:
        """
        Экспорт объектов в JSON
        Формат соответствует CIM JSON representation
        """
        cim_data = {
            "version": "CIM16",
            "namespace": CIMObject.CIM_NAMESPACE,
            "exported_at": datetime.now().isoformat(),
            "objects": [obj.to_cim_dict() for obj in objects]
        }
        
        json_str = json.dumps(cim_data, indent=2, ensure_ascii=False)
        
        if output_path:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(json_str)
        
        return json_str


class CIMJSONImporter(CIMImporter):
    """Импорт CIM из JSON формата"""
    
    def import_from_file(self, file_path: str) -> List[Dict[str, Any]]:
        """Импорт объектов из JSON файла"""
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        return data.get("objects", [])

