# Contributing to Pigsty

Welcome to Pigsty! We're excited that you're interested in contributing.

Pigsty is an open-source, cloud-neutral, local-first PostgreSQL distribution that delivers production-ready database clusters.
Your contributions help make PostgreSQL more accessible and powerful for everyone.

## Getting Started

Pigsty uses a 4-node sandbox environment based on EL9 (Rocky Linux 9) as the default testing environment.
You can set up this environment using either **Vagrant** or **Terraform**.

```bash
cd ~/pigsty
make full9
./configure -c ha/full
./deploy.yml
```

Check https://pigsty.io/docs/setup/ for details.


## Ways to Contribute

There are many ways to contribute to Pigsty, regardless of your experience level:

### Report Bugs & Request Features

- Search [existing issues](https://github.com/pgsty/pigsty/issues) first to avoid duplicates
- Use the issue templates when available
- Provide detailed reproduction steps for bugs
- Include your Pigsty version, OS version, and relevant configuration

### Improve Documentation

- Fix typos, clarify explanations, or add examples
- Documentation issues should be submitted to [pgsty/pigsty.io](https://github.com/pgsty/pigsty.io/issues) (EN) / [pgsty/pigsty.cc](https://github.com/pgsty/pigsty.cc/issues) (ZH)
- Translations are welcome

### Design Config Templates

If your scenario isn't covered by existing config templates, consider creating a new one.
Templates are located in the `conf/` directory:

```
conf/
├── meta.yml          # Default 1-node template
├── rich.yml          # Feature-rich with minio & examples
├── slim.yml          # Minimal installation
├── citus.yml         # Distributed PostgreSQL
├── supabase.yml      # Supabase self-hosting
├── ha/
│   ├── dual.yml      # 2-node HA
│   ├── trio.yml      # 3-node HA
│   ├── full.yml      # 4-node sandbox
│   └── safe.yml      # Security enhanced
└── ...
```

You can create templates for specific use cases: exotic kernels, special hardware, cloud providers, or industry scenarios.

### Add Docker App Templates

The `app/` directory contains Docker Compose templates for applications that work well with PostgreSQL.
You can contribute new templates for popular software:

```
app/
├── supabase/    # Firebase alternative
├── ferretdb/    # MongoDB alternative
├── bytebase/    # DDL migration tool
├── gitea/       # Git service
├── nocodb/      # Airtable alternative
├── dify/        # AI workflow platform
└── ...
```

To add a new app template:
1. Create a new directory under `app/`
2. Add a `docker-compose.yml` and `README.md`
3. Ensure it integrates well with Pigsty's PostgreSQL clusters
4. Submit a pull request

### Contribute Grafana Dashboards

Dashboards are located in `files/grafana/` with subdirectories for each module (pgsql, node, infra, redis, etc.).

To develop and test dashboards:

```bash
export GRAFANA_ENDPOINT=http://10.10.10.10:3000/ui # your grafana endpoint
make di    # dashboard-init: load dashboards to grafana
make dd    # dashboard-dump: dump dashboards from grafana
```

Edit dashboards in Grafana UI, then use `make dd` to export changes back to JSON files.

### Contribute Roles & Playbooks

If you believe a new Ansible role or playbook would benefit other users, consider contributing it.
Roles are located in the `roles/` directory:

```
roles/
├── pgsql/        # PostgreSQL cluster provisioning
├── node/         # Host provisioning and tuning
├── infra/        # Monitoring infrastructure
├── etcd/         # DCS for HA consensus
├── redis/        # Redis cluster deployment
├── minio/        # S3-compatible object storage
└── ...
```

New modules should follow existing patterns and include proper documentation.

### Contribute Code

- Bug fixes and feature implementations are welcome
- Follow the existing code style and conventions
- Test your changes thoroughly before submitting
- Keep changes focused and atomic

### Supported Platforms

When contributing code, please ensure compatibility with:

- **OS**: Ubuntu 22/24, Debian 12/13, EL 9/10
- **Arch**: Linux x86_64, ARM64
- **PostgreSQL**: 14, 15, 16, 17, 18
- **Ansible**: 2.9 - 2.19+



## Communication Guidelines

### Before Submitting Issues

1. Check the [FAQ](https://pigsty.io/docs/setup/faq) and [documentation](https://pigsty.io/docs)
2. Search [existing issues](https://github.com/pgsty/pigsty/issues) and [discussions](https://github.com/orgs/pgsty/discussions)
3. Provide sufficient information (see [community help guide](https://github.com/pgsty/pigsty/discussions/338))

### For Significant Changes

If you're planning significant modifications to the system, please discuss first in [GitHub Discussions](https://github.com/orgs/pgsty/discussions) 
before investing significant effort. This helps ensure your contribution aligns with the project's direction.

### Related Repositories

Different types of issues should be submitted to the appropriate repository:

| Topic                 | Repository                                                             |
|-----------------------|------------------------------------------------------------------------|
| Pigsty core           | [pgsty/pigsty](https://github.com/pgsty/pigsty/issues)                 |
| English documentation | [pgsty/pigsty.io](https://github.com/pgsty/pigsty.io/issues)           |
| Chinese documentation | [pgsty/pigsty.cc](https://github.com/pgsty/pigsty.cc/issues)           |
| PostgreSQL extensions | [pgsty/pig](https://github.com/pgsty/pig/issues)                       |
| Monitoring exporter   | [pgsty/pg_exporter](https://github.com/pgsty/pg_exporter/issues)       |

### Community Channels

- **GitHub Discussions**: [https://github.com/orgs/pgsty/discussions](https://github.com/orgs/pgsty/discussions)
- **Telegram**: [https://t.me/joinchat/gV9zfZraNPM3YjFh](https://t.me/joinchat/gV9zfZraNPM3YjFh)
- **Discord**: [https://discord.gg/j5pG8qfKxU](https://discord.gg/j5pG8qfKxU)
- **WeChat**: Search "pigsty-cc" to join Chinese community groups
- **Email**: rh@vonng.com



## Pull Request Process

1. Fork the repository and create your branch from `main`
2. Make your changes with clear, descriptive commits
3. Test your changes in the sandbox environment
4. Update documentation if needed
5. Submit a pull request with a clear description of changes

**Important**: Always use versioned [releases](https://github.com/pgsty/pigsty/releases) for production. The `main` branch is for development.


## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow


## License

By contributing to Pigsty, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).


## Thank You!

Every contribution matters - whether it's a bug report, documentation fix, feature suggestion, or code contribution.
Your involvement helps make Pigsty better for the entire PostgreSQL community.

We appreciate your time and effort in making Pigsty a better project!

If you have any questions, don't hesitate to reach out through our community channels.

**Happy hacking!**
