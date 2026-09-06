{ pkgs, config, ... }:
{
  name = "poc";

  env = {
    UV_PYTHON = config.languages.python.package.outPath;
  };

  packages = with pkgs; [
    goose
    hurl
    nushell
    sqlfluff
  ];

  languages = {
    python = {
      enable = true;
      package = pkgs.python314;
      lsp.package = pkgs.basedpyright;
      uv = {
        enable = true;
        sync = {
          enable = true;
          allGroups = true;
        };
      };
    };
  };

  git-hooks.hooks = {
    ruff.enable = true;
    ruff-format.enable = true;
    ripsecrets.enable = true;
    basedpyright = {
      enable = true;
      name = "basedpyright";
      entry = "${pkgs.uv}/bin/uv run basedpyright src/";
      language = "system";
      types = [ "python" ];
      pass_filenames = false;
    };
    sqlfluff = {
      enable = true;
      name = "sqlfluff";
      entry = "${pkgs.sqlfluff}/bin/sqlfluff lint --dialect postgres";
      language = "system";
      types = [ "sql" ];
      pass_filenames = true;
    };
  };

  tasks = {
    "poc:up".exec = ''
      docker compose down -v
      docker compose up --build -d
      sleep 5
    '';
    "poc:down".exec = "docker compose down -v";
    "poc:lint:pgls".exec = ''
      docker compose -f docker-compose.typecheck.yaml run --rm --build pgls
      docker compose -f docker-compose.typecheck.yaml down -v
    '';
    "poc:lint".exec = ''
      uv run ruff check src/
      uv run ruff format --check src/
      uv run basedpyright src/
      sqlfluff lint --dialect postgres migrations/
    '';
    "poc:test" = {
      exec = "hurl --test poc.hurl ";
      after = [ "poc:up" ];
      before = [ "poc:down" ];
    };
  };
}
