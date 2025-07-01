# Supabase

> [Supabase](https://supabase.com/) —— Build in a weekend, Scale to millions

Pigsty allow you to self-host **supabase** with existing managed HA postgres cluster, and launch the stateless part of supabase with docker-compose.
Check the official tutorial for details: [Self-Hosting Supabase](https://pgsty.com/docs/app/supabase)

Supabase is the open-source Firebase alternative built upon PostgreSQL.
It provides authentication, API, edge functions, real-time subscriptions, object storage, and vector embedding capabilities out of the box.
All you need to do is to design the database schema and frontend, and you can quickly get things done without worrying about the backend development.

Supabase's slogan is: "**Build in a weekend, Scale to millions**". Supabase has great cost-effectiveness in small scales (4c8g) indeed.
But there is no doubt that when you really grow to millions of users, some may choose to self-hosting their own Supabase —— for functionality, performance, cost, and other reasons.

That's where Pigsty comes in. Pigsty provides a complete one-click self-hosting solution for Supabase.
Self-hosted Supabase can enjoy full PostgreSQL monitoring, IaC, PITR, and high availability, the new PG 17 kernels (and 14~16),
and [422](https://pgsty.com/ext/list) PostgreSQL extensions ready to use, and can take full advantage of the performance and cost advantages of modern hardware.



-------

## Quick Start

First, download & [install](https://pgsty.com/docs/install/start) pigsty as usual, with the `supa` config template:

```bash
 curl -fsSL https://repo.pigsty.io/get | bash
 cd pigsty
./configure -c supabase  # use app/supa config template (IMPORTANT: CHANGE PASSWORDS!)
./install.yml            # install pigsty, create ha postgres & minio clusters 
```

Please change the `pigsty.yml` config file according to your need before deploying Supabase. (Credentials)

Then, run the [`docker.yml`](https://github.com/pgsty/pigsty/blob/main/docker.yml) and [`app.yml`](https://github.com/pgsty/pigsty/blob/main/app.yml) to install supabase with docker.

```bash
./docker.yml   # install docker & docker compose
./app.yml      # launch supabase stateless part with docker compose
```

You can access the supabase API / Web UI through the `80/443` infra portal,
with configured DNS for public domain, or a local `/etc/hosts` record with `supa.pigsty` pointing to the node also works.

> Default username & password: `supabase` : `pigsty`

> Beware the storage API require MinIO/S3 to work, and you have to access it via a valid domain name (`/etc/hosts` or real domain)