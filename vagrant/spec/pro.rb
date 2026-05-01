# pro: pigsty PRO building environment templates

Specs = [

  # Rocky Linux 8
  { "name" => "el8",    "ip" => "10.10.10.8" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-8"     },

  # Rocky Linux 9
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-9"     },

  # Debian 12.13
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },

  # Ubuntu 22.04.5
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },

  # Ubuntu 24.04.4
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

  # Ubuntu 26.04.0
  { "name" => "u26",    "ip" => "10.10.10.26",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-26.04" },

]
