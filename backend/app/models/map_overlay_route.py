"""Маршруты поверх карты (полилинии), не привязанные к ЛЭП CIM."""

from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy import DateTime

from app.database import Base


class MapOverlayRoute(Base):
    __tablename__ = "map_overlay_route"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(80), unique=True, nullable=False, index=True)
    title = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    points = relationship(
        "MapOverlayRoutePoint",
        back_populates="route",
        cascade="all, delete-orphan",
        order_by="MapOverlayRoutePoint.sequence_number",
    )


class MapOverlayRoutePoint(Base):
    __tablename__ = "map_overlay_route_point"

    id = Column(Integer, primary_key=True, index=True)
    route_id = Column(
        Integer,
        ForeignKey("map_overlay_route.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sequence_number = Column(Integer, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    route = relationship("MapOverlayRoute", back_populates="points")
