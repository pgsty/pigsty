#==============================================================#
# File      :   Makefile
# Desc      :   pigsty shortcuts
# Ctime     :   2019-04-13
# Mtime     :   2026-02-08
# Path      :   Makefile
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#
# pigsty version string
VERSION?=v4.0.0

# detect architecture
ARCH?=x86_64
UNAME_ARCH := $(shell uname -m)
ifeq ($(UNAME_ARCH),arm64)
	ARCH := aarch64
else ifeq ($(UNAME_ARCH),aarch64)
	ARCH := aarch64
else
	ARCH := $(UNAME_ARCH)
endif

# variables
SRC_PKG=pigsty-$(VERSION).tgz
APP_PKG=pigsty-app-$(VERSION).tgz
DBA_PKG=pigsty-dba-$(VERSION).tgz
DOCKER_PKG=pigsty-docker-$(VERSION).tgz
EL8_PKG=pigsty-pkg-$(VERSION).el8.${ARCH}.tgz
EL9_PKG=pigsty-pkg-$(VERSION).el9.${ARCH}.tgz
EL10_PKG=pigsty-pkg-$(VERSION).el10.${ARCH}.tgz
D12_PKG=pigsty-pkg-$(VERSION).d12.${ARCH}.tgz
D13_PKG=pigsty-pkg-$(VERSION).d13.${ARCH}.tgz
U22_PKG=pigsty-pkg-$(VERSION).u22.${ARCH}.tgz
U24_PKG=pigsty-pkg-$(VERSION).u24.${ARCH}.tgz
META?=10.10.10.10
OS?=el9
PKG?=""
#PKG?=pro

# append / to PKG if not already present
ifeq ($(filter %/,$(PKG)),)
ifneq ($(PKG),)
PKG:=$(PKG)/
endif
endif


###############################################################
#                      1. Quick Start                         #
###############################################################
# run with nopass SUDO user (or root) on Linux node
default: tip
tip:
	echo $(ARCH)
	@echo "# Run on Linux node with nopass sudo & ssh access"
	@echo 'curl -fsSL https://repo.pigsty.io/get | bash'
	@echo "./bootstrap     # prepare local repo & ansible"
	@echo "./configure     # pre-check and templating config"
	@echo "./deploy.yml    # install pigsty on current node"

# print pkg download links
link:
	@echo 'curl -fsSL https://repo.pigsty.io/get | bash'

# serve a local docs with docsify or python http
doc:
	docs/serve

#-------------------------------------------------------------#
# (1). BOOTSTRAP  pigsty pkg & util preparedness
boot: bootstrap
bootstrap:
	./bootstrap

# (2). CONFIGURE  pigsty in interactive mode
conf: configure
configure:
	./configure

# (3). DEPLOY     pigsty on current node
deploy:
	./deploy.yml
###############################################################



###############################################################
#                        OUTLINE                              #
###############################################################
#  (1). Quick-Start   :   shortcuts for launching pigsty (above)
#  (2). Download      :   shortcuts for downloading resources
#  (3). Configure     :   shortcuts for configure pigsty
#  (4). Install       :   shortcuts for running playbooks
#  (5). Sandbox       :   shortcuts for manage sandbox vm nodes
#  (6). Testing       :   shortcuts for testing features
#  (7). Develop       :   shortcuts for dev purpose
#  (8). Release       :   shortcuts for release and publish
#  (9). Misc          :   shortcuts for miscellaneous tasks
###############################################################



###############################################################
#                      2. Download                            #
###############################################################
# There are two things that need to be downloaded:
#    pigsty.tgz    :   source code
#    pkg.tgz       :   offline rpm packages (optional)
#
# get latest stable version to ~/pigsty
src:
	curl -SL https://github.com/pgsty/pigsty/releases/download/${VERSION}/${SRC_PKG} -o ~/pigsty.tgz
###############################################################



###############################################################
#                      3. Configure                           #
###############################################################
# there are several things that need to be checked before deploy
# use ./configure or `make config` to run interactive wizard
# it will install ansible (from offline rpm repo if available)

# common interactive configuration procedure
c: configure

# validate config inventory
v: validate
validate:
	bin/validate
###############################################################



###############################################################
#                      4. Install                             #
###############################################################
# pigsty is deployed via ansible-playbook

# install pigsty on meta nodes
infra:
	./infra.yml

# rebuild repo
repo: repo-build node-repo

# write upstream repo to /etc/yum.repos.d
repo-upstream:
	./infra.yml --tags=repo_upstream

repo-check:
	./deploy.yml -t node_repo,node_pkg,infra_pkg,pg_pkg

# re-build local repo
repo-build:
	./infra.yml -t repo_build

# add extra packages to local repo
repo-add:
	./infra.yml -t repo_build -t repo_upstream,repo_cache,repo_pkg -e '{"repo_packages":[],"repo_url_packages":[]}'

repo-clean:
	ansible all -b -a 'rm -rf /www/pigsty/repo_complete'

node-repo:
	./node.yml -t node_repo

node-pkg:
	./node.yml -t node_pkg

node-upstream:
	./node.yml -t node_repo -e node_repo_modules=node,pgsql,infra,local

redeploy: repo-clean
	./deploy.yml

# init grafana
grafana:
	./infra.yml --tags=grafana
	./pgsql.yml --tags=register_ds

# init vlogs & vector
vv: vlogs vector
vlogs:
	./infra.yml --tags=vlogs -e vlogs_clean=true
vector:
	./node.yml --tags=vector -e vector_clean=true -e vector_read_from=beginning

# nginx & certbot
nginx:
	./infra.yml -t nginx
cert:
	./infra.yml -t nginx_certbot,nginx_reload -e certbot_sign=true

# init docker
docker:
	./docker.yml
app:
	./app.yml

# claude
claude:
	./vibe.yml -t nodejs,claude

# install & uninstall pgsql (dangerous!!)
pgsql-add:
	./infra.yml -t repo_build
	./pgsql.yml
pgsql-rm:
	./pgsql-rm.yml -e pg_uninstall=true
pgsql-ext: repo-add
	./infra.yml -t repo_build
	./pgsql.yml -t pg_ext

###############################################################




###############################################################
#                       5. Vagrant                            #
###############################################################
# shortcuts to pull up vm nodes with vagrant on your own MacOS
# DO NOT RUN THESE SHORTCUTS ON YOUR META NODE!!!
# These shortcuts are running on your HOST machine which run
# pigsty sandbox via virtualbox managed by vagrant.
#=============================================================#
# to setup vagrant sandbox env on your MacOS host:
#
#  Prepare
#  (1). make deps    (once) Install MacOS deps with homebrew
#  (2). make dns     (once) Write static DNS
#  (3). make start   (once) Pull-up vm nodes and setup ssh access
#  (4). make demo           Boot meta node same as Quick-Start
#=============================================================#

#------------------------------#
# 1. deps (macos)
#------------------------------#
# install macos sandbox software dependencies
deps:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	brew install vagrant virtualbox ansible

#------------------------------#
# 2. dns
#------------------------------#
# write static dns records (sudo password required) (only run on first time)
dns:
	sudo vagrant/dns

#------------------------------#
# 3. start
#------------------------------#
# start will pull up node and write ssh-config
# it may take a while to download the box for the first time
start: up ssh      # 1-node version
ssh:               # add current vagrant ssh config to your ~/.ssh/pigsty_config
	vagrant/ssh
tssh:               # add current terraform ssh config to your ~/.ssh/pigsty_config
	terraform/ssh

#------------------------------#
# vagrant vm management
#------------------------------#
# default node (meta)
up:
	cd vagrant && vagrant up
dw:
	cd vagrant && vagrant halt
del:
	cd vagrant && vagrant destroy -f
nuke:
	cd vagrant && ./nuke
new: del up
clean: del
#------------------------------#
# extra nodes: node-{1,2,3}
up-test:
	cd vagrant && vagrant up node-1 node-2 node-3
dw-test:
	cd vagrant && vagrant halt node-1 node-2 node-3
del-test:
	cd vagrant && vagrant destroy -f node-1 node-2 node-3
new-test: del-test up-test
#------------------------------#
# status
st: status
status:
	cd vagrant && vagrant status
suspend:
	cd vagrant && vagrant suspend
resume:
	cd vagrant && vagrant resume

###############################################################



###############################################################
#                       6. Testing                            #
###############################################################
# Convenient shortcuts for add traffic to sandbox pgsql clusters
#  ri  test-ri   :  init pgbench on meta or pg-test cluster
#  rw  test-rw   :  read-write pgbench traffic on meta or pg-test
#  ro  test-ro   :  read-only pgbench traffic on meta or pg-test
#  rc  test-rc   :  clean-up pgbench tables on meta or pg-test
#  test-rw2 & test-ro2 : heavy load version of test-rw, test-ro
#  test-rb{1,2,3} : reboot node 1,2,3
#=============================================================#
# meta cmdb bench
ri:
	pgbench -is10 postgres://dbuser_meta:DBUser.Meta@$(META):5433/meta
rc:
	psql -AXtw postgres://dbuser_meta:DBUser.Meta@$(META):5433/meta -c 'DROP TABLE IF EXISTS pgbench_accounts, pgbench_branches, pgbench_history, pgbench_tellers;'
rw:
	while true; do pgbench -nv -P1 -c4 --rate=64 -T10 postgres://dbuser_meta:DBUser.Meta@$(META):5433/meta; done
ro:
	while true; do pgbench -nv -P1 -c8 --rate=256 -S -T10 postgres://dbuser_meta:DBUser.Meta@$(META):5434/meta; done
rh:
	ssh $(META) 'sudo -iu postgres /pg/bin/pg-heartbeat'
# pg-test cluster benchmark
test-ri:
	pgbench -is10  postgres://test:test@pg-test:5436/test
test-rc:
	psql -AXtw postgres://test:test@pg-test:5433/test -c 'DROP TABLE IF EXISTS pgbench_accounts, pgbench_branches, pgbench_history, pgbench_tellers;'
# pgbench small read-write / read-only traffic (rw=64TPS, ro=512QPS)
test-rw:
	while true; do pgbench -nv -P1 -c4 --rate=32 -T10 postgres://test:test@pg-test:5433/test; done
test-ro:
	while true; do pgbench -nv -P1 -c8 -S --rate=256 -T10 postgres://test:test@pg-test:5434/test; done
# pgbench read-write / read-only traffic (maximum speed)
test-rw2:
	while true; do pgbench -nv -P1 -c16 -T10 postgres://test:test@pg-test:5433/test; done
test-ro2:
	while true; do pgbench -nv -P1 -c64 -T10 -S postgres://test:test@pg-test:5434/test; done
test-rh:
	ssh node-1 'sudo -iu postgres /pg/bin/pg-heartbeat'
#------------------------------#
# show patroni status for pg-test cluster
test-st:
	ssh -t node-1 "sudo -iu postgres patronictl -c /etc/patroni/patroni.yml list -W"
# reboot node 1,2,3
test-rb1:
	ssh -t node-1 "sudo reboot"
test-rb2:
	ssh -t node-2 "sudo reboot"
test-rb3:
	ssh -t node-3 "sudo reboot"
###############################################################




###############################################################
#                       7. Develop                            #
###############################################################
#  other shortcuts for development
#=============================================================#

#------------------------------#
# grafana dashboard management
#------------------------------#
di: dashboard-init                    # init grafana dashboards
dashboard-init:
	cd files/grafana/ && ./grafana.py init

dd: dashboard-dump                    # dump grafana dashboards
dashboard-dump:
	cd files/grafana/ && ./grafana.py dump

dc: dashboard-clean                   # cleanup grafana dashboards
dashboard-clean:
	cd files/grafana/ && ./grafana.py clean

du: dashboard-clean dashboard-init    # update grafana dashboards

#------------------------------#
# copy source & packages
#------------------------------#
# copy latest source code
copy: copy-src copy-pkg use-src use-pkg
cc: release copy-src copy-pkg use-src use-pkg

# copy pigsty source code
copy-src:
	scp "dist/${VERSION}/${SRC_PKG}" $(META):~/pigsty.tgz

# copy offline packages (set OS=el8/el9/el10/d12/d13/u22/u24)
copy-pkg:
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.${OS}.${ARCH}.tgz $(META):/tmp/pkg.tgz
copy-el8:
	scp dist/${VERSION}/$(PKG)${EL8_PKG} $(META):/tmp/pkg.tgz
copy-el9:
	scp dist/${VERSION}/$(PKG)${EL9_PKG} $(META):/tmp/pkg.tgz
copy-el10:
	scp dist/${VERSION}/$(PKG)${EL10_PKG} $(META):/tmp/pkg.tgz
copy-d12:
	scp dist/${VERSION}/$(PKG)${D12_PKG} $(META):/tmp/pkg.tgz
copy-d13:
	scp dist/${VERSION}/$(PKG)${D13_PKG} $(META):/tmp/pkg.tgz
copy-u22:
	scp dist/${VERSION}/$(PKG)${U22_PKG} $(META):/tmp/pkg.tgz
copy-u24:
	scp dist/${VERSION}/$(PKG)${U24_PKG} $(META):/tmp/pkg.tgz
copy-app:
	scp dist/${VERSION}/${APP_PKG} $(META):~/app.tgz
	ssh -t $(META) 'rm -rf ~/app; tar -xf app.tgz; rm -rf app.tgz'
copy-all: copy-src copy-pkg

# extract packages
use-src:
	ssh -t $(META) 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
use-pkg:
	ssh $(META) "sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www"
use-all: use-src use-pkg

# load config into cmdb
cmdb:
	bin/inventory_load
	bin/inventory_cmdb

#------------------------------#
# build env shortcuts
#------------------------------#
# copy src to build environment
cso: copy-src-oss
copy-src-oss:
	scp "dist/${VERSION}/${SRC_PKG}" el9:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" d12:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" u24:~/pigsty.tgz
	ssh -t el9 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t d12 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t u24 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
copy-src-pro: copy-src-oss
	scp "dist/${VERSION}/${SRC_PKG}" el8:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" u22:~/pigsty.tgz
	ssh -t el8 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t u22 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
csr: copy-src-rpm
copy-src-rpm:
	scp "dist/${VERSION}/${SRC_PKG}" el8:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" el9:~/pigsty.tgz
	ssh -t el8 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t el9 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t el8 'cd ~/pigsty && ./configure -i 10.10.10.8'
	ssh -t el9 'cd ~/pigsty && ./configure -i 10.10.10.9'
csd: copy-src-deb
copy-src-deb:
	scp "dist/${VERSION}/${SRC_PKG}" d12:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" u22:~/pigsty.tgz
	scp "dist/${VERSION}/${SRC_PKG}" u24:~/pigsty.tgz
	ssh -t  d12 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t  u22 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t  u24 'rm -rf ~/pigsty; tar -xf pigsty.tgz; rm -rf pigsty.tgz'
	ssh -t  d12 'cd ~/pigsty && ./configure -i 10.10.10.12'
	ssh -t  u22 'cd ~/pigsty && ./configure -i 10.10.10.22'
	ssh -t  u24 'cd ~/pigsty && ./configure -i 10.10.10.24'
dfx: deb-fix
deb-fix:
	scp /etc/resolv.conf d12:/tmp/resolv.conf;
	ssh -t d12 'sudo mv /tmp/resolv.conf /etc/resolv.conf'
	scp /etc/resolv.conf u24:/tmp/resolv.conf;
	ssh -t u24 'sudo mv /tmp/resolv.conf /etc/resolv.conf'

#------------------------------#
# push / pull
#------------------------------#
push:
	rsync -avz ./ sv:~/pigsty/ --delete --exclude-from 'vagrant/Vagrantfile'
pull:
	rsync -avz sv:~/pigsty/ ./ --exclude-from 'vagrant/Vagrantfile' --exclude-from 'vagrant/.vagrant'
ss:
	rsync -avz --exclude=temp --exclude=dist --exclude=vagrant --exclude=terraform --delete ./ ai:/data/pigsty/
gsync:
	rsync -avz --delete .git/ sv:/data/pgsty/pigsty/.git/
gpull:
	rsync -avz --delete sv:/data/pgsty/pigsty/.git/ .git/
grestore:
	git restore pigsty.yml
	git restore vagrant/Vagrantfile
gpush:
	git push origin main
###############################################################



###############################################################
#                       8. Release                            #
###############################################################
# make pigsty release (source code tarball)
r: release
release:
	bin/release ${VERSION}

u: upload-src
upload-src:
	cp -f dist/$(VERSION)/$(SRC_PKG) ~/pgsty/repo/src/
	cd ~/pgsty/repo && make up-src

rd: release-dba
release-dba:
	@mkdir -p dist/$(VERSION)
	tar -czf dist/$(VERSION)/$(DBA_PKG) .claude CLAUDE.md
	@echo "Created: dist/$(VERSION)/$(DBA_PKG)"

gd: get-dba
get-dba:
	curl -fsSL "https://repo.pigsty.cc/dba/$(DBA_PKG)" | tar -xzf -
	@echo "DBA package extracted to current directory"

ud: upload-dba
upload-dba:
	cp -f dist/$(VERSION)/$(DBA_PKG) ~/pgsty/repo/dba/
	cd ~/pgsty/repo && make up-dba
	@echo "Uploaded: $(DBA_PKG)"


###############################################################
#                     9. Environment                          #
###############################################################

#------------------------------#
#          Terraform           #
#------------------------------#
tu: # terraform up
	cd terraform && make u
	cd terraform && make ssh
td: # terraform destroy
	cd terraform && make d
ts: # terraform ssh
	cd terraform && make ssh
to: # terraform output
	cd terraform && make out

#------------------------------#
#     Change Configuration     #
#------------------------------#
cmeta:
	./configure -s -c meta
cdual:
	./configure -s -c ha/dual
ctrio:
	./configure -s -c ha/trio
cfull:
	./configure -s -c ha/full
csimu:
	./configure -s -c ha/simu
coss:
	cp conf/build/oss.yml pigsty.yml
cpro:
	cp conf/build/pro.yml pigsty.yml

#------------------------------#
#     Building Environment     #
#------------------------------#
oss: coss del vo new ssh copy-src-oss dfx
pro: cpro del vp new ssh dfx
all: del va new ssh dfx
vo: # oss building environment
	vagrant/config oss
vp: # pro building environment
	vagrant/config pro
vr: # rpm building environment
	vagrant/config rpm
vd: # deb building environment
	vagrant/config deb
va: # all building environment
	vagrant/config all
boot-pkg:
	bin/boot $(VERSION)

#------------------------------#
# meta, single node, the devbox
#------------------------------#
# simple 1-node devbox for quick setup, demonstration, and development

meta: meta9
meta8:  cmeta del vmeta8  up ssh #copy-el8 use-pkg
meta9:  cmeta del vmeta9  up ssh #copy-el9 use-pkg
meta10: cmeta del vmeta10 up ssh #copy-el10 use-pkg
meta12: cmeta del vmeta12 up ssh #copy-d12 use-pkg
meta13: cmeta del vmeta13 up ssh #copy-d13 use-pkg
meta22: cmeta del vmeta22 up ssh #copy-u22 use-pkg
meta24: cmeta del vmeta24 up ssh #use-pkg

vm: vmeta
vmeta:
	vagrant/config meta el9
vmeta8:
	vagrant/config meta el8
vmeta9:
	vagrant/config meta el9
vmeta10:
	vagrant/config meta el10
vmeta12:
	vagrant/config meta d12
vmeta13:
	vagrant/config meta d13
vmeta22:
	vagrant/config meta u22
vmeta24:
	vagrant/config meta u24

#------------------------------#
# full, four nodes, the sandbox
#------------------------------#
# full-featured 4-node sandbox for HA-testing & tutorial & practices

full:   full9
full8:  cfull del vfull8  up ssh #copy-el8 use-pkg
full9:  cfull del vfull9  up ssh #copy-el9 use-pkg
full10: cfull del vfull10 up ssh #copy-el10 use-pkg
full12: cfull del vfull12 up ssh #copy-d12 use-pkg
full13: cfull del vfull13 up ssh #copy-d13 use-pkg
full22: cfull del vfull22 up ssh #copy-u22 use-pkg
full24: cfull del vfull24 up ssh #copy-u24 use-pkg

vf: vfull
vfull:
	vagrant/config full el9
vfull8:
	vagrant/config full el8
vfull9:
	vagrant/config full el9
vfull10:
	vagrant/config full el10
vfull12:
	vagrant/config full d12
vfull13:
	vagrant/config full d13
vfull22:
	vagrant/config full u22
vfull24:
	vagrant/config full u24

#------------------------------#
# simu, 20 nodes, the simubox
#------------------------------#
# complex 20-node simubox for production simulation & complete testing
simu-conf:
	./configure -s -c ha/simu
vsimu:
	vagrant/config simu el9
vsimu8:
	vagrant/config simu el8
vsimu9:
	vagrant/config simu el9
vsimu10:
	vagrant/config simu el10
vsimu12:
	vagrant/config simu d12
vsimu13:
	vagrant/config simu d13
vsimu22:
	vagrant/config simu u22
vsimu24:
	vagrant/config simu u24

vs: simu
simu: simu9
simu8: csimu del vsimu8 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.el8.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu9: csimu del vsimu9 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.el9.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu10: csimu del vsimu10 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.el10.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu12: csimu del vsimu12 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.d12.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu13: csimu del vsimu13 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.d13.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu22: csimu del vsimu22 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.u22.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
simu24: csimu del vsimu24 new ssh
	scp dist/${VERSION}/$(PKG)pigsty-pkg-${VERSION}.u24.${ARCH}.tgz 10.10.10.10:/tmp/pkg.tgz ; ssh 10.10.10.10 'sudo mkdir -p /www; sudo tar -xf /tmp/pkg.tgz -C /www'
rs:
	rsync -avz --exclude=vagrant ./ ai:~/pigsty/
###############################################################




###############################################################
#                        Inventory                            #
###############################################################
.PHONY: default tip link doc boot bootstrap conf configure deploy \
        src \
        c v validate \
        infra repo repo-upstream repo-check repo-build repo-add repo-clean \
        node-repo node-upstream node-pkg redeploy \
        grafana vv vlogs vector nginx cert claude cc docker app \
        pgsql-add pgsql-rm pgsql-ext \
        deps dns start ssh tssh \
        up dw del nuke new clean \
        up-test dw-test del-test new-test \
        st status suspend resume \
        ri rc rw ro rh test-ri test-rc test-rw test-ro test-rw2 test-ro2 test-rh test-st test-rb1 test-rb2 test-rb3 \
        di dd dc du dashboard-init dashboard-dump dashboard-clean \
        copy cc copy-src copy-pkg copy-el8 copy-el9 copy-el10 copy-d12 copy-d13 copy-u22 copy-u24 copy-app copy-all \
        use-src use-pkg use-all cmdb \
        cso copy-src-oss copy-src-pro csr copy-src-rpm csd copy-src-deb dfx deb-fix \
        push pull ss gsync gpull grestore gpush \
        r release u upload-src \
        tu td ts to \
        cmeta cdual ctrio cfull csimu coss cpro \
        oss pro all vo vp vr vd va boot-pkg \
        meta meta8 meta9 meta10 meta12 meta13 meta22 meta24 \
        vm vmeta vmeta8 vmeta9 vmeta10 vmeta12 vmeta13 vmeta22 vmeta24 \
        full full8 full9 full10 full12 full13 full22 full24 \
        vf vfull vfull8 vfull9 vfull10 vfull12 vfull13 vfull22 vfull24 \
        simu-conf vsimu vsimu8 vsimu9 vsimu10 vsimu12 vsimu13 vsimu22 vsimu24 \
        vs simu simu8 simu9 simu10 simu12 simu13 simu22 simu24 rs \
        rd release-dba gd get-dba ud upload-dba

###############################################################
