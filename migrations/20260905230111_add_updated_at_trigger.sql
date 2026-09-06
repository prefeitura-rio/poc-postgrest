-- +goose Up
-- +goose StatementBegin
CREATE FUNCTION app.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql
SET search_path = app, pg_temp
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
-- +goose StatementEnd

CREATE TRIGGER tasks_touch_updated_at
BEFORE UPDATE ON app.tasks
FOR EACH ROW
EXECUTE FUNCTION app.touch_updated_at();

-- +goose Down
DROP TRIGGER tasks_touch_updated_at ON app.tasks;

DROP FUNCTION app.touch_updated_at();
