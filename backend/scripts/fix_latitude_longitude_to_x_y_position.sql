-- Однократное приведение колонок координат к x_position / y_position.
-- Запускать, если миграция 20250221_800000 не применялась или схема отстаёт.
-- Идемпотентно: переименовывает только если есть latitude/longitude и нет x_position/y_position.

DO $$
DECLARE
  r RECORD;
  has_lat BOOLEAN;
  has_ypos BOOLEAN;
BEGIN
  FOR r IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('pole', 'tap', 'substation', 'connectivity_node'))
  LOOP
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = r.table_name AND column_name = 'latitude') INTO has_lat;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = r.table_name AND column_name = 'y_position') INTO has_ypos;
    IF has_lat AND NOT has_ypos THEN
      EXECUTE format('ALTER TABLE %I RENAME COLUMN latitude TO y_position', r.table_name);
      EXECUTE format('ALTER TABLE %I RENAME COLUMN longitude TO x_position', r.table_name);
      RAISE NOTICE 'Renamed latitude/longitude to y_position/x_position in %', r.table_name;
    END IF;
  END LOOP;
END $$;
