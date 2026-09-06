-- +goose Up
CREATE TYPE app.task_status AS ENUM ('pending', 'completed');

SET LOCAL lock_timeout = '2s';

ALTER TABLE app.tasks
ALTER COLUMN status DROP DEFAULT,
ALTER COLUMN status TYPE app.task_status USING status::app.task_status,
ALTER COLUMN status SET DEFAULT 'pending',
DROP CONSTRAINT tasks_status_check;

-- +goose Down
SET LOCAL lock_timeout = '2s';

ALTER TABLE app.tasks
ALTER COLUMN status DROP DEFAULT,
ALTER COLUMN status TYPE text USING status::text,
ALTER COLUMN status SET DEFAULT 'pending',
ADD CONSTRAINT tasks_status_check CHECK (status IN ('pending', 'completed'));

DROP TYPE app.task_status;
