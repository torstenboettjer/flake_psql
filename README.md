# Flakes for Dev Environments or Services

This Repo describes how to use flakes for isolated development environments per project. It enables engineers to run applications and scripts from different flakes, deploying services with their own flake-based configuration. Inside the project folder engineers execute custom nix develop, nix run, nix shell, and nix build per flake.

## How to Use Multiple Flakes

| Goal                | Command Example                       |
| ------------------- | ------------------------------------- |
| Enter dev env       | `nix develop`                         |
| Run app             | `nix run .#my-app`                    |
| Build package       | `nix build .#my-pkg`                  |
| Use multiple flakes | Use each in a separate dir/terminal   |
| Run concurrently    | Yes, they’re independent and isolated |

## Set Up a Flake for a Project

Each project can be a separate directory with its own flake.nix.

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

You can have a completely separate flake for another project:

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

## Enter a Dev Shell for Each Flake

```sh
cd ~/projects/foo
nix develop

# In another terminal
cd ~/projects/bar
nix develop
```

These are isolated environments. Each has its own packages, variables, versions, and flake inputs.
You can run them in separate terminals, concurrently.


## Running Applications from Flakes

Flakes can define apps, which you can run directly:

```nix
outputs = { self, nixpkgs }: {
  apps.x86_64-linux.hello = {
    type = "app";
    program = "${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello";
  };
};
```

Then:

```sh
nix run .#hello
```

This lets you structure multiple small flakes to encapsulate apps, scripts, etc.

## Building Packages from a Flake

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

If a flake builds a web service or daemon, you can run it with:

```sh
nix run github:username/my-service
```

Or hook it into a systemd user service (e.g. in `~/.config/systemd/user/my-service.service`), pointing to the flake output binary.

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

### Save the `flake.nix` and `src/example.sql` files

### (Optional) Enable direnv auto-load

```sh
echo 'use flake' > .envrc
direnv allow
```

### Enter the Dev Shell

```sh
nix develop
```

You now have access to psql, pgcli, and libpq in a clean environment.

## Running a Local PostgreSQL Server (Optional)

You can use the built-in PostgreSQL to spin up a local server manually if you need test data or stored procedures.

```sh
initdb --locale=en_US.UTF-8 -E UTF8 -D pgdata
pg_ctl -D pgdata -o "-p 5433" -l logfile start
createdb -p 5433 dev
psql -p 5433 -d dev
```
To stop:
```sh
pg_ctl -D pgdata stop
```

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
