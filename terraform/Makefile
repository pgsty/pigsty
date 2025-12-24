#==============================================================#
# File      :   Makefile
# Desc      :   terraform admin shortcuts
# Ctime     :   2024-12-24
# Mtime     :   2024-12-24
# Path      :   Makefile
# Author    :   Ruohang Feng (rh@vonng.com)
# License   :   Apache-2.0 @ https://pigsty.io/docs/about/license/
#==============================================================#


###############################################################
#                         Publishing                          #
###############################################################
u:
	terraform apply -auto-approve
	sleep 15
	./ssh
apply:
	terraform apply

d:
	terraform destroy -auto-approve
destroy:
	terraform destroy
out:
	terraform output
ssh:
	./ssh
r: reset
reset:
	git restore terraform.tf


###############################################################
#                         Inventory                           #
###############################################################
.PHONY: u d apply destroy out ssh r rest
