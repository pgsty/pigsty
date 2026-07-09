# Security Policy

Pigsty is a PostgreSQL distribution and deployment framework. This policy
explains how to report security issues, which versions receive fixes, and
where Pigsty's responsibility begins and ends.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
discussions, pull requests, or social media.**

Use one of these private channels instead:

1. **GitHub Private Vulnerability Reporting** (preferred):
   [Report a vulnerability](https://github.com/pgsty/pigsty/security/advisories/new)
   on the `pgsty/pigsty` repository.
2. **Email**: [rh@vonng.com](mailto:rh@vonng.com) or [ron@pgsty.com](mailto:ron@pgsty.com)

Include enough detail for us to reproduce and triage the issue:

- Affected Pigsty version, commit, package, or component
- Issue type and impact, such as privilege escalation, credential exposure,
  injection, insecure default configuration, or supply-chain risk
- Reproduction steps or a proof of concept, when available
- Required preconditions: network position, existing credentials, privileges,
  or configuration choices
- A suggested fix or mitigation, if you have one

Please redact passwords, tokens, private keys, CA material, and business or
customer data from your report. Do not send database dumps, backups, or full
`pigsty.yml` files unless we explicitly request them through a private channel.

### What to Expect

- We aim to acknowledge reports within **3 business days**.
- We aim to provide an initial assessment within **7 days**.
- We aim to coordinate disclosure within **90 days** where practical; issues
  requiring upstream coordination or package rebuilds may take longer.
- With your permission, we will credit you in the resulting advisory or
  release notes. We will not publish your name without consent.

Please keep vulnerability details private until a fix, mitigation, or
advisory has been published.

### Safe Harbor

We will not pursue legal action over research conducted in good faith, in
accordance with this policy, and against systems you own or are authorized
to test. Avoid privacy violations, data destruction, service disruption,
social engineering, and access to data that is not your own. If you
encounter sensitive data, stop and report it through a private channel.

Pigsty does not currently run a paid bug bounty program.

## Supported Versions

Security fixes land on the `main` branch and ship in the latest stable
release. Upgrading to the latest release is how you receive them.

| Version         | Status         |
|-----------------|----------------|
| Latest 4.x      | Supported      |
| Older 4.x       | Please upgrade |
| 3.x and earlier | End of life    |

Fixes are not backported to older or end-of-life versions in the open-source
distribution. If you need long-term maintenance for a pinned version,
extended support is available through
[Pigsty professional services](https://pigsty.io/price/).

## Scope

### In Scope

- Ansible playbooks, roles, templates, and scripts in this repository
- Configurations Pigsty generates for PostgreSQL, Patroni, pgBouncer,
  HAProxy, Nginx, etcd, MinIO, and other managed components
- Insecure Pigsty defaults that create unintended exposure or unsafe
  production behavior
- The Pigsty package repositories and distribution pipeline
  (`repo.pigsty.io` / `repo.pigsty.cc`): build, packaging, signing, and
  delivery
- Pigsty-built PostgreSQL extension packages, where the flaw lies in
  Pigsty's build, packaging, bundling, or distribution process
- Pigsty-specific patches and integration work in maintained forks
  (e.g., [pgsty/minio](https://github.com/pgsty/minio))

Reports concerning related Pigsty ecosystem projects, such as the
[`pig`](https://github.com/pgsty/pig) CLI, are welcome here if you are
unsure where they belong; we will route them to the appropriate repository.

### Upstream Components

Pigsty packages and orchestrates many upstream projects: PostgreSQL,
Patroni, pgBouncer, HAProxy, etcd, MinIO, Grafana, VictoriaMetrics,
Prometheus components, Ansible, and 500+ PostgreSQL extensions.
Vulnerabilities in upstream code should be reported to the upstream project
first. If an upstream vulnerability affects Pigsty deployments, please let
us know as well, so we can track it, rebuild packages, or ship mitigations.

| Component  | Report to                                                                                     |
|------------|-----------------------------------------------------------------------------------------------|
| PostgreSQL | [PostgreSQL Security](https://www.postgresql.org/support/security/) / security@postgresql.org |
| Grafana    | [Grafana security policy](https://github.com/grafana/grafana/security/policy)                 |
| etcd       | [etcd security policy](https://github.com/etcd-io/etcd/blob/main/security/README.md)          |
| Patroni    | [patroni/patroni](https://github.com/patroni/patroni)                                         |
| Others     | The respective upstream repository or vendor                                                  |

### PostgreSQL Extensions

Pigsty distributes 500+ PostgreSQL extensions, many of them built and
packaged by us. The dividing line:

- A flaw in an extension's **own code** should be reported to the extension's
  upstream project.
- A flaw in **how Pigsty builds, packages, bundles, signs, or distributes**
  an extension should be reported to us; this is in scope.
- Not sure which side it falls on? Report it to us privately and we will
  help route it.

### Not Considered Vulnerabilities

- **Documented placeholder credentials and self-signed certificates** in
  example, demo, or fresh local installations. Production and
  network-exposed deployments must change them before going live. See
  [Security Tips](https://pigsty.io/docs/setup/security/).
- Attacks requiring root access, admin-node or managed-node access, or
  possession of `pigsty.yml` / the CA private key. These are high-trust
  control surfaces by design and must be protected accordingly.
- Issues that only affect end-of-life versions.
- Denial of service against the public demo, project websites, or community
  infrastructure.
- Automated scanner output without a demonstrated, exploitable impact.

However, unintended exposure of real secrets, unsafe generated defaults,
unexpected network exposure, and reproducible denial-of-service flaws in
Pigsty-generated deployments may still qualify. When in doubt, report
privately.

## Security Advisories and Fixes

- Fixes normally ship in the next regular release; critical issues may
  trigger an out-of-band patch release or a mitigation notice.
- Advisories are published via
  [GitHub Security Advisories](https://github.com/pgsty/pigsty/security/advisories),
  with CVE IDs requested when applicable.
- When upstream components publish security fixes, Pigsty rebuilds packages,
  updates templates, or documents mitigations, depending on impact.

## Package Integrity

All RPM / DEB packages in the Pigsty online repositories are signed with GPG:

- Public key: <https://repo.pigsty.io/key> (mirror: <https://repo.pigsty.cc/key>)
- Fingerprint: `9592 A7BC 7A68 2E73 3337 6E09 E793 5D8D B9BD 8B20` (`B9BD8B20`)

Verify the fingerprint before trusting the key. Note that repository
definitions written by Pigsty during deployment, including the local
repository built on the infra node, do not enforce per-package signature
verification by default; review repository trust settings as part of
production hardening.

## Hardening Guidance

Pigsty defaults are designed for trusted internal environments. Production
or network-exposed deployments should follow the hardening documentation
before going live:

- [Security Tips](https://pigsty.io/docs/setup/security/)
- [Security Hardening](https://pigsty.io/docs/deploy/security/)
- [Security Model](https://pigsty.io/docs/concept/sec/level/)
- [`ha/safe` hardened config template](https://pigsty.io/docs/conf/safe/)

Thank you for helping keep Pigsty and its users safe.
