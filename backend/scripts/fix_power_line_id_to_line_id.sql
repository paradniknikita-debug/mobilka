-- Переименование power_line_id -> line_id в таблицах, где колонка ещё не переименована.
-- Идемпотентно: только если есть power_line_id и нет line_id.

DO $$
DECLARE
  t TEXT;
  has_old BOOLEAN;
  has_new BOOLEAN;
BEGIN
  FOREACH t IN ARRAY ARRAY['pole', 'span', 'tap', 'line_section', 'acline_segment', 'connectivity_node']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
      SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'power_line_id') INTO has_old;
      SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'line_id') INTO has_new;
      IF has_old AND NOT has_new THEN
        EXECUTE format('ALTER TABLE %I RENAME COLUMN power_line_id TO line_id', t);
        RAISE NOTICE 'Renamed power_line_id to line_id in %', t;
      END IF;
    END IF;
  END LOOP;
END $$;
