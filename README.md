<!--
SPDX-FileCopyrightText: 2024 Bergrübe

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# CouchDB Ansible Role for MASH Playbook

This Ansible role is designed to install and configure CouchDB for use with the [Mother of all self-hosting (MASH) playbook](https://github.com/mother-of-all-self-hosting/mash-playbook). It automates the process of setting up CouchDB in a Docker container, ensuring that the necessary system tables are created, users are added, and appropriate database permissions are set.
This role uses the [official CouchDB Docker image](https://github.com/apache/couchdb-docker).

## Features

- Sets up CouchDB in a Docker container.
- Creates necessary system tables, if `couchdb_config_single_node: true.
- Adds users as specified in the playbook.
- Sets database permissions.
- Integrates with the MASH playbook for easy deployment.

## Requirements

- Docker
- Ansible
- [MASH playbook](https://github.com/mother-of-all-self-hosting/mash-playbook)

## Usage

To use this role with the MASH playbook, add it to your inventory file in your MASH playbook directory:

```yaml
########################################################################
#                                                                      #
# couchdb                                                              #
#                                                                      #
########################################################################

couchdb_enabled:: true

couchdb_hostname: couchdb.example.com

# enable couchdb single node mode, to automatically create databases and users
couchdb_config_single_node: true

couchdb_admins_custom:
  - name: admin
    password: UseASecurePassword

couchdb_users_custom:
  - name: user1
    password: UseASecurePassword
    roles: []
    type: user

couchdb_tables_custom:
    - name: my_custom_table
      permission:
        admin:
          names:
            - user1
          roles: []
        member:
          names: []
          roles: []

########################################################################
#                                                                      #
# /cocuhdb                                                             #
#                                                                      #
########################################################################
```

You can customize the behavior of the role by setting the following variables in your playbook:

- `couchdb_environment_variables_extension`: to add additional environment variables to the CouchDB container.
- `couchdb_config_extension`: to add additional configuration to the CouchDB configuration
- `couchdb_config_peruser_enabled`: to enable per-user configuration in CouchDB | default is `true`.
- `couchdb_config_require_valid_user_except_for_up`: to require a valid user for all requests except for the `_up` endpoint | default is `true`.
- `couchdb_container_additional_networks_custom`: to add additional networks to the CouchDB container.
- `couchdb_version`: to specify the version of the CouchDB Docker image to use

For more information on possible configuration, refer to the comments in the `defaults/main.yml` file in this role.

By default, this role will not expose the CouchDB port to the host machine. If you want to access CouchDB from outside the Docker container, you will need to expose the port in your playbook via the `couchdb_container_http_host_bind_port` variable. Or you can just add the container to another docker network via the `couchdb_container_additional_networks_custom` variable.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter any problems or have any questions, please open an issue on GitHub.
