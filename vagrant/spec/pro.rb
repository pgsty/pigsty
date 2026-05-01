# pro: pigsty 5-node PRO building environment templates

Specs = [

  # Rocky Linux 8
  { "name" => "el8",    "ip" => "10.10.10.8" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-8"     },

  # Rocky Linux 9
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-9"     },

  # Debian 12.9
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },

  # Ubuntu 22.04.3
  { "name" => "u22",    "ip" => "10.10.10.22",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-22.04" },

  # Ubuntu 24.04.2
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

]
