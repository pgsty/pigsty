# Pigsty Production Environment - Claude Code Guide

Pigsty v4.1.0 | PostgreSQL RDS/DBaaS | Apache-2.0
- EN Docs: https://pigsty.io/docs
- CN Docs: https://pigsty.cc/docs
- Expert Support: https://pigsty.io/price (rh@vonng.com)

---

## Important Files

**`pigsty.yml`**, source of truth of this deployment, always read it to understand current environment.
Sometimes the real state may drift from the config file, especially after manual changes / failover. trust by verify.

**`files/pki/ca/ca.key`** - highly sensitive CA private key. Keep it safe, never share it, don't lose it.

If `pig` cli is available, you can use it to perform operation command with caution. https://pigsty.io/docs/pig


---

## Standard Operating Procedures

### Before Any Change

1. **Identify scope:** Which cluster? Which nodes?
2. **Check current state:** `pig pg list`, system status
3. **Verify backup:** `pig pb info` - is backup recent?
4. **Dry run first:** Add `--check` to playbook

### For Dangerous Operations

1. **Confirm with user** - even in YOLO mode
2. **Verify backup exists and is recent**
3. **Ask user to type exact target name**
4. **Execute with explicit `-l` limit flag**

### Incident Response

1. Read logs first, understand the situation, you can get it from `/pg/log`, or query victorialogs API
2. Check Patroni/HA status
3. Do NOT take any action without user confirmation
4. Recommend rollback/recovery options before executing

---

## Permission Boundaries

### ALWAYS ALLOWED (No confirmation needed)

**Read-only operations:**
- Read `pigsty.yml` configuration file
- Read Ansible inventory and playbook files
- Read system monitoring metrics (CPU, memory, disk, network)
- Read PostgreSQL/Patroni cluster status via `pg list`, `patronictl`
- Read backup status via `pb info`, `pgbackrest info`
- Read service status via `systemctl status`
- Read logs: `/pg/log/`, system journal, nginx access logs
- Query monitoring dashboards and Grafana metrics
- Dry-run playbooks with `--check` flag
- Read extension catalog and documentation

**Diagnostic commands:**
- `pig pg list <cluster>` - Patroni cluster status
- `pig pb info` - Backup information
- System health: `df`, `free`, `uptime`, `ps`, `top`, etc.


---

### REQUIRES USER CONFIRMATION (Always ask first)

**Cluster lifecycle operations:**
- `pgsql.yml` - Initialize PostgreSQL cluster
- `pgsql-user.yml` - Create/modify users
- `pgsql-db.yml` - Create/modify databases
- `node.yml` - Provision nodes
- `infra.yml` - Deploy infrastructure
- Any playbook execution without `--check`

**Configuration changes:**
- Modify `pigsty.yml`
- Change `pg_hba.conf` or HBA rules
- Modify PostgreSQL parameters
- Change Patroni configuration
- Update haproxy/vip configuration

**Service operations:**
- Restart PostgreSQL/Patroni services
- Reload configuration (`pg_reload_conf()`)
- Switchover primary/replica (`pg switchover`)
- Backup execution (`pg-backup`)

---

### FORBIDDEN - ALWAYS ASK (Even in YOLO mode)

**Destructive operations - require explicit confirmation + backup verification:**

Running Ansible playbooks, especially init/remove playbooks, always requires explicit user consent and permission, even in YOLO mode. Improper use may cause data loss! Your policy should be deny-by-default unless the user explicitly authorizes and requests. If you believe the user doesn't fully understand what they're doing, you should pause execution, explain and clarify further, and only proceed after confirming the user truly understands what they're about to do.

```
NEVER execute without user saying "yes, I confirm":

- pgsql-rm.yml      # Remove PostgreSQL cluster
- node-rm.yml       # Remove node from cluster
- infra-rm.yml      # Remove infrastructure
- redis-rm.yml      # Remove Redis cluster
- etcd-rm.yml       # Remove etcd cluster
- minio-rm.yml      # Remove MinIO cluster

- DROP DATABASE     # Delete database
- DROP TABLE        # Delete table
- TRUNCATE          # Clear table data
- DELETE without WHERE  # Mass deletion

- rm -rf /pg/*      # Delete data directories
- rm -rf ~/pigsty   # Delete Pigsty installation
- rm pigsty.yml     # Delete configuration
- rm -rf files/pki  # Delete PKI certificates

- patronictl remove # Remove cluster member
- pg_ctl stop -m immediate  # Force stop
```

**Must verify before any destructive operation:**
1. Ask: "Which cluster/database/table?"
2. Ask: "Do you have a recent backup?"
3. Ask: "Type the exact name to confirm"

---

### BUSINESS DATA - RESTRICTED ACCESS

**Default policy: DO NOT read business data without permission**

You may NOT execute these without explicit user consent:
- `SELECT * FROM <user_tables>`
- Read application data tables
- Export or dump business data
- Access data in `/pg/data/` directly

**Allowed for diagnostics (system tables only):**
- `pg_stat_*` views
- `pg_catalog.*` system catalogs
- `information_schema.*`
- Extension metadata tables

**If user needs data analysis:**
1. Ask which tables/data are needed
2. Confirm user authorizes access
3. Limit query scope (use LIMIT, specific columns)
4. Never store or transmit sensitive data

---

## Documentation Index

- English: https://pigsty.io/docs
- Chinese: https://pigsty.cc/docs

Use pigsty.io for English queries, pigsty.cc for Chinese queries.

---

### About `/docs/about/`
Project information including features, history, licensing, roadmap, and community resources.

- `feature.md` - Complete feature overview and capabilities of Pigsty
- `history.md` - Project history and version evolution
- `license.md` - Apache 2.0 licensing information and terms
- `roadmap.md` - Future development plans and upcoming features
- `case.md` - Real-world use cases and success stories
- `community.md` - Community resources, discussions, and contribution guidelines
- `compare/` - Comparisons with other database solutions and cloud RDS offerings

---

### Concept `/docs/concept/`
Core concepts explaining Pigsty's architecture, high availability design, backup/recovery mechanisms, and security compliance. Essential reading for understanding how Pigsty works under the hood.

- `arch/` - System architecture documentation covering PostgreSQL cluster design, node topology, and infrastructure components
- `model/` - Cluster model definitions for each module type (pgsql, infra, etcd, redis, minio)
- `iac/` - Infrastructure as Code principles and implementation
  - `inventory.md` - Ansible inventory structure and how to define your infrastructure
  - `parameter.md` - Parameter hierarchy and precedence rules
  - `configure.md` - Configuration generation process using the configure script
- `ha/` - High availability concepts and implementation details
  - `rto.md` - Recovery Time Objective analysis and guarantees
  - `rpo.md` - Recovery Point Objective and data loss prevention
  - `failure/` - Failure scenario handling (active failures, passive failures, manual intervention, network partitions)
- `pitr/` - Point-in-time recovery concepts and how pgBackRest enables time-travel for your data
- `sec/` - Security architecture including access control levels, CA/PKI infrastructure, and authentication mechanisms
- `monitor.md` - Observability stack design with VictoriaMetrics, Grafana, and alerting

---

### Setup `/docs/setup/`
Quick start guide for single-node deployments. Follow these docs to get Pigsty running on your laptop or a single server within minutes.

- `install.md` - Standard installation procedure with online package downloads
- `offline.md` - Air-gapped installation using pre-downloaded offline packages
- `slim.md` - Minimal installation without full monitoring stack for resource-constrained environments
- `config.md` - Configuration walkthrough explaining key parameters to customize
- `playbook.md` - How to execute Ansible playbooks and understand their output
- `security.md` - Security considerations for initial deployment
- `webui.md` - Accessing Grafana dashboards, Prometheus, and other web interfaces
- `pgsql.md` - Connecting to PostgreSQL using psql, pgAdmin, and application drivers
- `docker.md` - Alternative Docker-based deployment method

---

### Deploy `/docs/deploy/`
Production deployment guide for multi-node, highly available clusters. Use these docs when deploying Pigsty in serious production environments.

- `planning.md` - Architecture planning including node sizing, network topology, and resource allocation
- `prepare.md` - Pre-deployment checklist covering OS preparation, SSH access, and privilege requirements
- `install.md` - Step-by-step production installation with HA PostgreSQL clusters
- `sandbox.md` - Setting up sandbox environments for testing and development
- `vagrant.md` - Vagrant templates for local multi-node testing clusters
- `terraform.md` - Terraform templates for cloud infrastructure provisioning (AWS, GCP, Azure)
- `admin.md` - Admin node setup and configuration management best practices
- `security.md` - Production security hardening including SSL/TLS, firewall rules, and access controls

---

### Reference `/docs/ref/`
Quick reference documentation for looking up specific technical details. Bookmark these pages for day-to-day operations.

- `linux.md` - Supported Linux distributions and version compatibility matrix
- `module.md` - Complete module reference with dependencies and relationships
- `param.md` - Comprehensive parameter reference listing all configuration options with defaults and descriptions
- `playbook.md` - Ansible playbook reference with all available playbooks, tags, and execution examples
- `port.md` - Port allocation table showing all services and their default ports
- `fhs.md` - Filesystem hierarchy standard explaining directory structure and file locations
- `extension.md` - Complete catalog of 451+ PostgreSQL extensions with installation instructions

---

### Apps `/docs/app/`
Application templates for deploying containerized software on top of Pigsty infrastructure. Each app comes with Docker Compose configuration and integration guides.

- `nocodb.md`, `teable.md` - No-code database platforms for building applications without programming
- `gitea.md` - Self-hosted Git service similar to GitHub/GitLab
- `wiki.md` - Wiki and documentation platforms
- `mattermost.md` - Team collaboration and messaging platform
- `maybe.md` - Personal finance management application
- `metabase.md` - Business intelligence and analytics dashboard
- `kong.md` - API gateway for microservices architecture
- `jupyter.md` - Jupyter Notebook for data science and machine learning
- `bytebase.md` - Database DevOps and schema migration platform
- `pgadmin.md` - PostgreSQL graphical administration tool
- `supabase.md` - Open source Firebase alternative backend platform

---

### Templates `/docs/conf/`
Ready-to-use configuration templates for various deployment scenarios. Copy and customize these for your specific needs.

**Single-node templates:** `meta.md`, `rich.md`, `fat.md`, `slim.md`, `infra.md` - Various single-node configurations from minimal to feature-rich
**Kernel templates:** `pgsql.md`, `citus.md`, `polar.md`, `oriole.md`, `mysql.md`, `mssql.md` - Templates for different PostgreSQL variants and compatibility layers
**HA templates:** `dual.md`, `trio.md`, `full.md`, `safe.md`, `simu.md` - Multi-node high availability configurations from 2-node to full production
**Application templates:** `odoo.md`, `dify.md`, `teable.md`, `supabase.md`, `registry.md` - Pre-configured templates for specific applications
**Demo templates:** `demo.md`, `el.md`, `debian.md`, `oss.md`, `minio.md` - Demonstration and testing configurations

---

### PGSQL Module `/docs/pgsql/`
The core PostgreSQL module documentation. This is the most important section for database administrators managing PostgreSQL clusters with Pigsty.

#### Config `/docs/pgsql/config/`
Cluster configuration and definition. Learn how to declare PostgreSQL clusters, users, databases, and access rules in pigsty.yml.

- `cluster.md` - Cluster topology definition including primary, replicas, and instance placement
- `kernel.md` - PostgreSQL kernel version selection and variant configuration
- `user.md` - User and role definitions with privilege management
- `db.md` - Database definitions including templates, extensions, and schemas
- `hba.md` - Host-based authentication rules controlling client access
- `acl.md` - Fine-grained access control lists for database objects
- `alias.md` - SQL command aliases for convenience

#### Service `/docs/pgsql/service/`
Service exposure and access patterns. Explains how clients connect to PostgreSQL through HAProxy, VIP, and DNS.

#### Security `/docs/pgsql/security/`
PostgreSQL security configuration including SSL/TLS, authentication methods, and encryption.

#### Admin `/docs/pgsql/admin/`
Day-to-day administration operations. The essential guide for cluster lifecycle management.

- `cluster.md` - Cluster lifecycle management including creation, scaling, and removal procedures
- `user.md` - Runtime user management with CREATE/ALTER/DROP operations
- `db.md` - Database administration including creation, configuration, and maintenance
- `hba.md` - HBA rule management and reload procedures
- `upgrade.md` - PostgreSQL major and minor version upgrade procedures
- `component.md` - Managing cluster components (Patroni, pgBouncer, HAProxy)
- `monitor.md` - Monitoring configuration and troubleshooting
- `patroni.md` - Patroni-specific operations including switchover, failover, and maintenance mode
- `pgbackrest.md` - Backup administration with pgBackRest commands and scheduling
- `pgbouncer.md` - Connection pooler management and configuration
- `ext.md` - Extension management including installation, updates, and removal
- `crontab.md` - Scheduled task configuration for maintenance operations

#### Backup `/docs/pgsql/backup/`
Backup and recovery operations with pgBackRest. Critical documentation for data protection.

- `mechanism.md` - How PostgreSQL backup works including WAL archiving and base backups
- `policy.md` - Backup retention policies and scheduling strategies
- `repository.md` - Backup repository configuration for local, S3, and MinIO storage
- `admin.md` - Backup administration commands and monitoring
- `restore.md` - Point-in-time recovery procedures and disaster recovery
- `cluster.md` - Cluster-level backup coordination and consistency

#### Migration `/docs/pgsql/migration/`
Data migration guides for moving data between PostgreSQL versions and from other databases.

#### Tutorial `/docs/pgsql/tutorial/`
Hands-on tutorials for common operational tasks. Step-by-step guides with real examples.

- `drill.md` - Operational drills for practicing failover and recovery
- `drop.md` - Safe procedures for dropping databases, tables, and clusters
- `failure.md` - Failure scenario handling and recovery procedures
- `pitr.md` - Point-in-time recovery tutorial with practical examples
- `hugepage.md` - Linux huge pages configuration for improved performance
- `pg-fork.md` - Using PostgreSQL forks and variants (Citus, PolarDB, etc.)
- `pg-vip.md` - Virtual IP configuration for high availability
- `citus.md` - Citus distributed PostgreSQL setup and operations

#### Monitor `/docs/pgsql/monitor/`
Monitoring system configuration and dashboard usage.

- `dashboard.md` - Overview of available Grafana dashboards
- `dashboard/overview/` - System-wide overview dashboards
- `dashboard/cluster/` - Cluster-level monitoring dashboards
- `dashboard/instance/` - Instance-level detailed metrics
- `dashboard/database/` - Database-specific performance dashboards

#### Param `/docs/pgsql/param/`
Complete PGSQL module parameter reference. All configuration options with descriptions and defaults.

#### Ext `/docs/pgsql/ext/`
PostgreSQL extension management. Pigsty supports 451+ extensions out of the box.

- `start.md` - Quick start guide for extension installation
- `intro.md` - Introduction to PostgreSQL extension ecosystem
- `pkg.md` - Extension packaging and distribution
- `download.md` - Downloading extensions from repositories
- `install.md` - Installing extensions on PostgreSQL clusters
- `config.md` - Configuring extensions with shared_preload_libraries and other settings
- `create.md` - Creating extensions in databases with CREATE EXTENSION
- `extension.md` - Detailed extension catalog and compatibility information
- `repo.md` - Extension repository management
- `remove.md` - Safely removing extensions from databases
- `update.md` - Updating extensions to newer versions

#### Template `/docs/pgsql/template/`
Performance tuning templates for different workload types.

- `oltp.md` - OLTP template optimized for transactional workloads with low latency
- `olap.md` - OLAP template optimized for analytical queries and large scans
- `crit.md` - Critical/financial template with maximum durability and consistency
- `tiny.md` - Tiny instance template for development and resource-constrained environments
- `tune.md` - Manual tuning guide for custom performance optimization

#### Kernel `/docs/pgsql/kernel/`
PostgreSQL kernel variants and forks supported by Pigsty.

- `postgres.md` - Vanilla PostgreSQL from the official PostgreSQL Global Development Group
- `citus.md` - Citus distributed PostgreSQL for horizontal scaling
- `babelfish.md` - WiltonDB/Babelfish for SQL Server protocol compatibility
- `ivorysql.md` - IvorySQL with Oracle PL/SQL compatibility
- `openhalo.md` - OpenHalo distributed database
- `percona.md` - Percona Distribution for PostgreSQL with enterprise features
- `orioledb.md` - OrioleDB with cloud-native storage engine
- `polardb.md` - Alibaba PolarDB for PostgreSQL
- `polardb-o.md` - PolarDB with Oracle compatibility
- `pgml.md` - PostgresML for machine learning workloads
- `supabase.md` - Supabase PostgreSQL configuration
- `greenplum.md` - Greenplum massively parallel processing database
- `cloudberry.md` - Cloudberry Database (Greenplum fork)
- `neon.md` - Neon serverless PostgreSQL

#### Misc `/docs/pgsql/misc/`
Additional detailed documentation on specific topics.

- `user.md` - In-depth user and role management guide
- `db.md` - Comprehensive database management documentation
- `acl.md` - Detailed access control list configuration
- `hba.md` - Complete HBA rule syntax and examples
- `svc.md` - Service configuration and load balancing details

#### Other PGSQL Files
- `playbook.md` - PGSQL module playbook reference
- `metric.md` - PostgreSQL metrics and monitoring indicators
- `faq.md` - Frequently asked questions and troubleshooting

---

### INFRA Module `/docs/infra/`
Infrastructure module providing DNS, NTP, Nginx reverse proxy, package repository, and the complete observability stack (VictoriaMetrics, Grafana, AlertManager).

- `admin/` - Infrastructure administration (certificates, Grafana, Nginx, package repo management)
- `config.md` - INFRA module configuration options
- `param.md` - Complete parameter reference for infrastructure components
- `playbook.md` - Infrastructure playbooks for deployment and maintenance
- `monitor.md` - Monitoring stack configuration and dashboard access
- `faq.md` - Common infrastructure issues and solutions

---

### NODE Module `/docs/node/`
Node provisioning module for host configuration, VIP management, HAProxy load balancing, and node_exporter metrics collection.

- `admin.md` - Node administration including adding, removing, and reconfiguring hosts
- `config.md` - Node configuration options and tuning parameters
- `param.md` - Complete node parameter reference
- `playbook.md` - Node provisioning playbooks
- `monitor.md` - Node monitoring and alerting configuration
- `metric.md` - Node metrics collected by node_exporter

---

### ETCD Module `/docs/etcd/`
Distributed consensus store module. ETCD serves as the Distributed Configuration Store (DCS) for Patroni, enabling PostgreSQL high availability with automatic failover.

- `admin.md` - ETCD cluster administration including member management and maintenance
- `config.md` - ETCD configuration options and cluster topology
- `param.md` - Complete ETCD parameter reference
- `playbook.md` - ETCD deployment and maintenance playbooks
- `monitor.md` - ETCD monitoring and health checks

---

### MINIO Module `/docs/minio/`
S3-compatible object storage module. MinIO serves as the backup repository for pgBackRest, enabling off-site backup storage and cross-cluster backup sharing.

- `admin.md` - MinIO cluster administration and bucket management
- `config.md` - MinIO configuration for single-node and multi-node deployments
- `param.md` - Complete MinIO parameter reference
- `usage.md` - Using MinIO with pgBackRest and other applications
- `monitor.md` - MinIO monitoring and performance metrics
- `faq.md` - Common MinIO issues and solutions

---

### REDIS Module `/docs/redis/`
Redis caching module supporting standalone, master-slave replication, sentinel, and cluster deployment modes.

- `admin.md` - Redis administration including cluster management and failover
- `config.md` - Redis configuration for different deployment modes
- `param.md` - Complete Redis parameter reference
- `monitor.md` - Redis monitoring and performance metrics
- `faq.md` - Common Redis issues and troubleshooting

---

### FERRET Module `/docs/ferret/`
FerretDB module providing MongoDB wire protocol compatibility layer on top of PostgreSQL. Allows MongoDB applications to use PostgreSQL as the backend.

- `admin.md` - FerretDB administration and connection management
- `config.md` - FerretDB configuration and PostgreSQL integration

---

### DOCKER Module `/docs/docker/`
Docker runtime module for deploying containerized applications alongside Pigsty infrastructure.

- `usage.md` - Docker usage guide and container management
- `playbook.md` - Docker deployment playbooks
- `param.md` - Docker module parameters
- `faq.md` - Common Docker issues and solutions

---

### PIG `/docs/pig/`
PIG package manager for PostgreSQL extensions. Command-line tool for discovering, installing, and managing the 451+ extensions available in the Pigsty ecosystem.

---

### Repo `/docs/repo/`
Software repository documentation covering the package infrastructure that delivers PostgreSQL, extensions, and system packages.

- `pgsql/` - PostgreSQL package repository (deb.md for Debian/Ubuntu, rpm.md for RHEL/Rocky)
- `infra/` - Infrastructure package repository
- `gpg.md` - GPG key management for package signing and verification

---

### Other Modules (Experimental)
Additional experimental and internal modules not recommended for production use without thorough testing.

- `pilot/` - Experimental module integrations (Kafka, MySQL, DuckDB, Kubernetes, Consul, etc.)
- `pg_exporter/` - Standalone PostgreSQL metrics exporter for external PostgreSQL instances
- `piglet/` - Lightweight Pigsty variant for minimal deployments
- `juice/`, `vibe/` - Internal development modules
