-- Serialize repeated/concurrent runs of this seed without touching existing services.
SELECT pg_advisory_xact_lock(5260904);

INSERT INTO users (login, password, created_at)
VALUES ('__extras_demo__', gen_random_uuid()::text, CURRENT_TIMESTAMP)
ON CONFLICT (login) DO NOTHING;

WITH examples (name, description, mass, media) AS (
    VALUES
        ('Электрон', 'Отрицательно заряженный лептон. Входит в электронную оболочку атома.',
         9.109e-31::double precision, 'electron'),
        ('Протон', 'Положительно заряженная частица, входящая в состав атомных ядер.',
         1.6726e-27, 'proton'),
        ('Нейтрон', 'Электрически нейтральная частица атомного ядра, состоящая из трех кварков.',
         1.6749e-27, 'neutron'),
        ('Позитрон', 'Античастица электрона с такой же массой и положительным зарядом.',
         9.109e-31, 'positron'),
        ('Нейтрино', 'Элементарная частица с очень малой массой, участвующая в слабом взаимодействии.',
         NULL, 'neutrino')
)
INSERT INTO particles (name, full_description, status, image_key, video_key, mass, spin, creator_id, created_at, formed_at)
SELECT e.name, e.description, 'published', 'extras/' || e.media || '.jpg',
       CASE WHEN e.media <> 'neutrino' THEN 'extras/' || e.media || '.mp4' END, e.mass, '1/2', u.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM examples e
JOIN users u ON u.login = '__extras_demo__'
WHERE NOT EXISTS (
    SELECT 1 FROM particles p WHERE p.creator_id = u.id AND p.name = e.name
);

WITH existing AS MATERIALIZED (
    SELECT p.name FROM particles p
    JOIN users u ON p.creator_id = u.id
    WHERE u.login = '__extras_demo__' AND p.name LIKE 'Тестовая частица №%'
), samples AS (
    SELECT n, 'Тестовая частица №' || n AS name FROM generate_series(1, 120000) AS n
)
INSERT INTO particles (name, full_description, status, mass, spin, creator_id, created_at, formed_at)
SELECT s.name, 'Синтетическая запись для проверки фильтрации и пагинации.',
       'published', 1e-30 + s.n * 1e-30, '1/2', u.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM samples s
JOIN users u ON u.login = '__extras_demo__'
WHERE NOT EXISTS (SELECT 1 FROM existing e WHERE e.name = s.name);
