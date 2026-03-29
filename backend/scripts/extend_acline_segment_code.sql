-- Расширение колонки acline_segment.code до VARCHAR(36) для единого UID (mrid)
-- Выполнить один раз после обновления кода: psql -U user -d dbname -f extend_acline_segment_code.sql

ALTER TABLE acline_segment
  ALTER COLUMN code TYPE VARCHAR(36);

COMMENT ON COLUMN acline_segment.code IS 'Единый UID (совпадает с mrid), без префиксов SEG- и т.п.';
