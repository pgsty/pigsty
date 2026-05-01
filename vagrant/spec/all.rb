# all: pigsty current EL/Debian/Ubuntu Cloud Image matrix

Specs = [

  # EL 9 / 10 (Rocky Linux Cloud Image)
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/rocky-9"     },
  { "name" => "el10",   "ip" => "10.10.10.10",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/rocky-10"    },

  # Debian 12 / 13
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/debian-12"  },
  { "name" => "d13",    "ip" => "10.10.10.13",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/debian-13"  },

  # Ubuntu 22.04 / 24.04 / 26.04
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/ubuntu-22.04" },
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/ubuntu-24.04" },
  { "name" => "u26",    "ip" => "10.10.10.26",  "cpu" => "2",  "mem" => "4096",  "image" =>  "cloud-image/ubuntu-26.04" },

]
