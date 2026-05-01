# pro: pigsty 5-node PRO building environment templates

Specs = [

  # Rocky Linux 9
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/rocky-9"     },

  # Debian 12.x
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },

  # Ubuntu 24.04.2
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-24.04" },

]
