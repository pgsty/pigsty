# Vagrant Environment

[Vagrant](https://www.vagrantup.com/) can create local VMs according to [specifications](#Specifications) in a declarative way.

[Virtualbox](https://www.virtualbox.org/) is used as the default provider, and [`libvirt`](https://vagrant-libvirt.github.io/vagrant-libvirt/) is also supported.



--------

## Quick Start

Create pre-configured environment with `make` shortcuts:

```bash
make meta       # 1-node Ubuntu 24.04 devbox for quick start, dev, test & playground
make full       # 4-node Ubuntu 24.04 sandbox for HA-testing & feature demonstration
make simu       # 20-node Ubuntu 24.04 simubox for production environment simulation

# seldom used templates:
make dual       # 2-node env
make trio       # 3-node env
```

You can use variant alias to create environment with different base image:

```bash
make meta9      # create singleton-meta node with EL9 base image
make full22     # create 4-node sandbox with Ubuntu 22.04 base image
make full26     # create 4-node sandbox with Ubuntu 26.04 base image
make simu12     # create 20-node simulation env with Debian 12 base image
...             # available suffix: 8,9,10,12,13,22,24,26
```

You can also launch pigsty building env with these alias, base image will not be substituted:

```bash
make oss        # 4-node oss building environment
make pro        # 6-node pro building environment
make rpm        # 2-node el9/el10 building env
make deb        # 5-node debian12/13 + ubuntu22/24/26 building env
make all        # 7-node building env with all base images
```

--------

## Specifications

`Vagrantfile` is a ruby script file describing VM nodes. Here are some default specs of Pigsty.

|        Templates        |  Nodes  |      Spec       |         Comment         |  Alias  |
|:-----------------------:|:-------:|:---------------:|:-----------------------:|:-------:|
| [meta.rb](spec/meta.rb) | 1 node  |    2c4g x 1     |    Single Node Meta     | Devbox  |
| [dual.rb](spec/dual.rb) | 2 node  |    1c2g x 2     |       Dual Nodes        |         |
| [trio.rb](spec/trio.rb) | 3 node  |    1c2G x 3     |       Three Nodes       |         |
| [full.rb](spec/full.rb) | 4 node  | 2c4g + 1c2g x 3 |  Full-Featured 4 Node   | Sandbox |
| [simu.rb](spec/simu.rb) | 20 node |      misc       |   Prod Env Simulation   | Simubox |
|  [all.rb](spec/all.rb)  | 7 node  |    2c2g x 7     | 7-Node All Building Env |         |

Each spec file contains a `Specs` variable describe VM nodes. For example, the [`full.rb`](spec/full.rb) contains:

```ruby
# full: pigsty full-featured 4-node sandbox for HA-testing & tutorial & practices

Specs = [
  { "name" => "meta"   , "ip" => "10.10.10.10" ,  "cpu" => "2" ,  "mem" => "4096" ,  "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-1" , "ip" => "10.10.10.11" ,  "cpu" => "1" ,  "mem" => "2048" ,  "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-2" , "ip" => "10.10.10.12" ,  "cpu" => "1" ,  "mem" => "2048" ,  "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-3" , "ip" => "10.10.10.13" ,  "cpu" => "1" ,  "mem" => "2048" ,  "image" => "cloud-image/ubuntu-24.04" },
]

```

The system disk defaults to 64 GiB. Set `"root_disk" => "<GiB>"` on a node to override it;
the building specs (`all`, `rpm`, `deb`, `oss`, and `pro`) use 128 GiB system disks.
The existing `disk` field remains the size of the additional `/data` disk and defaults to 128 GiB.
Both providers create sparse disks, and the supported `cloud-image/*` boxes grow their root partition
and filesystem automatically on first boot.

For libvirt, both imported base images and VM volumes are stored in its `default` storage pool.
Check the pool target with `virsh pool-dumpxml default`; on hosts with a dedicated data filesystem,
place that target there (for example, `/data/libvirt/images`). The separate Vagrant box cache lives
under `~/.vagrant.d/boxes`; relocate it or set `VAGRANT_HOME` when the home filesystem is constrained.

You can use specs with the [`config`](config) script, it will render the final `Vagrantfile` according to the spec and other options

```bash
	cd ~/pigsty
	vagrant/config [spec] [image] [scale] [provider]

	vagrant/config meta u24            # use the 1-node spec, use Ubuntu 24.04 base image
	vagrant/config meta u26            # use the 1-node spec, use Ubuntu 26.04 base image
	vagrant/config dual el9            # use the 2-node spec, use el9 image instead 
	vagrant/config trio d12 2          # use the 3-node spec, use debian12 image, double the cpu/mem resource
	vagrant/config full u22 4          # use the 4-node spec, use ubuntu22 image instead, use 4x cpu/mem resource         
	vagrant/config simu u24 1 libvirt  # use the 20-node spec, use ubuntu24 image instead, use libvirt as provider instead of virtualbox
```

You can scale the resource unit with environment variable `VM_SCALE`, the default value is `1`.

For example, if you use `VM_SCALE=2` with `vagrant/config meta u24`, it will double the cpu / mem resources of the meta
node.

```bash
Specs = [
  { "name" => "meta" , "ip" => "10.10.10.10", "cpu" => "8" , "mem" => "16384" , "image" => "cloud-image/ubuntu-24.04" },
]
```

--------

## Shortcuts

After describing the VM nodes with specs and generate the `vagrant/Vagrantfile`. you can create the VMs with `vagrant up` command.

Pigsty templates will use your `~/.ssh/id_rsa[.pub]` as the default ssh key for vagrant provisioning.

Make sure you have a valid ssh key pair before you start, you can generate one by: `ssh-keygen -t rsa -b 2048`

There are some makefile shortcuts that wrap the vagrant commands, you can use them to manage the VMs.

```bash
make         # = make start
make new     # destroy existing vm and create new ones
make ssh     # write VM ssh config to ~/.ssh/     (required)
make dns     # write VM DNS records to /etc/hosts (optional)
make start   # launch VMs and write ssh config    (up + ssh) 
make up      # launch VMs with vagrant up
make halt    # shutdown VMs (down,dw)
make clean   # destroy VMs (clean/del/destroy)
make status  # show VM status (st)
make pause   # pause VMs (suspend,pause)
make resume  # pause VMs (resume)
make nuke    # destroy all vm & volumes with virsh (if using libvirt) 
```


--------

## Boxes

Default `VM_IMAGE` aliases (major-only):

```bash
el8  -> cloud-image/rocky-8
el9  -> cloud-image/rocky-9
el10 -> cloud-image/rocky-10
d12  -> cloud-image/debian-12
d13  -> cloud-image/debian-13
u22  -> cloud-image/ubuntu-22.04
u24  -> cloud-image/ubuntu-24.04
u26  -> cloud-image/ubuntu-26.04
```

The generator pins every supported `cloud-image/*` box to the newest version verified on Vagrant Cloud, for reproducible amd64 and arm64 environments. Current pins are:

| Alias  | Vagrant box                | Version           |
|--------|----------------------------|-------------------|
| `el8`  | `cloud-image/rocky-8`      | `8.10.20240528.0` |
| `el9`  | `cloud-image/rocky-9`      | `9.8.20260525.0`  |
| `el10` | `cloud-image/rocky-10`     | `10.2.20260525.0` |
| `d12`  | `cloud-image/debian-12`    | `20260806.2562.0` |
| `d13`  | `cloud-image/debian-13`    | `20260810.2566.0` |
| `u22`  | `cloud-image/ubuntu-22.04` | `20260810.0.0`    |
| `u24`  | `cloud-image/ubuntu-24.04` | `20260801.0.0`    |
| `u26`  | `cloud-image/ubuntu-26.04` | `20260731.0.0`    |

AlmaLinux and legacy shortcuts are pinned by the same generator:

| Alias    | Vagrant box                | Version           | Comment                             |
|----------|----------------------------|-------------------|-------------------------------------|
| `alma8`  | `cloud-image/almalinux-8`  | `8.10.20260803`   | EL8 vendor variant                  |
| `alma9`  | `cloud-image/almalinux-9`  | `9.8.20260810`    | EL9 vendor variant                  |
| `alma10` | `cloud-image/almalinux-10` | `10.2.20260526.0` | EL10 vendor variant                 |
| `d11`    | `cloud-image/debian-11`    | `20260618.2513.0` | EOL, outside the support matrix     |
| `u20`    | `cloud-image/ubuntu-20.04` | `20250624.0.0`    | EOL, outside the support matrix     |

Legacy `generic/*` fixtures (`rhel7/8/9`, `oracle7/8/9`, `centos7`) are pinned to their last published box release `4.3.12`.
These discontinued images are amd64-only (except `generic/rhel9`) and no longer track current OS minors,
so they remain only for explicit vendor-compatibility experiments.


--------

## Caveat

If you are using virtualbox as vagrant provider,
you have to add `10.0.0.0/8` to `/etc/vbox/networks.conf`,
so you can use the `10.x.x.x` CIDR as host-only networks.

```bash
# /etc/vbox/networks.conf
* 10.0.0.0/8
```

Reference: https://discuss.hashicorp.com/t/vagran-can-not-assign-ip-address-to-virtualbox-machine/30930/3
