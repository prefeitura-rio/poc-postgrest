-- +goose Up
CREATE TABLE app.projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app.tasks
    ADD COLUMN project_id uuid REFERENCES app.projects(id) ON DELETE SET NULL;

CREATE INDEX tasks_project_id_idx ON app.tasks (project_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON app.projects TO web_anon;

-- +goose Down
REVOKE SELECT, INSERT, UPDATE, DELETE ON app.projects FROM web_anon;

DROP INDEX app.tasks_project_id_idx;

ALTER TABLE app.tasks DROP COLUMN project_id;

DROP TABLE app.projects;
