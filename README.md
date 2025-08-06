# PostgreSQL Server Flake

This repository empowers system and database administrators to automate PostgreSQL server deployments with NixOS flakes. Flakes provide a consolidated, declarative approach to service configuration, isolating your development and deployment environments.

By leveraging NixOS flakes, you can capture both kernel and user-space configurations in a single file. This allows you to define custom `develop`, `run`, `shell`, and `build` commands, streamlining the entire service lifecycle. The repository's use of a virtual filesystem, rather than a virtual runtime, gives you precise control over your managed services and their dependencies without the overhead of traditional virtual environments.

## Project Structure

```sh
plpgsql-dev/
├── flake.nix
├── flake.lock       # created automatically after first `nix develop`
├── .envrc           # (optional, for direnv)
├── process-compose.yaml
├── README.md
└── src/
    └── example.sql
```

## Usage Instructions

NixOS flakes enable operators to run enterprise programs to build fragmented server **without user-space container (e.g. Docker)**. The linux distribution uses Nix packages to create reproducible environments, configures local sockets without open ports by default and eases customizations, e.g. following this example, modifying `example.sql` and/or adding services to `process-compose.yaml` enables engineers to build complex database server.

### Create Project Directory

```sh
mkdir plpgsql-dev && cd plpgsql-dev
```

Save the `flake.nix` and `src/example.sql` files or fetch the github repository.

```sh
git clone https://github.com/torstenboettjer/flake_psql.git
```
*Example: Fetching the PSQL server template*

Using git clone creates the directory and downloads the proposed files.

### (Optional) Enable direnv auto-load

```sh
echo 'use flake' > .envrc
direnv allow
```

### Enter the Dev Shell

```sh
nix develop
```

The dev shell provides access to psql, pgcli, and libpq in a clean environment.

#### Basic Nix Commands

| Goal                | Command Example                       |
| ------------------- | ------------------------------------- |
| Enter dev env       | `nix develop`                         |
| Run app             | `nix run .#my-app`                    |
| Build package       | `nix build .#my-pkg`                  |

Nix commands excute independent and isolated and applications run concurrently when a flake is stored in a separate directory and commands are exectued in a separate terminal.

### Running a PostgreSQL Server and Creating a Database

After loading the flake, engineers can spin up multiple PostgreSQL servers and test data or stored procedures.

```sh
initdb --locale=en_US.UTF-8 -E UTF8 -D pgdata
pg_ctl -D pgdata -o "-p 5433" -l logfile start
createdb -p 5433 dev
psql -p 5433 -d dev
```

Stopping the addtional server:

```sh
pg_ctl -D pgdata stop
```

#### Basic PostgreSQL Commands

| Tool     | Purpose                        |
| -------- | ------------------------------ |
| `psql`   | Main PostgreSQL CLI            |
| `pgcli`  | Enhanced CLI with autocomplete |
| `libpq`  | PostgreSQL client libraries    |
| `initdb` | Create local DB for dev        |
| `pg_ctl` | Manage the server              |


## Set Up a Flake for a Project

To setup mulitple projects for every instance an own `flake.nix` defined and stored in a separate directory.

```nix
{
  description = "Foo project dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = [
        nixpkgs.legacyPackages.x86_64-linux.git
        nixpkgs.legacyPackages.x86_64-linux.nodejs
      ];
    };
  };
}
```
*Example: ~/projects/foo/flake.nix*

To setup another project a completely separate configuration is stored as `flake.nix` in another directory.

```nix
{
  description = "Bar project dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = [ nixpkgs.legacyPackages.x86_64-linux.python3 ];
    };
  };
}
```
*Example: ~/projects/bar/flake.nix*

## Enter the Development Shell for Each Flake

`nix develop` is a command from Nix Flakes that enables engineers to drop into a development environment based on a flake's configuration. It sets up all the dependencies and environment variables needed for development — without permanently installing anything to the system.

```sh
cd ~/projects/foo && nix develop
```

Calling the same command in another terminal loads another devShell from a flake, builds any required dependencies, sets up an isolated shell environment with those dependencies available, and drops the user into this shell.

```sh
cd ~/projects/bar
nix develop
```

Foo and Bar represent isolated environments. Each has its own packages, variables, versions, and flake inputs.
To keep the shell separate, engineers run them in separate terminals, concurrently.

## Composing Complex Servers

Building more complex server, engineers can rely on `process-compose` as a scheduler that captures dependencies as part of a development environment in the Nix flake. `process-compose` is heavily inspired by docker, it reads the schedule from process-compose.yaml (or .yml) by default, similar to docker reading from docker-compose.yaml. Using the tool in flakes doesn’t change how process-compose works internally, but it helps to pin and reproducibly install it.

```nix
{
  description = "PostgreSQL dev environment using process-compose";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.process-compose
            pkgs.postgresql
            pkgs.pgcli # optional: friendly CLI
          ];

          shellHook = ''
            echo "Ready to run: process-compose up"
          '';
        };
      });
}
```
*Example configuration*

Then run:
```sh
nix develop
process-compose up
```

Run process-compose directly from a flake without devShell

```sh
nix run github:Platonic-Systems/process-compose
```

Or with a pinned version:

```sh
nix run github:Platonic-Systems/process-compose/v0.90.3
```

The default example runs the hello command repeatedly.

## Running Applications from Flakes

Flakes can also define apps, which can be run together with the database server

```nix
outputs = { self, nixpkgs }: {
  apps.x86_64-linux.hello = {
    type = "app";
    program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
  };
};
```
*Definition of a programm in the configuration file*

Running this program from the command line interface (CLI)

```sh
nix run .#hello
```

Flakes are configuration files that let engineers structure multiple services with encapsulated apps, scripts, etc. on a single machine.

## Building Packages from a Flake

Using flakes enables engineers to package entire solution footprints into nix files automate the downstream service provisioning process.

```nix
outputs = { self, nixpkgs }: {
  packages.x86_64-linux.mytool = nixpkgs.legacyPackages.x86_64-linux.callPackage ./mytool.nix {};
};
```

Then build it:

```sh
nix build .#mytool
```

## Running Services Using `nix run` or Systemd/User Units

If a flake builds a web service or daemon, operators can run it with:

```sh
nix run github:username/my-service
```

Or hook it into a systemd user service (e.g. in `~/.config/systemd/user/my-service.service`), pointing to the flake output binary.

## Tips

1. Use `direnv` + `nix-direnv` to automatically load the flake dev shell on cd:

* Add `.envrc`: `use flake`
* Run `direnv allow`

2. Use flake registries to shorten flake URLs:

```sh
nix registry add mylib github:myname/mylib
nix run mylib
```

3. Use `nix flake show` to explore outputs of a flake.
