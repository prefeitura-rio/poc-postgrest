-- +goose Up
SET LOCAL lock_timeout = '2s';

ALTER TABLE app.tasks
ADD COLUMN description text,
ADD COLUMN search_vector tsvector
GENERATED ALWAYS AS (
    to_tsvector(
        'english', coalesce(title, '') || ' ' || coalesce(description, '')
    )
) STORED,
ADD COLUMN tags jsonb NOT NULL DEFAULT '[]';

SET LOCAL lock_timeout = '2s';

CREATE INDEX tasks_search_vector_idx ON app.tasks USING gin (search_vector);

SET LOCAL lock_timeout = '2s';

CREATE INDEX tasks_tags_idx ON app.tasks USING gin (tags);

-- +goose Down
SET LOCAL lock_timeout = '2s';

DROP INDEX app.tasks_tags_idx;
DROP INDEX app.tasks_search_vector_idx;

ALTER TABLE app.tasks
DROP COLUMN tags,
DROP COLUMN search_vector,
DROP COLUMN description;
