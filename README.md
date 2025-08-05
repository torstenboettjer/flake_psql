# PostgreSQL Server Flake

This Flake enables Database Engineers to automate the setup of PostgreSQL server. It's build on NixOS and uses flakes to provide an isolated environment per projects. Nix enables engineers to run applications and scripts from different flakes, deploying services with their own flake-based configuration. Engineers define custom nix develop, nix run, nix shell, and nix build commands per project.

## Project Structure

```sh
plpgsql-dev/
├── flake.nix
├── flake.lock       # created automatically after first `nix develop`
├── .envrc           # (optional, for direnv)
├── README.md
└── src/
    └── example.sql
```

## Usage Instructions

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
