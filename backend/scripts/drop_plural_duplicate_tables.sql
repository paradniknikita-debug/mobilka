-- Однократная очистка: удаление дубликатов таблиц (множественное число),
-- когда уже есть таблицы в единственном числе (line, pole, connectivity_node и т.д.).
--
-- ВАЖНО:
-- 1. Сделайте бэкап БД перед запуском: pg_dump -U postgres lepm_db > backup_before_cleanup.sql
-- 2. Убедитесь, что рабочие данные в таблицах единственного числа (pole, line, ...).
-- 3. Запуск: psql -U postgres -d lepm_db -f drop_plural_duplicate_tables.sql
--    или: docker compose exec postgres psql -U postgres -d lepm_db -f /path/to/this/file
--
BEGIN;

-- Удаляем в порядке зависимостей (сначала те, кто ссылается на другие, потом родительские)
DROP TABLE IF EXISTS acline_segments CASCADE;
DROP TABLE IF EXISTS line_segments CASCADE;
DROP TABLE IF EXISTS line_sections CASCADE;
DROP TABLE IF EXISTS terminals CASCADE;
DROP TABLE IF EXISTS spans CASCADE;
DROP TABLE IF EXISTS taps CASCADE;
DROP TABLE IF EXISTS connectivity_nodes CASCADE;
DROP TABLE IF EXISTS poles CASCADE;
DROP TABLE IF EXISTS substations CASCADE;
DROP TABLE IF EXISTS bays CASCADE;
DROP TABLE IF EXISTS busbar_sections CASCADE;
DROP TABLE IF EXISTS power_lines CASCADE;
DROP TABLE IF EXISTS position_points CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS base_voltages CASCADE;
DROP TABLE IF EXISTS wire_infos CASCADE;
DROP TABLE IF EXISTS voltage_levels CASCADE;

COMMIT;
