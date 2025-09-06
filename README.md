# Deploying a High-Availability PostgreSQL Cluster with NixOS Flakes and Patroni

This repository provides a declarative approach to deploying high-availability PostgreSQL clusters, targeting system and database administrators. The solution leverages NixOS flakes for automated, reproducible deployments. High availability is achieved via Patroni, a robust management system that orchestrates PostgreSQL clusters, including automatic failover and leader election. Patroni utilizes a distributed consensus system (such as etcd or Consul) to maintain cluster state and ensure continuous database availability. The proposed architecture for this implementation is a four-node cluster.

* `psqlnode1` and `psqlnode2` — PostgreSQL database nodes
* `etcdnode` — etcd cluster node (or Consul)
* `haproxynode` — HAProxy load balancer node

## Prerequisites

### Packages

* net-tools
* PostgreSQL
* etcd

## Configure etcd by editing `/etc/default/etcd`:

```txt
ETCD_LISTEN_PEER_URLS="http://192.168.32.140:2380"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://192.168.32.140:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.32.140:2380"
ETCD_INITIAL_CLUSTER="default=http://192.168.32.140:2380,"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.32.140:2379"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
```

### Validate etcd

```sh
sudo systemctl restart etcd
sudo systemctl status etcd
curl http://192.168.32.140:2380/members
```

## Configure Patroni

```sh
scope: postgres
namespace: /db/
name: node1
restapi:
    listen: 192.168.32.130:8008
    connect_address: 192.168.32.130:8008
etcd:
    host: 192.168.32.140:2379
bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
  initdb:
  - encoding: UTF8
  - data-checksums
  pg_hba:
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator 192.168.32.130/0 md5
  - host replication replicator 192.168.32.131/0 md5
  - host all all 0.0.0.0/0 md5
  users:
    admin:
      password: admin
      options:
        - createrole
        - createdb
postgresql:
  listen: 192.168.32.130:5432
  connect_address: 192.168.32.130:5432
  data_dir: /data/patroni
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: admin@123
    superuser:
      username: postgres
      password: admin@123
  parameters:
      unix_socket_directories: '.'
tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
```


## PostgreSQL Server Flake

Flakes give you a declarative, single-file approach to service configuration, isolating your development and deployment environments. Instead of using a container runtime, this approach leverages a virtual filesystem, giving you precise control over your application and its dependencies without the management overhead for a kubernetes cluster. Flakes capture both kernel and user-space configurations, and let you define custom `develop`, `run`, `shell`, and `build` commands to streamline the entire service lifecycle.

### Project Structure

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

### Usage Instructions

Nix flakes execute a set of applications combining independent, sandboxed processes and avoid the overhead of a container environment. Exexcuting applications directly means less isolation but superior stability and better performance for statefull processes like a relational database server. Using the programmable Nix package manager, you can still create reproducible environments. To use this template, you fork the repository and simply modify `example.sql` and/or `process-compose.yaml`. 

#### Create Project Directory

As a first step, create a local directory and save the `flake.nix` and `src/example.sql` files, e.g. by cloning the github repository.

```sh
git clone https://github.com/torstenboettjer/flake_psql.git
```
*Example: Cloning the PSQL server template*

Git clone creates the directory and downloads the proposed files.

#### (Optional) Enable direnv auto-load

In case [direnv](https://direnv.net) is installed autoloading the flake is recommended.

```sh
echo 'use flake' > .envrc
direnv allow
```

#### Enter the Dev Shell

Engineers create a full-fledged development environment for a specific project with `nix develop`. It's designed to debug and build a Nix derivation. The command sets up a much richer environment than nix shell. In addition to adding binaries to your $PATH, it also sets up a wide range of environment variables, build inputs, and shell functions (configurePhase, buildPhase, etc.) that are necessary for building and developing a package. The environment represents a fully equipped "workshop". You are working on a project that requires specific compilers, libraries, and build tools. nix develop sets up the entire workspace exactly as it needs to be, so you can interactively run the build steps, test code, and troubleshoot.

Example: You have a project with a flake.nix file defining its development shell. You want to work on it.

```sh
nix develop
```

The dev shell provides access to psql, pgcli, and libpq in a clean environment.

##### Basic Nix Commands

| Goal                | Command Example                       |
| ------------------- | ------------------------------------- |
| Enter dev env       | `nix develop`                         |
| Run app             | `nix run .#my-app`                    |
| Build package       | `nix build .#my-pkg`                  |

Nix commands excute independent and isolated and applications run concurrently when a flake is stored in a separate directory and commands are exectued in a separate terminal.

#### Running a PostgreSQL Server and Creating a Database

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

##### Basic PostgreSQL Commands

| Tool     | Purpose                        |
| -------- | ------------------------------ |
| `psql`   | Main PostgreSQL CLI            |
| `pgcli`  | Enhanced CLI with autocomplete |
| `libpq`  | PostgreSQL client libraries    |
| `initdb` | Create local DB for dev        |
| `pg_ctl` | Manage the server              |


### Set Up a Flake for a Project

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

### Enter the Development Shell for Each Flake

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

### Composing Complex Servers

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

### Running Applications from Flakes

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

### Building Packages from a Flake

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

### Running Services Using `nix run` or Systemd/User Units

If a flake builds a web service or daemon, operators can run it with:

```sh
nix run github:username/my-service
```

Or hook it into a systemd user service (e.g. in `~/.config/systemd/user/my-service.service`), pointing to the flake output binary.

### Tips

1. Use `direnv` + `nix-direnv` to automatically load the flake dev shell on cd:

* Add `.envrc`: `use flake`
* Run `direnv allow`

2. Use flake registries to shorten flake URLs:

```sh
nix registry add mylib github:myname/mylib
nix run mylib
```

3. Use `nix flake show` to explore outputs of a flake.

## Technologies

* [NixOS](https://nixos.org/)
* [Home Manager](https://nix-community.github.io/home-manager/)
* [Direnv](https://direnv.net/)

## Contribution
* *Add features* If you have an idea for a new feature, please [open an issue](https://github.com/torstenboettjer/flake_psql/issues/new) to discuss it before creating a pull request.
* *Report bugs* If you find a bug, please [open an issue](https://github.com/torstenboettjer/flake_psql/issues/new) with a clear description of the problem.
* *Fix bugs* If you know how to fix a bug, submit a [pull request](https://github.com/torstenboettjer/flake_psql/pull/new) with your changes.
* *Improve documentation* If you find the documentation lacking, you can contribute improvements by editing the relevant files.
