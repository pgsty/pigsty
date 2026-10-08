# jupyter notebook

The default image is `quay.io/jupyter/minimal-notebook:latest`.
[Current Jupyter Docker Stacks builds](https://jupyter-docker-stacks.readthedocs.io/en/latest/)
are published on Quay; the Docker Hub images have been frozen since 2023-10-20.

Run jupyter notebook with docker, you have to:

- 1. change the default password in [`.env`](.env): `JUPYTER_TOKEN`
- 2. create data dir with proper permission: `make dir`, owned by `1000:100` 
- 3. `make up` to pull up jupyter with docker compose 


```bash
cd ~/pigsty/app/jupyter ; make dir up
```

Visit [http://lab.pigsty](http://lab.pigsty) or http://10.10.10.10:8888, the default password is `pigsty`

- [`http://lab.pigsty?token=pigsty`](http://lab.pigsty?token=pigsty)



## Prepare

Create a data directory `/data/jupyter`, with the default uid & gid `1000:100`:

```bash
make dir   # mkdir -p /data/jupyter; chown -R 1000:100 /data/jupyter
```


## Connect to Postgres

Use the jupyter terminal to install `psycopg2-binary` & `psycopg2` package.

```bash
pip install psycopg2-binary psycopg2

# install with a mirror
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple psycopg2-binary psycopg2

pip install --upgrade pip
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

Or installation with `conda`:

```bash
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
```

then use the driver in your notebook

```python
import psycopg2

conn = psycopg2.connect('postgres://dbuser_dba:DBUser.DBA@10.10.10.10:5432/meta')
cursor = conn.cursor()
cursor.execute('SELECT * FROM pg_stat_activity')
for i in cursor.fetchall():
    print(i)
```




## Alias

```bash
make up         # pull up jupyter with docker compose
make dir        # create required /data/jupyter and set owner
make run        # launch jupyter with docker
make view       # print jupyter access point
make log        # tail -f jupyter logs
make info       # introspect jupyter with jq
make stop       # stop jupyter container
make clean      # remove jupyter container
make pull       # pull latest jupyter image
make rmi        # remove jupyter image
make save       # save jupyter image to /tmp/docker/jupyter.tgz
make load       # load jupyter image from /tmp/docker/jupyter.tgz
```
