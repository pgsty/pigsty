# all: pigsty 7-node EL/Debian/Ubuntu building environment templates

Specs = [

  # EL 8 / 9 / 10
  { "name" => "el8",    "ip" => "10.10.10.8" ,  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-8" },
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-9" },
  { "name" => "el10",   "ip" => "10.10.10.10",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-10" },

  # Debian 12 / 13
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },
  { "name" => "d13",    "ip" => "10.10.10.13",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/debian-13"  },

  # Ubuntu 22.04 / 24.04
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

]
