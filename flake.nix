{
  description = "PL/pgSQL development flake with PostgreSQL client and optional server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Choose version of PostgreSQL
        postgres = pkgs.postgresql_15;

      in {
        devShells.default = pkgs.mkShell {
          name = "plpgsql-dev";

          buildInputs = [
            postgres
            pkgs.pgcli         # Optional: nice interactive CLI
            pkgs.libpq         # For C client libraries or bindings
          ];

          shellHook = ''
            echo "🛢️  Welcome to your PL/pgSQL dev environment"
            echo "🔧 psql version: $(psql --version)"
            echo "📁 Project directory: $PWD"
            export PGDATA=$PWD/pgdata
            export PGDATABASE=dev
            export PGUSER=dev
            export PGPASSWORD=dev
            export PGPORT=5433
          '';
        };
      });
}
