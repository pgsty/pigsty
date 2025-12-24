#!/usr/bin/env python3
#==============================================================#
# File      :   grafana.py
# Desc      :   dump/load/init grafana dashboards
# Ctime     :   2022-11-23
# Mtime     :   2025-12-11
# Path      :   files/grafana/grafana.py
# License   :   AGPLv3 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
import os, sys, json, requests

# grafana access info
ENDPOINT = os.environ.get("GRAFANA_ENDPOINT", 'http://i.pigsty/ui')
USERNAME = os.environ.get("GRAFANA_USERNAME", 'admin')
PASSWORD = os.environ.get("GRAFANA_PASSWORD", 'pigsty')
CREATE_FOLDERS = True

METADB_PASSWORD = 'DBUser.Viewer'
DEFAULT_DATASOURCES = {
    'ds-prometheus': {'uid': 'ds-prometheus', 'orgId': 1, 'name': 'Prometheus', 'type': 'prometheus', 'typeName': 'Prometheus', 'typeLogoUrl': 'public/app/plugins/datasource/prometheus/img/prometheus_logo.svg', 'access': 'proxy',
     'url': 'http://127.0.0.1:9058', 'user': '', 'database': '', 'basicAuth': False, 'isDefault': True, 'jsonData': {'queryTimeout': '60s', 'timeInterval': '2s', 'tlsAuth': False, 'tlsAuthWithCACert': False}, 'readOnly': False},
    'ds-meta': {'uid': 'ds-meta', 'orgId': 1, 'name': 'Meta', 'type': 'postgres', 'typeName': 'PostgreSQL', 'access': 'proxy', 'url': '127.0.0.1:5432', 'user': 'dbuser_view', 'database': 'meta', 'basicAuth': False, 'isDefault': False, 'readOnly': True,
     'jsonData': {'connMaxLifetime': 14400, 'maxIdleConns': 10, 'maxOpenConns': 64,  'postgresVersion': 1500, 'sslmode': 'require', 'tlsAuth': False, 'tlsAuthWithCACert': False}, 'secureJsonData': { 'password': METADB_PASSWORD }},
    'ds-vlogs': {'uid': 'ds-vlogs', 'orgId': 1, 'name': 'Loki', 'type': 'loki', 'typeName': 'Loki', 'access': 'proxy', 'url': 'http://127.0.0.1:3100', 'basicAuth': False, 'isDefault': False, 'jsonData': {}, 'readOnly': False}}



##########################################
# generic api
##########################################
def get(path):
    return requests.get(
        "%s/api/%s" % (ENDPOINT, path),
        auth=requests.auth.HTTPBasicAuth(USERNAME, PASSWORD),
        headers={'Content-Type': 'application/json'}
    ).json()


def post(path, payload={}):
    return requests.post(
        "%s/api/%s" % (ENDPOINT, path),
        auth=requests.auth.HTTPBasicAuth(USERNAME, PASSWORD),
        headers={'Content-Type': 'application/json'},
        json=payload
    ).json()


def put(path, payload={}):
    return requests.put(
        "%s/api/%s" % (ENDPOINT, path),
        auth=requests.auth.HTTPBasicAuth(USERNAME, PASSWORD),
        headers={'Content-Type': 'application/json'},
        json=payload
    ).json()


def delete(path):
    return requests.delete(
        "%s/api/%s" % (ENDPOINT, path),
        auth=requests.auth.HTTPBasicAuth(USERNAME, PASSWORD),
        headers={'Content-Type': 'application/json'}
    ).json()


##########################################
# grafana api
##########################################


# Dashboard ----------------->
def get_dashboard(uid):
    return get('dashboards/uid/%s' % uid)


def add_dashboard(d, folder=None):
    """put raw dashboard"""
    d["id"] = None
    payload = {"dashboard": d, "overwrite": True}
    if CREATE_FOLDERS:
        if folder is not None and folder != "":
            payload["folderUid"] = folder
        else:
            payload["folderId"] = 0
    return post('dashboards/db', payload)


def del_dashboard(uid):
    return delete('dashboards/uid/%s' % uid)


def list_dashboards():
    return get('search')


def list_datasources():
    return get('datasources')


def get_dashboard_id_by_uid(uid):
    return get_dashboard(uid)["dashboard"]["id"]


def star_dashboard(id):
    return post('user/stars/dashboard/%s' % id)


def star_dashboard_by_uid(uid):
    return post('user/stars/dashboard/%s' % get_dashboard_id_by_uid(uid))


# Folder ----------------->
def list_folders():
    return get('folders')


def add_folder(uid, title=""):
    if not CREATE_FOLDERS:
        return
    if title == "":
        title = uid.upper()
    post('folders', {"uid": uid, "title": title})
    return put('folders/%s' % uid, {"title": title, "overwrite": True})


def del_folder(uid):
    try:
        return delete('folders/%s' % uid)
    except:
        return {}


# Datasource ----------------->
def del_datasource_by_name(name):
    return delete('datasources/name/%s' % name)


def get_datasource_id_by_name(name):
    return get('datasources/id/%s' % name).get('id')


def create_datasource(ds):
    return post('datasources', ds)

def update_datasource(uid, ds):
    return put('datasources/uid/%s'% uid, ds)


def ds_query(dsID, query):
    return post('ds/query', {
        "queries": [
            {
                "refId": "A",
                "datasourceId": dsID,
                "rawSql": query,
                "format": "table"
            }
        ]
    })


def ds_query_by_name(name, query):
    dsID = get('datasources/id/%s' % name).get('id')
    ds_query(dsID, query)


# Preference ----------------->
def update_org_preference(home="pigsty", theme="light"):
    home_id = get_dashboard_id_by_uid(home)
    put('org/preferences', {
        "theme": theme,
        "homeDashboardId": home_id
    })


def update_user_preference(home="pigsty", theme="light"):
    home_id = get_dashboard_id_by_uid(home)
    put('user/preferences', {
        "theme": theme,
        "homeDashboardId": home_id
    })


# Organization ----------------->
def update_orgname(id, new_name):
    return put('orgs/%s' % id, {"name": new_name})


##########################################
# process dashboard
##########################################

def dashboard_raw(d):
    """extract raw definition of dashboard"""
    raw = d["dashboard"]
    if "id" in raw and raw["id"] is not None:
        raw["id"] = None
    if "templating" in raw and "list" in raw["templating"]:
        i = 0
        for item in raw["templating"]["list"]:
            if "current" in item:
                raw["templating"]["list"][i]["current"] = {}
            i = i + 1
    return raw


def load_dashboard(path, substitute=False):
    if substitute:
        with open(path) as src:
            raw = src.read()
            return json.loads(raw)
    else:
        return json.load(open(path))


def dump_dashboard_to_file(d, path):
    with open(path, 'w') as dst:
        raw = dashboard_raw(d)
        raw["version"] = 1
        raw["author"] = "Ruohang Feng (rh@vonng.com)"
        raw["license"] = "https://pigsty.io/docs/about/license/"
        json.dump(raw, dst, indent=4, sort_keys=True)


def dump_dashboard(d, home):
    db_uid = d["dashboard"]["uid"]
    dir_uid = d["meta"].get("folderUid")
    if dir_uid is None or dir_uid == "":
        dir_uid = '.'
    p = os.path.join(home, dir_uid, db_uid + '.json')
    with open(p, 'w') as dst:
        json.dump(dashboard_raw(d), dst, indent=4, sort_keys=True)


##########################################
# business logic
##########################################


def init_all(dashboard_dir):
    """init grafana with dashboards dir content
        similar to load_all, but will replace domain name placeholder
    """
    update_orgname(1, 'Pigsty')  # update default org name
    # add_folder("pgsql", "PGSQL")  # create dashboard folders
    # add_folder("pgcat", "PGCAT")
    # add_folder("pglog", "PGLOG")

    # load home dashboards
    folders = []
    for f in os.listdir(dashboard_dir):
        abs_path = os.path.join(dashboard_dir, f)
        if os.path.isfile(abs_path) and f.endswith('.json')  and not f.startswith('.'):
            print("init dashboard : %s" % f)
            add_dashboard(load_dashboard(abs_path, True))
        if os.path.isdir(abs_path):
            folders.append((f, abs_path))  # folder name, abs path

    home_uid = "pigsty"
    star_dashboard_by_uid(home_uid)  # home dashboards will be loaded above if exists
    update_org_preference(home_uid, "light")
    update_user_preference(home_uid, "light")

    # load other second-layer dashboards
    for folder_name, folder_path in folders:
        print("init folder %s" % folder_name)
        add_folder(folder_name, folder_name.upper())

        for f in os.listdir(folder_path):
            abs_path = os.path.join(dashboard_dir, folder_name, f)
            if os.path.isfile(abs_path) and f.endswith('.json') and not f.startswith('.'):
                print("init dashboard: %s / %s" % (folder_name, f))
                add_dashboard(load_dashboard(abs_path, True), folder_name)


def load_all(dashboard_dir):
    """load dashboards and folders"""
    folders = []
    for f in os.listdir(dashboard_dir):
        abs_path = os.path.join(dashboard_dir, f)
        if os.path.isfile(abs_path) and f.endswith('.json') and not f.startswith('.'):
            print("load dashboard : %s" % f)
            add_dashboard(load_dashboard(abs_path))
        if os.path.isdir(abs_path):
            folders.append((f, abs_path))  # folder name, abs path

    for folder_name, folder_path in folders:
        print("add folder %s" % folder_name)
        add_folder(folder_name, folder_name.upper())

        for f in os.listdir(folder_path):
            abs_path = os.path.join(dashboard_dir, folder_name, f)
            if os.path.isfile(abs_path) and f.endswith('.json') and not f.startswith('.'):
                print("load dashboard: %s / %s" % (folder_name, f))
                add_dashboard(load_dashboard(abs_path), folder_name)


def dump_all(dashboard_dir):
    """dump dashboard to specific dir with fhs"""
    if not os.path.exists(dashboard_dir):
        print("dump: create dashboard dir %s" % dashboard_dir)
        os.mkdir(dashboard_dir)
    dbmeta = list_dashboards()
    folders = set([i.get('folderUid') for i in dbmeta if 'folderUid' in i and i.get('type') != 'dash-folder'])
    dashdbs = [(i.get('uid'), i.get('folderUid', '.')) for i in dbmeta if i.get('type') != 'dash-folder']
    for d in folders:
        abs_path = os.path.join(dashboard_dir, d)
        if os.path.isfile(abs_path):
            os.remove(abs_path)
        if not os.path.exists(abs_path):
            print("dump: %s / dir created" % d)
            os.mkdir(abs_path)
        print("dump: create dir %s" % d)

    for uid, folder in dashdbs:
        dbpath = os.path.join(dashboard_dir, folder, uid + '.json')
        if folder == "." or not folder:
            dbpath = os.path.join(dashboard_dir, uid + '.json')
        print("dump: %s / %s  \t ---> %s" % (folder, uid, dbpath))
        dump_dashboard_to_file(get_dashboard(uid), dbpath)


def clean_all():
    dbmeta = list_dashboards()
    folders = set([i.get('folderUid') for i in dbmeta if 'folderUid' in i and i.get('type') != 'dash-folder'])
    dashdbs = [(i.get('uid'), i.get('folderUid', '.')) for i in dbmeta if
               i.get('type') != 'dash-folder']
    for d, f in dashdbs:
        print("clean: dashboard %s" % d)
        del_dashboard(d)
    for f in folders:
        print("clean: folder %s" % f)
        del_folder(f)

def add_default_datasource():
    for k, v in DEFAULT_DATASOURCES.items():
        print("init: data source %s" % k)
        create_datasource(v)
        update_datasource(k, v)


def usage():
    print("""
    grafana.py [init|load|dump|clean]
                init [dashboard_dir=.]  # provisioning grafana
                load [dashboard_dir=.]  # load folders & dashboards 
                dump [dashboard_dir=.]  # dump folders & dashboards
                ds                      # init data sources
                clean                   # clean folders & dashboards
    """)


if __name__ == '__main__':
    if len(sys.argv) <= 1:
        usage()
        exit(1)

    action = sys.argv[1]
    dashboard_dir_path = None
    if len(sys.argv) > 2:
        dashboard_dir_path = sys.argv[2]
    else:
        dashboard_dir_path = '.'

    print("Grafana API: %s:%s @ %s" % (USERNAME, PASSWORD, ENDPOINT))

    if action == 'clean':
        print("clean all dashboards and folders")
        clean_all()
        exit(0)

    if not (os.path.exists(dashboard_dir_path) and os.path.isdir(dashboard_dir_path)):
        print("not exists : dashboard dir %s " % dashboard_dir_path)
        exit(2)

    if action == 'init':
        # add_default_datasource()
        init_all(dashboard_dir_path)
    elif action == 'load':
        load_all(dashboard_dir_path)
    elif action == 'dump':
        dump_all(dashboard_dir_path)
    elif action == 'ds':
        add_default_datasource()
    else:
        usage()
        exit(3)
