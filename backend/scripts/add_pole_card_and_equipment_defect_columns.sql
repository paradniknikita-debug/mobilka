-- Добавить колонки карточки опоры и дефектов оборудования, если их ещё нет.
-- Выполнить при ошибке: column pole.card_comment does not exist
-- Пример: psql -h localhost -p 5433 -U your_user -d lepm_db -f add_pole_card_and_equipment_defect_columns.sql

ALTER TABLE pole ADD COLUMN IF NOT EXISTS card_comment TEXT;
ALTER TABLE pole ADD COLUMN IF NOT EXISTS card_comment_attachment TEXT;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS defect TEXT;
ALTER TABLE equipment ADD COLUMN IF NOT EXISTS criticality VARCHAR(20);
