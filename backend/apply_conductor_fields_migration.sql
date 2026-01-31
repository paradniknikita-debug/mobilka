-- Миграция: добавление полей марки провода в таблицу poles
-- Выполните этот SQL скрипт в базе данных

-- Добавляем поля марки провода в таблицу poles
ALTER TABLE poles 
ADD COLUMN IF NOT EXISTS conductor_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS conductor_material VARCHAR(50),
ADD COLUMN IF NOT EXISTS conductor_section VARCHAR(20);

-- Комментарии к полям
COMMENT ON COLUMN poles.conductor_type IS 'Марка провода для этой опоры (AC-70, AC-95 и т.д.)';
COMMENT ON COLUMN poles.conductor_material IS 'Материал провода (алюминий, медь)';
COMMENT ON COLUMN poles.conductor_section IS 'Сечение провода в мм² (70, 95 и т.д.)';

