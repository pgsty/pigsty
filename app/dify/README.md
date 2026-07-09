# Dify

Dify: https://dify.ai/

The Innovation Engine for GenAI Applications, Dify is an open-source LLM app development platform. Orchestrate LLM apps from agents to complex AI workflows, with an RAG engine.

- Last verified with Dify v1.15.0 on 2026-07-09.
- Includes a PostgreSQL 18 compatibility patch for Dify's current `uuidv7()` migration script.
- [Self-Hosting Dify](https://pigsty.io/docs/app/dify)
- [GitHub: langgenius/Dify](https://github.com/langgenius/dify/)
- [Pigsty: Dify Docker Compose Template](https://github.com/pgsty/pigsty/tree/master/app/dify)


```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
cd ~/pigsty
./bootstrap               # prepare local repo & ansible
./configure -c app/dify   # IMPORTANT: CHANGE CREDENTIALS!!
./deploy.yml              # install pigsty & pgsql
./docker.yml              # install docker & docker-compose
./app.yml                 # install dify with docker compose
```

------

## Get Started

Define & Create required PostgreSQL and Docker resources with Pigsty:

```yaml
all:
  children:

    # the dify application
    dify:
      hosts: { 10.10.10.10: {} }
      vars:
        app: dify   # specify app name to be installed (in the apps)
        apps:       # define all applications
          dify:     # app name, should have corresponding ~/app/dify folder
            conf:   # override /opt/dify/.env config file
              # A secret key for signing and encryption, gen with `openssl rand -base64 42` (CHANGE PASSWORD!)
              SECRET_KEY: sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U
              DIFY_DATA: /data/dify
              COMPOSE_PROFILES: collaboration
              NEXT_PUBLIC_SOCKET_URL: ws://dify.pigsty
              TRIGGER_URL: http://dify.pigsty
              ENDPOINT_URL_TEMPLATE: http://dify.pigsty/e/{hook_id}
              DB_TYPE: postgresql
              DB_USERNAME: dify
              DB_PASSWORD: difyai123456
              DB_HOST: 10.10.10.10
              DB_PORT: 5432
              DB_DATABASE: dify
              DB_SSL_MODE: disable
              VECTOR_STORE: pgvector
              PGVECTOR_HOST: 10.10.10.10
              PGVECTOR_PORT: 5432
              PGVECTOR_USER: dify
              PGVECTOR_PASSWORD: difyai123456
              PGVECTOR_DATABASE: dify
              PGVECTOR_MIN_CONNECTION: 2
              PGVECTOR_MAX_CONNECTION: 10
              NGINX_SERVER_NAME: localhost
              DIFY_PORT: 5001 # expose DIFY nginx service with port 5001 by default
              #STORAGE_TYPE: s3
              #S3_ENDPOINT: 'https://sss.pigsty'
              #S3_BUCKET_NAME: 'dify'
              #S3_ACCESS_KEY: 'dify'
              #S3_SECRET_KEY: 'S3User.Dify'
              #S3_REGION: 'us-east-1'
              #S3_ADDRESS_STYLE: 'path'

    pg-meta:
      hosts: { 10.10.10.10: { pg_seq: 1, pg_role: primary } }
      vars:
        pg_cluster: pg-meta
        pg_extensions: [ pgvector ]
        pg_users:
          - { name: dify ,password: difyai123456 ,pgbouncer: true ,roles: [ dbrole_admin ] ,superuser: true ,comment: dify superuser }
        pg_databases:
          - { name: dify        ,owner: dify ,extensions: [ { name: vector } ] ,comment: dify main database  }
          - { name: dify_plugin ,owner: dify ,comment: dify plugin daemon database }
        pg_hba_rules:
          - { user: dify ,db: all ,addr: 172.16.0.0/12  ,auth: pwd ,title: 'allow dify access from local docker networks' }
          - { user: dbuser_view , db: all ,addr: infra ,auth: pwd ,title: 'allow grafana dashboard access cmdb from infra nodes' }
    
    infra: { hosts: { 10.10.10.10: { infra_seq: 1 } } }
    etcd:  { hosts: { 10.10.10.10: { etcd_seq: 1 } }, vars: { etcd_cluster: etcd } }
    #minio: { hosts: { 10.10.10.10: { minio_seq: 1 } }, vars: { minio_cluster: minio } }
```


------

## Expose Dify Web Service

Change `infra_portal` in `pigsty.yml`, with the new `dify` line:

```yaml
infra_portal:                     # infra services exposed via portal
  home : { domain: i.pigsty }     # default domain name
  
  dify         : { domain: dify.pigsty ,endpoint: "10.10.10.10:5001", websocket: true }
```

Then expose dify web service via Pigsty's Nginx server:

```bash
./infra.yml -t nginx
```

Don't forget to add `dify.pigsty` to your DNS or local `/etc/hosts` / `C:\Windows\System32\drivers\etc\hosts` to access via domain name.

If you are using a public domain, consider using [Certbot](https://pigsty.io/docs/infra/admin/cert) to get a free SSL certificate.

```bash
certbot --nginx --agree-tos --email your@email.com -n -d dify.your.domain    # replace with your email & dify domain
```

Then add `certbot` field to the `dify` entry:

```yaml
infra_portal:
  #...
  dify : { domain: dify.pigsty.cc ,endpoint: "10.10.10.10:5001", websocket: true , certbot: 'dify.pigsty.cc' }
```

To take over nginx config back to pigsty:

```bash
./infra.yml -t nginx_config     # regenerate nginx config align with certbot modification
```

## Upgrade Notes

Dify v1.15.0 includes database migrations and a required plugin auto-upgrade backfill. Before upgrading an existing deployment, verify that the Pigsty PostgreSQL backup is recent, back up `/data/dify`, and then run the Dify upgrade commands after containers are updated:

```bash
docker compose exec api flask db upgrade
docker compose exec api flask backfill-plugin-auto-upgrade
```

The Pigsty template keeps PostgreSQL and pgvector external. MinIO/S3 storage remains opt-in; do not point Dify at the pgBackRest backup bucket unless that is intentional.
