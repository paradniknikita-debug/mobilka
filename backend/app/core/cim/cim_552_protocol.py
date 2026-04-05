"""
Реализация протокола IEC 61970-552:2016 для обмена данными
Протокол определяет формат обмена данными в энергетике через веб-сервисы
"""
from typing import Dict, Any, List, Optional
from datetime import datetime
from enum import Enum


class MessageType(str, Enum):
    """Типы сообщений по протоколу 552"""
    REQUEST = "Request"
    RESPONSE = "Response"
    NOTIFICATION = "Notification"
    ERROR = "Error"


class MessagePurpose(str, Enum):
    """Назначение сообщения"""
    GET = "Get"
    CREATE = "Create"
    UPDATE = "Update"
    DELETE = "Delete"
    QUERY = "Query"
    SUBSCRIBE = "Subscribe"
    UNSUBSCRIBE = "Unsubscribe"


class CIM552Message:
    """
    Сообщение по протоколу IEC 61970-552:2016
    
    Структура сообщения:
    - Header: метаданные сообщения
    - Body: данные CIM объектов
    """
    
    def __init__(
        self,
        message_type: MessageType,
        message_purpose: MessagePurpose,
        sender_id: str,
        receiver_id: str,
        message_id: Optional[str] = None,
        correlation_id: Optional[str] = None,
        timestamp: Optional[datetime] = None,
        cim_objects: Optional[List[Dict[str, Any]]] = None
    ):
        self.message_type = message_type
        self.message_purpose = message_purpose
        self.sender_id = sender_id
        self.receiver_id = receiver_id
        self.message_id = message_id or f"msg_{datetime.now().strftime('%Y%m%d%H%M%S%f')}"
        self.correlation_id = correlation_id
        self.timestamp = timestamp or datetime.now()
        self.cim_objects = cim_objects or []
    
    def to_dict(self) -> Dict[str, Any]:
        """Преобразование сообщения в словарь"""
        return {
            "Header": {
                "MessageType": self.message_type.value,
                "MessagePurpose": self.message_purpose.value,
                "SenderID": self.sender_id,
                "ReceiverID": self.receiver_id,
                "MessageID": self.message_id,
                "CorrelationID": self.correlation_id,
                "Timestamp": self.timestamp.isoformat(),
                "CIMVersion": "CIM16",
                "ProtocolVersion": "552:2016"
            },
            "Body": {
                "CIMObjects": self.cim_objects
            }
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "CIM552Message":
        """Создание сообщения из словаря"""
        header = data.get("Header", {})
        body = data.get("Body", {})
        
        return cls(
            message_type=MessageType(header.get("MessageType", "Request")),
            message_purpose=MessagePurpose(header.get("MessagePurpose", "Get")),
            sender_id=header.get("SenderID", ""),
            receiver_id=header.get("ReceiverID", ""),
            message_id=header.get("MessageID"),
            correlation_id=header.get("CorrelationID"),
            timestamp=datetime.fromisoformat(header.get("Timestamp", datetime.now().isoformat())),
            cim_objects=body.get("CIMObjects", [])
        )


class CIM552Service:
    """
    Сервис для работы с протоколом IEC 61970-552:2016
    
    Обеспечивает:
    - Формирование сообщений запросов
    - Обработку сообщений ответов
    - Валидацию сообщений
    - Преобразование в CIM XML
    """
    
    def __init__(self, system_id: str):
        self.system_id = system_id
    
    def create_request(
        self,
        purpose: MessagePurpose,
        receiver_id: str,
        cim_objects: Optional[List[Dict[str, Any]]] = None,
        correlation_id: Optional[str] = None
    ) -> CIM552Message:
        """Создание запроса"""
        return CIM552Message(
            message_type=MessageType.REQUEST,
            message_purpose=purpose,
            sender_id=self.system_id,
            receiver_id=receiver_id,
            correlation_id=correlation_id,
            cim_objects=cim_objects or []
        )
    
    def create_response(
        self,
        request: CIM552Message,
        cim_objects: Optional[List[Dict[str, Any]]] = None,
        success: bool = True,
        error_message: Optional[str] = None
    ) -> CIM552Message:
        """Создание ответа на запрос"""
        if not success:
            return CIM552Message(
                message_type=MessageType.ERROR,
                message_purpose=request.message_purpose,
                sender_id=self.system_id,
                receiver_id=request.sender_id,
                correlation_id=request.message_id,
                cim_objects=[{"error": error_message}] if error_message else []
            )
        
        return CIM552Message(
            message_type=MessageType.RESPONSE,
            message_purpose=request.message_purpose,
            sender_id=self.system_id,
            receiver_id=request.sender_id,
            correlation_id=request.message_id,
            cim_objects=cim_objects or []
        )
    
    def validate_message(self, message: CIM552Message) -> tuple[bool, Optional[str]]:
        """Валидация сообщения"""
        if not message.sender_id:
            return False, "SenderID is required"
        
        if not message.receiver_id:
            return False, "ReceiverID is required"
        
        if not message.message_id:
            return False, "MessageID is required"
        
        return True, None

