# App

Here are some docker compose templates for popular applications that works well with PostgreSQL

* [Supabase](supabase/) : The open source Firebase alternative, built on Postgres
* [FerretDB](ferretdb/) : Open Source MongoDB alternative, built on Postgres
* [PolarDB](polardb/) : Open Source RAC alternative, built on Postgres
* [PgAdmin4](pgadmin/) : Postgres Admin Tools
* [PgWeb](pgweb/) : Postgres Web Console
* [ByteBase](bytebase/) : Postgres DDL Migration
* [PostgREST](postgrest/) : Auto-Generated PG Backend REST API
* [Kong](kong/) : Kong API Gateway
* [Gitea](gitea/) : Self-Hosting Git Services
* [Wiki](wiki/) : Local Wiki Service
* [NocoDB](nocodb/) : Open source airtable alternative
* [Odoo](odoo/) : Open Source ERP
* [Dify](dify/) : Open Source AI Workflow Platform for GenAI Apps.
* [Metabase](metabase/) : Fast analytics with the friendly UX and integrated tooling
* [Jupyter](jupyter/) : Run jupyter notebook, the data analysis IDE with docker
* etc....


**Docker**

You can install docker with the [`docker.yml`](https://github.com/pgsty/pigsty/blob/master/docker.yml) playbook. 
If you wish to use a mirror, add them to `docker_registry_mirrors`. To use another registry: 

```bash
docker login quay.io
````


**Portals**

There are several predefined portals

```yaml
postgrest : { domain: api.pigsty  ,endpoint: "127.0.0.1:8884"   }
pgadmin   : { domain: adm.pigsty  ,endpoint: "127.0.0.1:8885"   }
pgweb     : { domain: cli.pigsty  ,endpoint: "127.0.0.1:8886"   }
bytebase  : { domain: ddl.pigsty  ,endpoint: "127.0.0.1:8887"   }
jupyter   : { domain: lab.pigsty  ,endpoint: "127.0.0.1:8888" ,websocket: true }
gitea     : { domain: git.pigsty  ,endpoint: "127.0.0.1:8889"   }
minio     : { domain: sss.pigsty  ,endpoint: "127.0.0.1:9000"   }
wiki      : { domain: wiki.pigsty ,endpoint: "127.0.0.1:9002"   }
noco      : { domain: noco.pigsty ,endpoint: "127.0.0.1:9003"   }
odoo      : { domain: odoo.pigsty ,endpoint: "127.0.0.1:8069" ,websocket: true }
supa      : { domain: supa.pigsty ,endpoint: "127.0.0.1:8000" ,websocket: true }
dify      : { domain: dify.pigsty ,endpoint: "127.0.0.1:8001" ,websocket: true }
```

**Pull Image**

```bash
docker pull dpage/pgadmin4
docker pull sosedoff/pgweb
docker pull vonng/pg_exporter
docker pull postgrest/postgrest
docker pull bytebase/bytebase
docker pull jupyter/minimal-notebook
#docker pull jupyter/scipy-notebook:latest 
docker pull alpine
docker pull registry
docker pull andrewjones/schemaspy-postgres
docker pull requarks/wiki
docker pull gitea/gitea
docker pull kong
docker pull odoo
docker pull quay.io/ferretdb/ferretdb
```


**Make Cache**

```bash
mkdir -p /tmp/docker
docker save dpage/pgadmin4                   | gzip -9 -c > /tmp/docker/pgadmin4.tgz
docker save sosedoff/pgweb                   | gzip -9 -c > /tmp/docker/pgweb.tgz
docker save vonng/pg_exporter                | gzip -9 -c > /tmp/docker/pg_exporter.tgz
docker save postgrest/postgrest              | gzip -9 -c > /tmp/docker/postgrest.tgz
docker save bytebase/bytebase                | gzip -9 -c > /tmp/docker/bytebase.tgz
docker save jupyter/minimal-notebook         | gzip -9 -c > /tmp/docker/jupyter.tgz
docker save alpine                           | gzip -9 -c > /tmp/docker/alpine.tgz
docker save registry                         | gzip -9 -c > /tmp/docker/registry.tgz
docker save andrewjones/schemaspy-postgres   | gzip -9 -c > /tmp/docker/schemaspy.tgz
docker save requarks/wiki                    | gzip -9 -c > /tmp/docker/wiki.tgz
docker save gitea/gitea                      | gzip -9 -c > /tmp/docker/gitea.tgz
docker save kong                             | gzip -9 -c > /tmp/docker/kong.tgz
docker save odoo                             | gzip -9 -c > /tmp/docker/odoo.tgz
docker save quay.io/ferretdb/ferretdb        | gzip -9 -c > /tmp/docker/ferretdb.tgz
docker save nocodb/nocodb                    | gzip -9 -c > /tmp/docker/nocodb.tgz
```


**Load Cache**

```bash
cat /tmp/docker/pg_exporter.tgz  | gzip -d -c - | docker load;
cat /tmp/docker/postgrest.tgz    | gzip -d -c - | docker load;
cat /tmp/docker/pgweb.tgz        | gzip -d -c - | docker load;
cat /tmp/docker/pgadmin4.tgz     | gzip -d -c - | docker load;
cat /tmp/docker/bytebase.tgz     | gzip -d -c - | docker load;
cat /tmp/docker/jupyter.tgz      | gzip -d -c - | docker load;
cat /tmp/docker/wiki.tgz         | gzip -d -c - | docker load;
cat /tmp/docker/gitea.tgz        | gzip -d -c - | docker load;
cat /tmp/docker/kong.tgz         | gzip -d -c - | docker load;
cat /tmp/docker/odoo.tgz         | gzip -d -c - | docker load;
cat /tmp/docker/alpine.tgz       | gzip -d -c - | docker load;
cat /tmp/docker/registry.tgz     | gzip -d -c - | docker load;
cat /tmp/docker/schemaspy.tgz    | gzip -d -c - | docker load;
cat /tmp/docker/nocodb.tgz       | gzip -d -c - | docker load;
```


## Software

There are lots of software using PostgreSQL / Redis.

* KeyCloak : SSO Solution
* Gitlab : Code Management
* Jira : Project Management
* Confluence: Document Management
* Harbour : Image Management
* JupyterLab : Data Analysis
* Grafana : Data Visualization
* Mastodon : Social Network
* Discourse : Community

```bash
docker pull quay.io/keycloak/keycloak:18.0.0            # 18.0.0   # 562MB
docker pull tootsuite/mastodon                          # latest   # 1.76GB
docker pull cptactionhank/atlassian-confluence:7.7.3    # 7.7.3    # 835MB
docker pull cptactionhank/atlassian-jira-software:8.1.0 # 8.1.0    # 531MB
docker pull jupyter/scipy-notebook                      # latest   # 3.01GB
docker pull gitlab/gitlab-ee                            # latest   # 2.69GB
docker pull grafana/grafana-oss                         # latest   # 286MB
```

**Make Cache for Software**

```bash
docker save quay.io/keycloak/keycloak tootsuite/mastodon cptactionhank/atlassian-confluence cptactionhank/atlassian-jira-software jupyter/scipy-notebook gitlab/gitlab-ee grafana/grafana-oss | gzip -c - > docker.tgz
cat /tmp/docker.tgz | gzip -d -c - | docker load  
```


## Visualization App

Check [pigsty-app](https://github.com/pgsty/pigsty-app) for details.

Pigsty has one embed visualization app: [pglog](https://demo.pigsty.io/ui/d/pglog-overview) which is used for pg csv log analysis.

There's another visualization app works on pigsty: ISD : noaa weather data visualization: [github.com/Vonng/isd](https://github.com/Vonng/isd), [Demo](https://demo.pigsty.io/ui/d/isd-overview)
