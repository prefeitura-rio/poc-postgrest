-- +goose Up
-- +goose StatementBegin
CREATE FUNCTION app.complete_all_tasks(p_project_id uuid) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, pg_temp
AS $$
DECLARE
    n integer;
BEGIN
    UPDATE app.tasks
        SET status = 'completed'
        WHERE project_id = p_project_id AND status = 'pending';
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;
-- +goose StatementEnd

GRANT EXECUTE ON FUNCTION app.complete_all_tasks(uuid) TO web_anon;

-- +goose Down
REVOKE EXECUTE ON FUNCTION app.complete_all_tasks(uuid) FROM web_anon;

DROP FUNCTION app.complete_all_tasks(uuid);
