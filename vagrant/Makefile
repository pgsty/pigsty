#==============================================================#
# File      :   Makefile
# Desc      :   vagrant shortcuts
# Ctime     :   2023-07-29
# Mtime     :   2025-12-14
# Path      :   vagrant/Makefile
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


###############################################################
#                         Environment                         #
###############################################################
# VAGRANT_SPEC='meta'
# VAGRANT_IMAGE='bento/rockylinux-9'
# VAGRANT_SCALE='1'
# VAGRANT_PROVIDER='virtualbox'


###############################################################
#                         Management                          #
###############################################################

#------------------------------#
# default: launch vagrant vms
#------------------------------#
default: start
new: del up ssh

#------------------------------#
# dns
#------------------------------#
dns:
	sudo ./dns

#------------------------------#
# add ssh config to ~/.ssh/
#------------------------------#
ssh:
	./ssh
sshb:
	./ssh oss

#------------------------------#
# Start & Up
#------------------------------#
start: up ssh
up:
	vagrant up

#------------------------------#
# Stop & Halt
#------------------------------#
down: halt
dw: halt
halt:
	vagrant halt

#------------------------------#
# destroy
#------------------------------#
clean: destroy
del: destroy
destroy:
	vagrant destroy -f
nuke:
	./nuke

#------------------------------#
# status
#------------------------------#
st: status
status:
	vagrant status
list:
	virsh list --all

#------------------------------#
# suspend & resume
#------------------------------#
pause: suspend
suspend:
	vagrant suspend
resume:
	vagrant resume

#------------------------------#
# libvirtd info
#------------------------------#
info:
	virsh list
	virsh net-list
	virsh vol-list --pool=default


###############################################################
#                       Specifications                        #
###############################################################

#------------------------------#
#     Building Environment     #
#------------------------------#
oss:   del vo up ssh
pro:   del vp up ssh
rpm:   del vr up ssh
deb:   del vd up ssh
all:   del va up ssh

vo: # oss building environment
	./config oss
vp: # pro building environment
	./config pro
vr: # rpm building environment
	./config rpm
vd: # deb building environment
	./config deb
va: # deb building environment
	./config all


#------------------------------#
# meta, single node, the devbox
#------------------------------#
# simple 1-node devbox for quick setup, demonstration, and development

meta:   del vmeta   up ssh
meta7:  del vmeta7  up ssh
meta8:  del vmeta8  up ssh
meta9:  del vmeta9  up ssh
meta11: del vmeta11 up ssh
meta12: del vmeta12 up ssh
meta20: del vmeta20 up ssh
meta22: del vmeta22 up ssh
meta24: del vmeta24 up ssh

vm: vmeta
vmeta:
	./config meta
vmeta7:
	./config meta el7
vmeta8:
	./config meta el8
vmeta9:
	./config meta el9
vmeta11:
	./config meta debian11
vmeta12:
	./config meta debian12
vmeta20:
	./config meta ubuntu20
vmeta22:
	./config meta ubuntu22
vmeta24:
	./config meta ubuntu24


#------------------------------#
# full, four nodes, the sandbox
#------------------------------#
# full-featured 4-node sandbox for HA-testing & tutorial & practices

full:   del vfull   up ssh
full7:  del vfull7  up ssh
full8:  del vfull8  up ssh
full9:  del vfull9  up ssh
full11: del vfull11 up ssh
full12: del vfull12 up ssh
full20: del vfull20 up ssh
full22: del vfull22 up ssh
full24: del vfull24 up ssh

vf: vfull
vfull:
	./config full
vfull7:
	./config full el7
vfull8:
	./config full el8
vfull9:
	./config full el9
vfull11:
	./config full debian11
vfull12:
	./config full debian12
vfull20:
	./config full ubuntu20
vfull22:
	./config full ubuntu22
vfull24:
	./config full ubuntu24

#------------------------------#
# deci, 10 nodes, the 10-node
#------------------------------#
# complex 10-node simubox for small simulation

deci:   del vdeci   up ssh
deci8:  del vdeci8  up ssh
deci9:  del vdeci9  up ssh
deci10: del vdeci10  up ssh
deci12: del vdeci12 up ssh
deci13: del vdeci12 up ssh
deci22: del vdeci22 up ssh
deci24: del vdeci24 up ssh

vdc: vdeci
vdeci:
	./config deci
vdeci8:
	./config deci el8
vdeci9:
	./config deci el9
vdeci10:
	./config deci el10
vdeci12:
	./config deci debian12
vdeci13:
	./config deci debian13
vdeci22:
	./config deci ubuntu22
vdeci24:
	./config deci ubuntu24

#------------------------------#
# simu, 36 nodes, the simubox
#------------------------------#
# complex 36-node simubox for production simulation & complete testing

simu:   del vsimu   up ssh
simu7:  del vsimu7  up ssh
simu8:  del vsimu8  up ssh
simu9:  del vsimu9  up ssh
simu11: del vsimu11 up ssh
simu12: del vsimu12 up ssh
simu20: del vsimu20 up ssh
simu22: del vsimu22 up ssh
simu24: del vsimu24 up ssh

vs: vsimu
vsimu:
	./config simu
vsimu7:
	./config simu el7
vsimu8:
	./config simu el8
vsimu9:
	./config simu el9
vsimu11:
	./config simu debian11
vsimu12:
	./config simu debian12
vsimu20:
	./config simu ubuntu20
vsimu22:
	./config simu ubuntu22
vsimu24:
	./config simu ubuntu24

#------------------------------#
# dual, 2-node, seldom used
#------------------------------#
# 2-node environment

dual:   del vdual   up ssh
dual7:  del vdual7  up ssh
dual8:  del vdual8  up ssh
dual9:  del vdual9  up ssh
dual11: del vdual11 up ssh
dual12: del vdual12 up ssh
dual20: del vdual20 up ssh
dual22: del vdual22 up ssh

vdual:
	./config dual
vdual7:
	./config dual el7
vdual8:
	./config dual el8
vdual9:
	./config dual el9
vdual12:
	./config dual debian12
vdual20:
	./config dual ubuntu20
vdual22:
	./config dual ubuntu22
vdual24:
	./config dual ubuntu24

#------------------------------#
# trio, 3-node, seldom used
#------------------------------#
# 3-node environment

trio:   del vtrio   up ssh
trio7:  del vtrio7  up ssh
trio8:  del vtrio8  up ssh
trio9:  del vtrio9  up ssh
trio11: del vtrio11 up ssh
trio12: del vtrio12 up ssh
trio20: del vtrio20 up ssh
trio22: del vtrio22 up ssh
trio24: del vtrio24 up ssh

vtrio:
	./config trio
vtrio7:
	./config trio el7
vtrio8:
	./config trio el8
vtrio9:
	./config trio el9
vtrio12:
	./config trio debian12
vtrio20:
	./config trio ubuntu20
vtrio22:
	./config trio ubuntu22
vtrio24:
	./config trio ubuntu24

#------------------------------#
# minio, 4-node, seldom used
#------------------------------#
# 4-node environment

minio:   del vminio   up ssh
minio7:  del vminio7  up ssh
minio8:  del vminio8  up ssh
minio9:  del vminio9  up ssh
minio11: del vminio11 up ssh
minio12: del vminio12 up ssh
minio20: del vminio20 up ssh
minio22: del vminio22 up ssh
minio24: del vminio24 up ssh

vminio:
	./config minio
vminio7:
	./config minio el7
vminio8:
	./config minio el8
vminio9:
	./config minio el9
vminio12:
	./config minio debian12
vminio20:
	./config minio ubuntu20
vminio22:
	./config minio ubuntu22
vminio24:
	./config minio ubuntu24

###############################################################
#                        Inventory                            #
###############################################################
.PHONY: default new ssh sshb dns start up down dw halt clean del destroy nuke st status pause suspend resume info \
	oss rpm deb all vo vr vd vm vf vp va \
	meta meta7 meta8 meta9 meta11 meta12 meta20 meta22 vmeta vmeta7 vmeta8 vmeta9 vmeta11 vmeta12 vmeta20 vmeta22 vmeta24 \
	dual dual7 dual8 dual9 dual11 dual12 dual20 dual22 vdual vdual7 vdual8 vdual9 vdual11 vdual12 vdual20 vdual22 vdual24 \
	trio trio7 trio8 trio9 trio11 trio12 trio20 trio22 vtrio vtrio7 vtrio8 vtrio9 vtrio11 vtrio12 vtrio20 vtrio22 vtrio24 \
	full full7 full8 full9 full11 full12 full20 full22 vfull vfull7 vfull8 vfull9 vfull11 vfull12 vfull20 vfull22 vfull24 \
	simu simu7 simu8 simu9 simu11 simu12 simu20 simu22 vsimu vsimu7 vsimu8 vsimu9 vsimu11 vsimu12 vsimu20 vsimu22 vsimu24 \
	minio minio7 minio8 minio9 minio11 minio12 minio20 minio22 mini24 vminio vminio7 vminio8 vminio9 vminio12 vminio20 vminio22 vminio24

###############################################################