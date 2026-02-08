#==============================================================#
# File      :   Makefile
# Desc      :   vagrant shortcuts
# Ctime     :   2023-07-29
# Mtime     :   2026-01-20
# Path      :   vagrant/Makefile
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
# Copyright :   2018-2026  Ruohang Feng / Vonng (rh@vonng.com)
#==============================================================#


###############################################################
#                         Environment                         #
###############################################################
#export VM_SPEC='meta'
#export VM_IMAGE='bento/rockylinux-9'
#export VM_SCALE='1'
#export VM_PROVIDER='virtualbox'
export VAGRANT_EXPERIMENTAL=disks

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
meta8:  del vmeta8  up ssh
meta9:  del vmeta9  up ssh
meta10: del vmeta10 up ssh
meta12: del vmeta12 up ssh
meta13: del vmeta13 up ssh
meta22: del vmeta22 up ssh
meta24: del vmeta24 up ssh

vm: vmeta
vmeta:
	./config meta el9
vmeta8:
	./config meta el8
vmeta9:
	./config meta el9
vmeta10:
	./config meta el10
vmeta12:
	./config meta d12
vmeta13:
	./config meta d13
vmeta22:
	./config meta u22
vmeta24:
	./config meta u24


#------------------------------#
# full, four nodes, the sandbox
#------------------------------#
# full-featured 4-node sandbox for HA-testing & tutorial & practices

full:   del vfull   up ssh
full8:  del vfull8  up ssh
full9:  del vfull9  up ssh
full10: del vfull10 up ssh
full12: del vfull12 up ssh
full13: del vfull13 up ssh
full22: del vfull22 up ssh
full24: del vfull24 up ssh

vf: vfull
vfull:
	./config full el9
vfull8:
	./config full el8
vfull9:
	./config full el9
vfull10:
	./config full el10
vfull12:
	./config full d12
vfull13:
	./config full d13
vfull22:
	./config full u22
vfull24:
	./config full u24

#------------------------------#
# deci, 10 nodes, the 10-node
#------------------------------#
# complex 10-node simubox for small simulation

deci:   del vdeci   up ssh
deci8:  del vdeci8  up ssh
deci9:  del vdeci9  up ssh
deci10: del vdeci10  up ssh
deci12: del vdeci12 up ssh
deci13: del vdeci13 up ssh
deci22: del vdeci22 up ssh
deci24: del vdeci24 up ssh

vdc: vdeci
vdeci:
	./config deci el9
vdeci8:
	./config deci el8
vdeci9:
	./config deci el9
vdeci10:
	./config deci el10
vdeci12:
	./config deci d12
vdeci13:
	./config deci d13
vdeci22:
	./config deci u22
vdeci24:
	./config deci u24

#------------------------------#
# simu, 20 nodes, the simubox
#------------------------------#
# complex 20-node simubox for production simulation & complete testing

simu:   del vsimu   up ssh
simu8:  del vsimu8  up ssh
simu9:  del vsimu9  up ssh
simu10: del vsimu10 up ssh
simu12: del vsimu12 up ssh
simu13: del vsimu13 up ssh
simu22: del vsimu22 up ssh
simu24: del vsimu24 up ssh

vs: vsimu
vsimu:
	./config simu el9
vsimu8:
	./config simu el8
vsimu9:
	./config simu el9
vsimu10:
	./config simu el10
vsimu12:
	./config simu d12
vsimu13:
	./config simu d13
vsimu22:
	./config simu u22
vsimu24:
	./config simu u24

#------------------------------#
# dual, 2-node, seldom used
#------------------------------#
# 2-node environment

dual:   del vdual   up ssh
dual8:  del vdual8  up ssh
dual9:  del vdual9  up ssh
dual10: del vdual10 up ssh
dual12: del vdual12 up ssh
dual13: del vdual13 up ssh
dual22: del vdual22 up ssh
dual24: del vdual24 up ssh

vdual:
	./config dual el9
vdual8:
	./config dual el8
vdual9:
	./config dual el9
vdual10:
	./config dual el10
vdual12:
	./config dual d12
vdual13:
	./config dual d13
vdual22:
	./config dual u22
vdual24:
	./config dual u24

#------------------------------#
# trio, 3-node, seldom used
#------------------------------#
# 3-node environment

trio:   del vtrio   up ssh
trio8:  del vtrio8  up ssh
trio9:  del vtrio9  up ssh
trio10: del vtrio10 up ssh
trio12: del vtrio12 up ssh
trio13: del vtrio13 up ssh
trio22: del vtrio22 up ssh
trio24: del vtrio24 up ssh

vtrio:
	./config trio el9
vtrio8:
	./config trio el8
vtrio9:
	./config trio el9
vtrio10:
	./config trio el10
vtrio12:
	./config trio d12
vtrio13:
	./config trio d13
vtrio22:
	./config trio u22
vtrio24:
	./config trio u24

#------------------------------#
# minio, 4-node, seldom used
#------------------------------#
# 4-node environment

minio:   del vminio   up ssh
minio8:  del vminio8  up ssh
minio9:  del vminio9  up ssh
minio10: del vminio10 up ssh
minio12: del vminio12 up ssh
minio13: del vminio13 up ssh
minio22: del vminio22 up ssh
minio24: del vminio24 up ssh

vminio:
	./config minio el9
vminio8:
	./config minio el8
vminio9:
	./config minio el9
vminio10:
	./config minio el10
vminio12:
	./config minio d12
vminio13:
	./config minio d13
vminio22:
	./config minio u22
vminio24:
	./config minio u24

#------------------------------#
# citus, 13-node, seldom used
#------------------------------#
citus:   del vcitus   up ssh
citus8:  del vcitus8  up ssh
citus9:  del vcitus9  up ssh
citus10: del vcitus10 up ssh
citus12: del vcitus12 up ssh
citus13: del vcitus13 up ssh
citus22: del vcitus22 up ssh
citus24: del vcitus24 up ssh

vcitus:
	./config citus el9
vcitus8:
	./config citus el8
vcitus9:
	./config citus el9
vcitus10:
	./config citus el10
vcitus12:
	./config citus d12
vcitus13:
	./config citus d13
vcitus22:
	./config citus u22
vcitus24:
	./config citus u24

###############################################################
#                        Inventory                            #
###############################################################
.PHONY: default new dns ssh sshb start up down dw halt clean del destroy nuke st status list pause suspend resume info \
		oss pro rpm deb all vo vp vr vd va \
		meta meta8 meta9 meta10 meta12 meta13 meta22 meta24 vm vmeta vmeta8 vmeta9 vmeta10 vmeta12 vmeta13 vmeta22 vmeta24 \
		full full8 full9 full10 full12 full13 full22 full24 vf vfull vfull8 vfull9 vfull10 vfull12 vfull13 vfull22 vfull24 \
		deci deci8 deci9 deci10 deci12 deci13 deci22 deci24 vdc vdeci vdeci8 vdeci9 vdeci10 vdeci12 vdeci13 vdeci22 vdeci24 \
		simu simu8 simu9 simu10 simu12 simu13 simu22 simu24 vs vsimu vsimu8 vsimu9 vsimu10 vsimu12 vsimu13 vsimu22 vsimu24 \
		dual dual8 dual9 dual10 dual12 dual13 dual22 dual24 vdual vdual8 vdual9 vdual10 vdual12 vdual13 vdual22 vdual24 \
		trio trio8 trio9 trio10 trio12 trio13 trio22 trio24 vtrio vtrio8 vtrio9 vtrio10 vtrio12 vtrio13 vtrio22 vtrio24 \
		minio minio8 minio9 minio10 minio12 minio13 minio22 minio24 vminio vminio8 vminio9 vminio10 vminio12 vminio13 vminio22 vminio24 \
		citus citus8 citus9 citus10 citus12 citus13 citus22 citus24 vcitus vcitus8 vcitus9 vcitus10 vcitus12 vcitus13 vcitus22 vcitus24

###############################################################
