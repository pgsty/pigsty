# deb: pigsty current debian/ubuntu Cloud Image building environment templates

Specs = [

  # Debian 12 / 13
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },
  { "name" => "d13",    "ip" => "10.10.10.13",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-13"  },

  # Ubuntu 22.04 / 24.04 / 26.04
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },
  { "name" => "u26",    "ip" => "10.10.10.26",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-26.04" },

]
