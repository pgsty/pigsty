# Hindsight

> [Hindsight](https://github.com/vectorize-io/hindsight) -- PostgreSQL-native long-term memory for AI agents

Pigsty allows you to self-host **Hindsight** with an external PostgreSQL cluster managed by Pigsty,
instead of the embedded `pg0` development database.
This template follows Hindsight's official external PostgreSQL deployment path and keeps the stack minimal:
one all-in-one Hindsight container, one Pigsty-managed PostgreSQL database, and two Pigsty portal entries for UI/API.


-------

## Quick Start

Install Pigsty with the `hindsight` config template:

```bash
curl -fsSL https://repo.pigsty.io/get | bash; cd ~/pigsty
./bootstrap                  # prepare local repo & ansible
./configure -c app/hindsight # use the hindsight config template
vi pigsty.yml                # IMPORTANT: CHANGE CREDENTIALS / DOMAIN / LLM SETTINGS
./deploy.yml                 # install pigsty & pgsql
./docker.yml                 # install docker & docker-compose
./app.yml                    # install hindsight with docker-compose
```

Access points after deployment:

- UI: `http://hs.pigsty`
- API: `http://hs-api.pigsty`
- Direct API port: `http://<your-ip>:8888`
- Direct UI port: `http://<your-ip>:9999`


-------

## What This Template Provides

- Pigsty-managed PostgreSQL database `hindsight`
- Pigsty-managed service user `hindsight`
- `vector` extension enabled by default via `pgvector`
- Docker Compose app with the official all-in-one image `ghcr.io/vectorize-io/hindsight:latest`
- Persistent local cache directory `/data/hindsight` for downloaded embedding / reranker models
- Two Pigsty portals:
  - `hs.pigsty` -> Hindsight control plane UI (`9999`)
  - `hs-api.pigsty` -> Hindsight REST API (`8888`)


-------

## Default Design Choices

This template defaults to:

- **External PostgreSQL** managed by Pigsty
- **`pgvector`** for vector search
- **`native`** PostgreSQL text search
- **`HINDSIGHT_API_LLM_PROVIDER=none`**

The `none` provider keeps the stack bootable without an external model service.
That means you can bring Hindsight up immediately, but fact extraction / consolidation / `reflect`
will remain limited until you point it at a real LLM provider.


-------

## Enable a Real LLM

Edit `/opt/hindsight/.env` or override the same keys in `pigsty.yml`.

### Use Ollama On The Same Host

```dotenv
HINDSIGHT_API_LLM_PROVIDER=ollama
HINDSIGHT_API_LLM_BASE_URL=http://host.docker.internal:11434/v1
HINDSIGHT_API_LLM_MODEL=qwen3:8b
```

### Use OpenAI-Compatible APIs

```dotenv
HINDSIGHT_API_LLM_PROVIDER=openai
HINDSIGHT_API_LLM_BASE_URL=https://api.openai.com/v1
HINDSIGHT_API_LLM_API_KEY=sk-xxxxxxxx
HINDSIGHT_API_LLM_MODEL=gpt-5-mini
```


-------

## Chinese / Multilingual Retrieval

The default template stays on `pgvector + native` for the safest first deployment.

If your workload is Chinese-heavy and you want better multilingual BM25/tokenization,
Pigsty can provide `vchord` + `vchord_bm25` as a follow-up tuning path.
After installing those extensions in PostgreSQL, switch:

```dotenv
HINDSIGHT_API_VECTOR_EXTENSION=vchord
HINDSIGHT_API_TEXT_SEARCH_EXTENSION=vchord
```


-------

## Management Commands

```bash
make up
make log
make info
make down
make pull
```
