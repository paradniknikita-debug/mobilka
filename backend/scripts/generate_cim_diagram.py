"""
Скрипт для генерации UML диаграммы классов CIMpy и их зависимостей
Генерирует PlantUML и Graphviz диаграммы
"""
import os
import sys
from pathlib import Path

# Добавляем путь к проекту
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    import cimpy
    CIMPY_AVAILABLE = True
except ImportError:
    CIMPY_AVAILABLE = False
    print("⚠️ CIMpy не установлен. Установите: pip install cimpy")
    print("Генерирую диаграмму на основе наших моделей...")

def generate_plantuml_diagram():
    """Генерация PlantUML диаграммы"""
    
    diagram = """@startuml CIM_Model_Classes
!theme plain
skinparam classAttributeIconSize 0
skinparam linetype ortho

title CIM Model Classes and Relationships

' Основные классы CIM
package "CIM Base Classes" {
    class IdentifiedObject {
        +mRID: String
        +name: String
        +description: String
    }
    
    class PowerSystemResource {
        +aliasName: String
    }
    
    class Equipment {
        +aggregate: Boolean
        +normallyInService: Boolean
    }
    
    class ConductingEquipment {
        +phases: PhaseCode
    }
    
    class Terminal {
        +sequenceNumber: Integer
        +connected: Boolean
    }
    
    class ConnectivityNode {
        +description: String
    }
}

package "Location Classes" {
    class Location {
        +mainAddress: String
        +telephoneNumber: String
        +electronicAddress: String
    }
    
    class PositionPoint {
        +xPosition: Float
        +yPosition: Float
        +zPosition: Float
        +sequenceNumber: Integer
    }
}

package "Voltage Classes" {
    class BaseVoltage {
        +nominalVoltage: Float
    }
    
    class VoltageLevel {
        +highVoltageLimit: Float
        +lowVoltageLimit: Float
    }
}

package "Substation Classes" {
    class Substation {
        +region: String
    }
    
    class Bay {
        +bayType: String
    }
    
    class BusbarSection {
        +ipMax: Float
    }
}

package "Line Classes" {
    class Line {
        +region: String
    }
    
    class ACLineSegment {
        +r: Float
        +x: Float
        +b: Float
        +g: Float
        +length: Float
        +r0: Float
        +x0: Float
        +b0: Float
        +g0: Float
    }
    
    class Conductor {
        +length: Float
    }
}

package "Wire Info Classes" {
    class WireInfo {
        +material: String
        +section: Float
        +r: Float
        +x: Float
        +b: Float
        +g: Float
        +ratedCurrent: Float
        +breakingLoad: Float
    }
}

' Наследование
IdentifiedObject <|-- PowerSystemResource
IdentifiedObject <|-- Location
IdentifiedObject <|-- BaseVoltage
IdentifiedObject <|-- PositionPoint
PowerSystemResource <|-- Equipment
PowerSystemResource <|-- ConnectivityNode
PowerSystemResource <|-- Terminal
Equipment <|-- ConductingEquipment
Equipment <|-- Line
ConductingEquipment <|-- ACLineSegment
ConductingEquipment <|-- Conductor
ConductingEquipment <|-- BusbarSection
PowerSystemResource <|-- Substation
PowerSystemResource <|-- VoltageLevel
PowerSystemResource <|-- Bay

' Связи (Composition/Aggregation)
Location "1" *-- "0..*" PositionPoint : contains
Substation "1" *-- "0..*" VoltageLevel : contains
VoltageLevel "1" *-- "0..*" Bay : contains
Bay "1" *-- "0..*" ConductingEquipment : contains
Line "1" *-- "0..*" ACLineSegment : contains

' Связи (Association)
Substation "1" --> "0..1" Location : located at
VoltageLevel "1" --> "0..1" BaseVoltage : uses
ACLineSegment "1" --> "0..1" WireInfo : uses
ConductingEquipment "1" --> "0..*" Terminal : has
Terminal "1" --> "0..1" ConnectivityNode : connects to
ACLineSegment "1" --> "0..1" ConnectivityNode : from
ACLineSegment "1" --> "0..1" ConnectivityNode : to

note right of Location
  Географическое местоположение
  объекта (IEC 61970-301)
end note

note right of BaseVoltage
  Базовый уровень напряжения
  (IEC 61970-301)
end note

note right of WireInfo
  Характеристики провода
  (IEC 61970-301)
end note

@enduml
"""
    
    output_path = Path(__file__).parent.parent / "docs" / "cim_model_diagram.puml"
    output_path.parent.mkdir(exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(diagram)
    
    print(f"✅ PlantUML диаграмма создана: {output_path}")
    print(f"   Откройте на https://www.plantuml.com/plantuml/uml/ или используйте PlantUML plugin в IDE")
    
    return output_path


def generate_graphviz_diagram():
    """Генерация Graphviz диаграммы"""
    
    try:
        from graphviz import Digraph
        GRAPHVIZ_AVAILABLE = True
    except ImportError:
        GRAPHVIZ_AVAILABLE = False
        print("⚠️ Graphviz не установлен. Установите: pip install graphviz")
        return None
    
    dot = Digraph(comment='CIM Model Classes', format='png')
    dot.attr(rankdir='TB')
    dot.attr('node', shape='box', style='rounded')
    
    # Основные классы
    dot.node('IdentifiedObject', 'IdentifiedObject\n+mRID\n+name')
    dot.node('PowerSystemResource', 'PowerSystemResource\n+aliasName')
    dot.node('Equipment', 'Equipment\n+normallyInService')
    dot.node('ConductingEquipment', 'ConductingEquipment\n+phases')
    
    # Location
    dot.node('Location', 'Location\n+mainAddress')
    dot.node('PositionPoint', 'PositionPoint\n+xPosition\n+yPosition')
    
    # Voltage
    dot.node('BaseVoltage', 'BaseVoltage\n+nominalVoltage')
    dot.node('VoltageLevel', 'VoltageLevel\n+highVoltageLimit')
    
    # Substation
    dot.node('Substation', 'Substation\n+region')
    dot.node('Bay', 'Bay\n+bayType')
    dot.node('BusbarSection', 'BusbarSection\n+ipMax')
    
    # Line
    dot.node('Line', 'Line\n+region')
    dot.node('ACLineSegment', 'ACLineSegment\n+r, x, b, g\n+length')
    dot.node('Conductor', 'Conductor\n+length')
    
    # Wire Info
    dot.node('WireInfo', 'WireInfo\n+material\n+section\n+r, x, b, g')
    
    # Connectivity
    dot.node('ConnectivityNode', 'ConnectivityNode\n+description')
    dot.node('Terminal', 'Terminal\n+sequenceNumber')
    
    # Наследование
    dot.edge('IdentifiedObject', 'PowerSystemResource', label='extends', style='solid')
    dot.edge('IdentifiedObject', 'Location', label='extends', style='solid')
    dot.edge('IdentifiedObject', 'BaseVoltage', label='extends', style='solid')
    dot.edge('PowerSystemResource', 'Equipment', label='extends', style='solid')
    dot.edge('PowerSystemResource', 'ConnectivityNode', label='extends', style='solid')
    dot.edge('Equipment', 'ConductingEquipment', label='extends', style='solid')
    dot.edge('Equipment', 'Line', label='extends', style='solid')
    dot.edge('ConductingEquipment', 'ACLineSegment', label='extends', style='solid')
    dot.edge('ConductingEquipment', 'BusbarSection', label='extends', style='solid')
    dot.edge('PowerSystemResource', 'Substation', label='extends', style='solid')
    dot.edge('PowerSystemResource', 'VoltageLevel', label='extends', style='solid')
    
    # Связи
    dot.edge('Location', 'PositionPoint', label='1..*', style='dashed', color='blue')
    dot.edge('Substation', 'Location', label='located at', style='dashed', color='green')
    dot.edge('VoltageLevel', 'BaseVoltage', label='uses', style='dashed', color='green')
    dot.edge('Substation', 'VoltageLevel', label='contains', style='dashed', color='red')
    dot.edge('Line', 'ACLineSegment', label='contains', style='dashed', color='red')
    dot.edge('ACLineSegment', 'WireInfo', label='uses', style='dashed', color='green')
    dot.edge('ACLineSegment', 'ConnectivityNode', label='from/to', style='dashed', color='orange')
    dot.edge('ConductingEquipment', 'Terminal', label='has', style='dashed', color='purple')
    dot.edge('Terminal', 'ConnectivityNode', label='connects', style='dashed', color='purple')
    
    output_path = Path(__file__).parent.parent / "docs" / "cim_model_diagram"
    dot.render(output_path, format='png', cleanup=True)
    
    print(f"✅ Graphviz диаграмма создана: {output_path}.png")
    
    return output_path


def analyze_cimpy_classes():
    """Анализ классов CIMpy и генерация детальной диаграммы"""
    
    if not CIMPY_AVAILABLE:
        return None
    
    try:
        from cimpy.cgmes_v2_4_15 import set_of_resources
        
        classes_info = []
        
        # Получаем все классы из set_of_resources
        for attr_name in dir(set_of_resources):
            if not attr_name.startswith('_'):
                attr = getattr(set_of_resources, attr_name)
                if isinstance(attr, type):
                    classes_info.append({
                        'name': attr_name,
                        'class': attr,
                        'module': attr.__module__ if hasattr(attr, '__module__') else None
                    })
        
        print(f"Найдено классов CIMpy: {len(classes_info)}")
        
        # Генерируем детальную диаграмму
        diagram = """@startuml CIMpy_Detailed_Classes
!theme plain
title CIMpy Classes (cgmes_v2_4_15)

"""
        
        # Группируем по пакетам
        packages = {}
        for info in sorted(classes_info, key=lambda x: x['name']):
            # Определяем пакет по имени класса
            if 'Location' in info['name'] or 'Position' in info['name']:
                pkg = 'Location'
            elif 'Voltage' in info['name']:
                pkg = 'Voltage'
            elif 'Substation' in info['name'] or 'Bay' in info['name'] or 'Busbar' in info['name']:
                pkg = 'Substation'
            elif 'Line' in info['name'] or 'Segment' in info['name'] or 'Conductor' in info['name']:
                pkg = 'Line'
            elif 'Wire' in info['name'] or 'Conductor' in info['name']:
                pkg = 'WireInfo'
            elif 'Connectivity' in info['name'] or 'Terminal' in info['name']:
                pkg = 'Connectivity'
            else:
                pkg = 'Base'
            
            if pkg not in packages:
                packages[pkg] = []
            packages[pkg].append(info['name'])
        
        # Генерируем классы по пакетам
        for pkg, classes in packages.items():
            diagram += f'package "{pkg}" {{\n'
            for cls_name in classes:
                diagram += f'  class {cls_name}\n'
            diagram += '}\n\n'
        
        diagram += "@enduml\n"
        
        output_path = Path(__file__).parent.parent / "docs" / "cimpy_classes_detailed.puml"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(diagram)
        
        print(f"✅ Детальная диаграмма CIMpy создана: {output_path}")
        
        return output_path
        
    except Exception as e:
        print(f"⚠️ Ошибка при анализе CIMpy: {e}")
        return None


def main():
    """Главная функция"""
    print("=" * 60)
    print("Генерация UML диаграмм CIM модели")
    print("=" * 60)
    
    # 1. Базовая PlantUML диаграмма
    print("\n1. Генерация базовой PlantUML диаграммы...")
    puml_path = generate_plantuml_diagram()
    
    # 2. Graphviz диаграмма
    print("\n2. Генерация Graphviz диаграммы...")
    try:
        gv_path = generate_graphviz_diagram()
    except Exception as e:
        print(f"   ⚠️ Ошибка: {e}")
        gv_path = None
    
    # 3. Детальная диаграмма CIMpy
    if CIMPY_AVAILABLE:
        print("\n3. Анализ классов CIMpy...")
        cimpy_path = analyze_cimpy_classes()
    else:
        print("\n3. Пропущено (CIMpy не установлен)")
        cimpy_path = None
    
    print("\n" + "=" * 60)
    print("Результаты:")
    print("=" * 60)
    print(f"✅ PlantUML: {puml_path}")
    if gv_path:
        print(f"✅ Graphviz: {gv_path}.png")
    if cimpy_path:
        print(f"✅ CIMpy детальная: {cimpy_path}")
    
    print("\n📖 Как использовать:")
    print("1. PlantUML:")
    print("   - Онлайн: https://www.plantuml.com/plantuml/uml/")
    print("   - VS Code: установите расширение 'PlantUML'")
    print("   - IntelliJ: встроенная поддержка")
    print("2. Graphviz:")
    print("   - Откройте .png файл")
    print("   - Или установите Graphviz и используйте: dot -Tpng file.dot -o output.png")
    
    print("\n🔗 Полезные ссылки:")
    print("- CIM User Group: https://cimug.ucaiug.org/")
    print("- IEC 61970-301: CIM Base")
    print("- IEC 61970-552: mRID и протокол обмена")


if __name__ == "__main__":
    main()

