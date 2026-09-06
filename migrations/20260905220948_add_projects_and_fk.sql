-- +goose Up
CREATE TABLE app.projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL, -- noqa: RF04
    created_at timestamptz NOT NULL DEFAULT now()
);

SET LOCAL lock_timeout = '2s';

ALTER TABLE app.tasks
ADD COLUMN project_id uuid;

ALTER TABLE app.tasks
ADD CONSTRAINT tasks_project_id_fkey
FOREIGN KEY (project_id) REFERENCES app.projects (id) ON DELETE SET NULL
NOT VALID;

SET LOCAL lock_timeout = '2s';

CREATE INDEX tasks_project_id_idx ON app.tasks (project_id);

ALTER TABLE app.tasks
VALIDATE CONSTRAINT tasks_project_id_fkey;

GRANT SELECT, INSERT, UPDATE, DELETE ON app.projects TO web_anon;

-- +goose Down
REVOKE SELECT, INSERT, UPDATE, DELETE ON app.projects FROM web_anon;

DROP INDEX app.tasks_project_id_idx;

ALTER TABLE app.tasks DROP COLUMN project_id;

DROP TABLE app.projects;
