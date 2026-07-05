# pro: pigsty PRO building environment templates

Specs = [

  # Rocky Linux 9
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-9"     },

  # Rocky Linux 10
  { "name" => "el10",   "ip" => "10.10.10.10",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-10"    },

  # Debian 12.14
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"   },

  # Debian 13.5
  { "name" => "d13",    "ip" => "10.10.10.13",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-13"   },

  # Ubuntu 22.04.5
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },

  # Ubuntu 24.04.4
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

  # Ubuntu 26.04.0
  { "name" => "u26",    "ip" => "10.10.10.26",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-26.04" },

]
