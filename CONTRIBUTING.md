# Contributing to Pigsty

Welcome to Pigsty! We're excited that you're interested in contributing.

Pigsty is an open-source, cloud-neutral, local-first PostgreSQL distribution that delivers production-ready database clusters.
Your feedback and ideas help make PostgreSQL more accessible and powerful for everyone.


## Ways to Contribute

### Report Bugs

- Search [existing issues](https://github.com/pgsty/pigsty/issues) first to avoid duplicates
- Provide detailed reproduction steps
- Include your Pigsty version, OS version, and relevant configuration
- Attach logs and error messages when applicable

### Request Features

- Describe your use case and why the feature would be valuable
- Explain your current workaround (if any)
- Be specific about expected behavior

### Suggest Extensions

Pigsty supports 400+ PostgreSQL extensions. If you need an extension that's not included:

- Open an issue describing the extension and your use case
- Include links to the extension's repository/documentation
- Specify which PostgreSQL versions you need it for

### Propose Config Templates

If your scenario isn't covered by existing templates in the `conf/` directory, we'd love to hear about it:

- Target environment (cloud provider, hardware specs, OS)
- Workload characteristics (OLTP, OLAP, mixed)
- Special requirements (compliance, performance, HA topology)

Good suggestions may be incorporated into future releases.

### Suggest Docker App Templates

The `app/` directory contains Docker Compose templates for applications that work well with PostgreSQL:

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

If you have ideas for new app templates, please open an issue with:

- The application name and what it does
- Why it pairs well with PostgreSQL
- Any specific configuration considerations
- Links to official documentation

### Suggest Grafana Dashboards

Dashboards are located in `files/grafana/` with subdirectories for each module (pgsql, node, infra, redis, etc.).

If you have ideas for new dashboards or improvements to existing ones, please describe them in an issue.

### Improve Documentation

- Report documentation issues to [pgsty/pigsty.io](https://github.com/pgsty/pigsty.io/issues) (EN) or [pgsty/pigsty.cc](https://github.com/pgsty/pigsty.cc/issues) (ZH)
- Suggest clarifications, point out outdated content, or propose examples
- Translation suggestions are appreciated


## Before Submitting

1. Check the [FAQ](https://pigsty.io/docs/setup/faq) and [documentation](https://pigsty.io/docs)
2. Search [existing issues](https://github.com/pgsty/pigsty/issues) and [discussions](https://github.com/orgs/pgsty/discussions)
3. Provide sufficient context (see [community help guide](https://github.com/pgsty/pigsty/discussions/338))

For code changes or significant contributions, please open an issue first to discuss.
This helps ensure alignment with the project's direction and avoids duplicated effort.


## Related Repositories

| Topic                        | Repository                                                             |
|------------------------------|------------------------------------------------------------------------|
| Pigsty core                  | [pgsty/pigsty](https://github.com/pgsty/pigsty/issues)                 |
| English documentation        | [pgsty/pigsty.io](https://github.com/pgsty/pigsty.io/issues)           |
| Chinese documentation        | [pgsty/pigsty.cc](https://github.com/pgsty/pigsty.cc/issues)           |
| PG CLI and Extension Manager | [pgsty/pig](https://github.com/pgsty/pig/issues)                       |
| PG Metrics Exporter          | [pgsty/pg_exporter](https://github.com/pgsty/pg_exporter/issues)       |


## Community Channels

- **GitHub Discussions**: [https://github.com/orgs/pgsty/discussions](https://github.com/orgs/pgsty/discussions)
- **Telegram**: [https://t.me/joinchat/gV9zfZraNPM3YjFh](https://t.me/joinchat/gV9zfZraNPM3YjFh)
- **Discord**: [https://discord.gg/j5pG8qfKxU](https://discord.gg/j5pG8qfKxU)
- **WeChat**: Search "pigsty-cc" to join wechat community groups
- **QQ Group**: 619377403 / PG
- **Email**: rh@vonng.com


## License

Pigsty is licensed under the [Apache License 2.0](LICENSE).


## Thank You

Your feedback, ideas, and bug reports genuinely help improve Pigsty.
We read every issue and discussion, and good suggestions often make it into future releases.

If you have questions, don't hesitate to reach out through the community channels above.
