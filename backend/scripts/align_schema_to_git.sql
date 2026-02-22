-- Приведение схемы БД к состоянию после всех миграций (как в git).
-- Запускать на проде, если схема отстаёт из‑за stamp/незавершённых миграций.
-- Идемпотентно: можно запускать повторно.
--
-- Делает:
-- 1) power_line_id -> line_id в pole, span, tap, connections, line_section, acline_segment, connectivity_node
-- 2) latitude -> y_position, longitude -> x_position в pole, tap, substation, connectivity_node
-- 3) DROP TABLE line_segments если есть
--
-- Перед запуском: pg_dump бэкап. Запуск: psql -U postgres -d lepm_db -f align_schema_to_git.sql

BEGIN;

-- 1. power_line_id -> line_id
DO $$
DECLARE
  t TEXT;
  has_old BOOLEAN;
  has_new BOOLEAN;
BEGIN
  FOREACH t IN ARRAY ARRAY['pole', 'span', 'tap', 'connections', 'line_section', 'acline_segment', 'connectivity_node']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
      SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'power_line_id') INTO has_old;
      SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'line_id') INTO has_new;
      IF has_old AND NOT has_new THEN
        EXECUTE format('ALTER TABLE %I RENAME COLUMN power_line_id TO line_id', t);
        RAISE NOTICE 'Renamed power_line_id -> line_id in %', t;
      END IF;
    END IF;
  END LOOP;
END $$;

-- 2. latitude -> y_position, longitude -> x_position
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
      RAISE NOTICE 'Renamed latitude/longitude -> y_position/x_position in %', r.table_name;
    END IF;
  END LOOP;
END $$;

-- 3. Удалить таблицу line_segments (дублирует связь по AClineSegment.line_id)
DROP TABLE IF EXISTS line_segments CASCADE;

COMMIT;
