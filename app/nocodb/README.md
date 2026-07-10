# NocoDB

Open Source Airtable Alternative: https://nocodb.com/

This is a minimal single-container example, not NocoDB's full production
reference architecture. `DATABASE_URL` remains supported here for compatibility.

```bash
# do not forget to check app/nocodb/.env before make up
cd app/nocodb; make up
```


```bash
make up         # pull up nocodb with docker compose
make run        # launch nocodb with docker, local data dir and external PostgreSQL
make view       # print nocodb access point
make log        # tail -f nocodb logs
make info       # introspect nocodb with jq
make stop       # stop nocodb container
make clean      # remove nocodb container
make pull       # pull latest nocodb image
make rmi        # remove nocodb image
make save       # save nocodb image to /tmp/nocodb.tgz
make load       # load nocodb image from /tmp
```



## Database

Database & User definition

```yaml
- {name: dbuser_noco ,password: DBUser.Noco ,pgbouncer: true ,roles: [dbrole_admin] ,comment: admin user for nocodb service     }
- {name: noco ,owner: dbuser_noco ,revokeconn: true ,comment: nocodb database }
```

```bash
bin/pgsql-user pg-meta dbuser_noco
bin/pgsql-db   pg-meta noco
# postgres://dbuser_noco:DBUser.Noco@10.10.10.10:5432/noco
```


## Expose Service


Visit [http://noco.pigsty](http://noco.pigsty) or http://10.10.10.10:9003 with:

Public demo: http://noco.pigsty.cc , username: `admin@pigsty.cc` and password: `pigsty.cc`



## Docker Compose 

```yaml

services:
  nocodb:
    container_name: nocodb
    image: nocodb/nocodb:latest
    environment:
      DATABASE_URL: "${DATABASE_URL}"
      NC_AUTH_JWT_SECRET: "${NC_AUTH_JWT_SECRET}"
    restart: always
    ports:
      - ${NC_PORT}:8080
    volumes:
      - /data/nocodb:/usr/app/data/
```
