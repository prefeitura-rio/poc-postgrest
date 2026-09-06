-- +goose Up
CREATE SCHEMA app;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE app.tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE ROLE web_anon NOLOGIN;

GRANT USAGE ON SCHEMA app TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.tasks TO web_anon;

-- +goose Down
REVOKE SELECT, INSERT, UPDATE, DELETE ON app.tasks FROM web_anon;
REVOKE USAGE ON SCHEMA app FROM web_anon;

DROP ROLE web_anon;

DROP TABLE app.tasks;

DROP EXTENSION IF EXISTS pgcrypto;

DROP SCHEMA app;
