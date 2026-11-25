# Дополнительное задание «Индексы в БД»

Бэкенд каталога частиц с фильтром по массе, пагинацией и случайной лентой на Redis.

## Запуск

Нужны Docker Compose и Go 1.27.

```bash
docker compose up -d --wait
go run ./cmd/particleserver
```

Для демонстрационных изображений и видео нужна соседняя папка `particle_wavelength_calculator_frontend` с веткой `extra/indexes`. Когда API запустится, выполните в другом терминале `go run ./cmd/seedextras`. Команда создаст 120 000 тестовых записей и добавит демонстрационные карточки. API доступен на `http://localhost:8081/api`, Swagger UI — на `http://localhost:8081/swagger/index.html`.

## Проверка индекса

Сравните планы одного запроса с выключенным и включённым индексом:

```bash
docker compose exec -T postgres_particle psql -U particle_user -d particle_db < sql/mass-index-off.sql
docker compose exec -T postgres_particle psql -U particle_user -d particle_db < sql/mass-index-explain.sql
docker compose exec -T postgres_particle psql -U particle_user -d particle_db < sql/mass-index-on.sql
docker compose exec -T postgres_particle psql -U particle_user -d particle_db < sql/mass-index-explain.sql
```

Частичный B-tree индекс хранит опубликованные карточки в порядке `mass DESC NULLS LAST, id ASC`. В выводе `EXPLAIN (ANALYZE, BUFFERS)` сравните способ чтения строк и время выполнения. Те же фильтр и лимит можно проверить через API:

```bash
curl 'http://localhost:8081/api/particles?min_mass=1e-25&limit=20&offset=0'
```

Для следующей страницы используйте `offset=20`. Поле `has_more` показывает, есть ли следующая страница, а `query_ms` — сколько времени заняло получение страницы из PostgreSQL.

Сценарий проверки интерфейса и случайной ленты приведён в [инструкции к фронтенду](https://github.com/KseniaBlinkova/particle_wavelength_calculator_frontend/blob/extra/indexes/docs/extras-defense.md).
