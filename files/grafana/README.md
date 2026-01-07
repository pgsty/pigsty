# Dashboards

This directory contains grafana dashboard definitions.

* [Pigsty Home](pigsty.json)
* [INFRA Dashboards](infra)
* [Node DAshboards](node)
* [PGSQL Dashboards](pgsql)
* [REDIS Dashboards](redis)
* [Application Dashboards](app)

## Utils

There's a utils script [`grafana.py`](grafana.py) to load / dump /clean grafana dashboards.

You can pass the following environment variables to the script:

```bsah
# Grafana Endpoint / Username / Password
ENDPOINT = os.environ.get("GRAFANA_ENDPOINT", 'http://i.pigsty/ui')
USERNAME = os.environ.get("GRAFANA_USERNAME", 'admin')
PASSWORD = os.environ.get("GRAFANA_PASSWORD", 'pigsty')

# Replace default domain names
UPSTREAM = os.environ.get("NGINX_UPSTREAM", "")
NGINX_SSL = os.environ.get("NGINX_SSL_ENABLED", "false")
```


```bash
./grafana.py init       # init pigsty baseline dashboards
./grafana.py dump .     # dump pigsty dashboards to current dir
./grafana.py load .     # load pigsty dashboards from current dir
./grafana.py clean .    # remove target grafana dashboards & folders
```