-- Миграция: магистраль и отпайки (TAPS_AND_MAINLINE)
-- Добавляет branch_type и tap_pole_id в pole и acline_segment.
-- Идемпотентно: можно запускать повторно.
-- Запуск: psql -U postgres -d lepm_db -f add_taps_mainline_columns.sql

BEGIN;

-- pole: branch_type ('main'|'tap'), tap_pole_id (FK pole.id)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'branch_type') THEN
    ALTER TABLE pole ADD COLUMN branch_type VARCHAR(10) NULL;
    RAISE NOTICE 'Added pole.branch_type';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'pole' AND column_name = 'tap_pole_id') THEN
    ALTER TABLE pole ADD COLUMN tap_pole_id INTEGER NULL REFERENCES pole(id);
    RAISE NOTICE 'Added pole.tap_pole_id';
  END IF;
END $$;

-- acline_segment: branch_type, tap_pole_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'branch_type') THEN
    ALTER TABLE acline_segment ADD COLUMN branch_type VARCHAR(10) NULL;
    RAISE NOTICE 'Added acline_segment.branch_type';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'acline_segment' AND column_name = 'tap_pole_id') THEN
    ALTER TABLE acline_segment ADD COLUMN tap_pole_id INTEGER NULL REFERENCES pole(id);
    RAISE NOTICE 'Added acline_segment.tap_pole_id';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_pole_tap_pole_id ON pole(tap_pole_id);
CREATE INDEX IF NOT EXISTS idx_acline_segment_tap_pole_id ON acline_segment(tap_pole_id);

COMMIT;
