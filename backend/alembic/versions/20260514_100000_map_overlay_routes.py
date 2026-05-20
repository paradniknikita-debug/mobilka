"""Таблицы маршрутов поверх карты (полилинии) + демо-линия.

Revision ID: 20260514_100000
Revises: 20260512_160000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = "20260514_100000"
down_revision = "20260512_160000"
branch_labels = None
depends_on = None


def _table_exists(conn, name: str) -> bool:
    r = conn.execute(
        text("SELECT to_regclass(:n) IS NOT NULL"),
        {"n": f"public.{name}"},
    )
    return bool(r.scalar())


def upgrade() -> None:
    conn = op.get_bind()
    if _table_exists(conn, "map_overlay_route"):
        return
    op.create_table(
        "map_overlay_route",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )

    op.create_table(
        "map_overlay_route_point",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("route_id", sa.Integer(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.ForeignKeyConstraint(
            ["route_id"],
            ["map_overlay_route.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_map_overlay_route_point_route_id",
        "map_overlay_route_point",
        ["route_id"],
        unique=False,
    )

    op.execute(
        text(
            "INSERT INTO map_overlay_route (id, slug, title) "
            "VALUES (1, 'demo_great_circle', 'Демо-маршрут (равномерно по дуге)')"
        )
    )

    pts = [
        (1, 55.26761372382896, 30.52346362054548),
        (2, 55.26451947106894, 30.51884191186435),
        (3, 55.26142504377087, 30.51422092311609),
        (4, 55.25833044198206, 30.50960065414614),
        (5, 55.25523566574982, 30.50498110479994),
        (6, 55.25214071512143, 30.50036227492301),
        (7, 55.24904559014417, 30.49574416436081),
        (8, 55.24595029086528, 30.49112677295891),
        (9, 55.24285481733203, 30.48651010056285),
        (10, 55.23975916959162, 30.48189414701821),
        (11, 55.23666334769128, 30.47727891217062),
        (12, 55.23356735167821, 30.47266439586568),
        (13, 55.23047118159958, 30.46805059794907),
        (14, 55.22737483750259, 30.46343751826647),
        (15, 55.22427831943440, 30.45882515666359),
        (16, 55.22118162744214, 30.45421351298616),
        (17, 55.21808476157294, 30.44960258707994),
        (18, 55.21498772187392, 30.44499237879072),
        (19, 55.21189050839219, 30.44038288796431),
        (20, 55.20879312117482, 30.43577411444653),
        (21, 55.20569556026891, 30.43116605808325),
        (22, 55.20259782572151, 30.42655871872036),
        (23, 55.19949991757966, 30.42195209620377),
        (24, 55.19640183589039, 30.41734619037942),
        (25, 55.19330358070074, 30.41274100109325),
        (26, 55.19020515205769, 30.40813652819127),
        (27, 55.18710655000823, 30.40353277151948),
        (28, 55.18400777459937, 30.39892973092393),
        (29, 55.18090882587803, 30.39432740625067),
        (30, 55.17780970389119, 30.38972579734580),
        (31, 55.17471040868577, 30.38512490405542),
        (32, 55.17161094030870, 30.38052472622567),
        (33, 55.16851129880688, 30.37592526370273),
        (34, 55.16541148422719, 30.37132651633277),
        (35, 55.16231149661652, 30.36672848396202),
        (36, 55.15921133602174, 30.36213116643670),
        (37, 55.15611100248970, 30.35753456360310),
        (38, 55.15301049606722, 30.35293867530750),
        (39, 55.14990981680115, 30.34834350139621),
        (40, 55.14680896473828, 30.34374904171559),
    ]
    bind = op.get_bind()
    pid = 1
    for seq, lat, lon in pts:
        bind.execute(
            text(
                "INSERT INTO map_overlay_route_point "
                "(id, route_id, sequence_number, latitude, longitude) "
                "VALUES (:id, 1, :seq, :lat, :lon)"
            ),
            {"id": pid, "seq": seq, "lat": lat, "lon": lon},
        )
        pid += 1

    bind.execute(
        text(
            "SELECT setval(pg_get_serial_sequence('map_overlay_route', 'id'), "
            "(SELECT COALESCE(MAX(id), 1) FROM map_overlay_route))"
        )
    )
    bind.execute(
        text(
            "SELECT setval(pg_get_serial_sequence('map_overlay_route_point', 'id'), "
            "(SELECT COALESCE(MAX(id), 1) FROM map_overlay_route_point))"
        )
    )


def downgrade() -> None:
    op.drop_index("ix_map_overlay_route_point_route_id", table_name="map_overlay_route_point")
    op.drop_table("map_overlay_route_point")
    op.drop_table("map_overlay_route")
