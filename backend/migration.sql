-- Удаление unique constraint с pole_id (если есть)
ALTER TABLE connectivity_nodes DROP CONSTRAINT IF EXISTS uq_connectivity_nodes_pole_id;
ALTER TABLE connectivity_nodes DROP CONSTRAINT IF EXISTS connectivity_nodes_pole_id_key;

-- Добавление power_line_id, если его нет
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'connectivity_nodes' 
        AND column_name = 'power_line_id'
    ) THEN
        -- Добавляем колонку
        ALTER TABLE connectivity_nodes ADD COLUMN power_line_id INTEGER;
        
        -- Заполняем из опор
        UPDATE connectivity_nodes
        SET power_line_id = (
            SELECT power_line_id
            FROM poles
            WHERE poles.id = connectivity_nodes.pole_id
        )
        WHERE power_line_id IS NULL;
        
        -- Делаем NOT NULL
        ALTER TABLE connectivity_nodes ALTER COLUMN power_line_id SET NOT NULL;
        
        -- Добавляем foreign key
        ALTER TABLE connectivity_nodes 
        ADD CONSTRAINT fk_connectivity_nodes_power_line 
        FOREIGN KEY (power_line_id) 
        REFERENCES power_lines(id);
        
        -- Создаём индекс
        CREATE INDEX IF NOT EXISTS ix_connectivity_nodes_power_line_id 
        ON connectivity_nodes(power_line_id);
    END IF;
END $$;

