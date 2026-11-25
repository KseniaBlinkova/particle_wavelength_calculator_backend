-- Serialize repeated/concurrent runs of this seed without touching existing services.
SELECT pg_advisory_xact_lock(5260904);

INSERT INTO users (login, password, created_at)
VALUES ('__extras_demo__', gen_random_uuid()::text, CURRENT_TIMESTAMP)
ON CONFLICT (login) DO NOTHING;

WITH examples (name, description, caption, mass, media) AS (
    VALUES
        ('Электрон', 'Отрицательно заряженный лептон. Входит в электронную оболочку атома.',
         'A luminous green ring of electron particles with soft rays against black space.', 9.109e-31::double precision, 'electron'),
        ('Протон', 'Положительно заряженная частица, входящая в состав атомных ядер.',
         'Purple spheres with bright pink centers float in a dark illustration of protons.', 1.6726e-27, 'proton'),
        ('Нейтрон', 'Электрически нейтральная частица атомного ядра, состоящая из трех кварков.',
         'A violet neutron sphere connected to an abstract purple network on a black background.', 1.6749e-27, 'neutron'),
        ('Позитрон', 'Античастица электрона с такой же массой и положительным зарядом.',
         'A positron illustration of a hollow metallic sphere pierced by colored laser beams.', 9.109e-31, 'positron'),
        ('Нейтрино', 'Элементарная частица с очень малой массой, участвующая в слабом взаимодействии.',
         'A chain of glowing yellow neutrino spheres and thin lines on a black background.', NULL, 'neutrino')
), backfilled AS (
    UPDATE particles p SET description_en = e.caption
    FROM examples e, users u
    WHERE p.creator_id = u.id AND u.login = '__extras_demo__'
      AND p.name = e.name AND COALESCE(btrim(p.description_en), '') = ''
)
INSERT INTO particles (name, full_description, description_en, status, image_key, video_key, mass, spin, creator_id, created_at, formed_at)
SELECT e.name, e.description, e.caption, 'published', 'extras/' || e.media || '.jpg',
       CASE WHEN e.media <> 'neutrino' THEN 'extras/' || e.media || '.mp4' END, e.mass, '1/2', u.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM examples e
JOIN users u ON u.login = '__extras_demo__'
WHERE NOT EXISTS (
    SELECT 1 FROM particles p WHERE p.creator_id = u.id AND p.name = e.name
);

UPDATE particles p
SET description_en = 'A positron illustration of a hollow metallic sphere pierced by colored laser beams.'
FROM users u
WHERE p.creator_id = u.id AND u.login = '__extras_demo__' AND p.image_key = 'extras/positron.jpg'
  AND p.description_en = 'A dark positron sphere emitting sharp beams of red, yellow, and violet light.';

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

-- Fill captions for existing records without replacing edits or changing IDs.
WITH captions (image_key, caption) AS (
    VALUES
        ('electron.jpg', 'Green streaks of light surround a dark center in an illustration of an electron.'),
        ('proton.jpg', 'Glowing pink and purple bubbles illustrate protons against a dark background.'),
        ('neutron.jpg', 'Purple lights and thin connecting lines form a stylized illustration of a neutron.'),
        ('positron.jpg', 'Red and yellow beams cross a dark scene with spheres illustrating a positron.'),
        ('image_7194_20261011_120908_b1ee7d.jpg', 'A bright blue center with crossing orbital trails illustrates a muon in dark space.'),
        ('image_7194_20261014_104514_2ff31e.jpg', 'A bright blue center with crossing orbital trails illustrates a muon in dark space.'),
        ('image_electron_20261123_121546_c3e722.jpg', 'An educational illustration of an electron surrounded by green glowing trails.'),
        ('image_1ezhik-sovsemneponravilos_20261123_121753_b54ced.png', 'A smiling pink cartoon hedgehog with purple spines and large round glasses.')
)
UPDATE particles p SET description_en = c.caption
FROM captions c
WHERE p.image_key = c.image_key AND COALESCE(btrim(p.description_en), '') = '';
