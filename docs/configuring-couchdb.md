<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up CouchDB

This is an [Ansible](https://www.ansible.com/) role which installs [CouchDB](https://couchdb.apache.org/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

CouchDB is a document-oriented NoSQL database which uses JSON to store data.

See the project's [documentation](https://docs.couchdb.org/en/stable/) to learn what CouchDB does and why it might be useful to you.

## Adjusting the playbook configuration

To enable CouchDB with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# couchdb                                                              #
#                                                                      #
########################################################################

couchdb_enabled: true

########################################################################
#                                                                      #
# /couchdb                                                             #
#                                                                      #
########################################################################
```

### Specify server administrator's username and password

You also need to specify a server administrator's login credential by adding the following configuration to your `vars.yml` file:

```yaml
couchdb_root_username: YOUR_ADMIN_USERNAME_HERE

couchdb_root_password: YOUR_ADMIN_PASSWORD_HERE
```

>[!NOTE]
>
> - CouchDB requires a server administrator account to start. If one has not been created, CouchDB will print an error message and terminate. See [this section](#creating-users) below for details about how to create it.
> - After installing the CouchDB it will be possible to create other administrator accounts on its web UI.

### Specify users (optional)

You can create users by specifying ones with `couchdb_users_custom` as below on your `vars.yml` file:

```yaml
couchdb_users_custom:
  - name: YOUR_USER_USERNAME_HERE
    password: YOUR_USER_PASSWORD_HERE
    roles: []
    type: user
```

### Exposing the instance (optional)

By default, the CouchDB instance is not exposed externally, as it is mainly intended to be used in the internal network, connected to other services.

To expose it to the internet, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
couchdb_hostname: "example.com"

couchdb_container_labels_traefik_enabled: true
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting CouchDB under a subpath (by configuring the `couchdb_path_prefix` variable) does not seem to be possible due to CouchDB's technical limitations.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file.

See the [documentation](https://docs.couchdb.org/en/stable/config/index.html) for a complete list of CouchDB's config options that you could put in `couchdb_config_extension`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, CouchDB becomes available internally to other services on the same network. If the service is exposed to the internet, it becomes available at the specified hostname like `https://example.com`.

### Creating users

You can create users (administrators and normal users) by running the command below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=create-user-couchdb
```

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu couchdb` (or how you/your playbook named the service, e.g. `mash-couchdb`).
