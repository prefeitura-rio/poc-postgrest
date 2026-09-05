{ pkgs, config, ... }:
{
  name = "poc";

  env = {
    UV_PYTHON = config.languages.python.package.outPath;
  };

  packages = with pkgs; [
    nushell
    goose
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

  treefmt.config.programs.sqlfluff.enable = true;

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
  };
}
