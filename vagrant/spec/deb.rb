# deb: pigsty 4-node debian/ubuntu building environment templates : Debian12 / Debian13 / Ubuntu22.04 / Ubuntu24.04

Specs = [

  # Debian 12/13
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },
  { "name" => "d13",    "ip" => "10.10.10.13",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/debian-13"  },

  # Ubuntu 22.04 / 24.04
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

]
