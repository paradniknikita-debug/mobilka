-- Перенос данных из towers в poles и обновление внешних ключей

-- 1. Переносим данные из towers в poles
INSERT INTO poles (
    id, mrid, power_line_id, segment_id, 
    pole_number, latitude, longitude, pole_type,
    height, foundation_type, material, year_installed,
    condition, notes, created_by, created_at, updated_at
)
SELECT 
    id, mrid, power_line_id, segment_id,
    tower_number, latitude, longitude, tower_type,
    height, foundation_type, material, year_installed,
    condition, notes, created_by, created_at, updated_at
FROM towers
ON CONFLICT (id) DO NOTHING;

-- 2. Обновляем внешние ключи в spans (если колонки еще не переименованы)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'spans' AND column_name = 'from_tower_id') THEN
        UPDATE spans SET from_pole_id = from_tower_id WHERE from_tower_id IS NOT NULL;
        UPDATE spans SET to_pole_id = to_tower_id WHERE to_tower_id IS NOT NULL;
    END IF;
END $$;

-- 3. Обновляем внешние ключи в taps
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'taps' AND column_name = 'tower_id') THEN
        UPDATE taps SET pole_id = tower_id WHERE tower_id IS NOT NULL;
    END IF;
END $$;

-- 4. Обновляем внешние ключи в equipment
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipment' AND column_name = 'tower_id') THEN
        UPDATE equipment SET pole_id = tower_id WHERE tower_id IS NOT NULL;
    END IF;
END $$;

-- 5. Обновляем внешние ключи в acline_segments
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'acline_segments' AND column_name = 'start_tower_id') THEN
        UPDATE acline_segments SET start_pole_id = start_tower_id WHERE start_tower_id IS NOT NULL;
        UPDATE acline_segments SET end_pole_id = end_tower_id WHERE end_tower_id IS NOT NULL;
    END IF;
END $$;

-- Проверка результата
SELECT 'towers' as table_name, COUNT(*) as count FROM towers
UNION ALL
SELECT 'poles', COUNT(*) FROM poles;

