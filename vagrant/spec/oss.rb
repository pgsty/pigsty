# pro: pigsty 5-node PRO building environment templates

Specs = [

  # RockyLinux 9.5
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "1",  "mem" => "2048",  "image" =>  "bento/rockylinux-9"     },

  # Debian 12.x
  { "name" => "d12",    "ip" => "10.10.10.12",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/debian-12"  },

  # Ubuntu 24.04.2
  { "name" => "u24",    "ip" => "10.10.10.24",  "cpu" => "1",  "mem" => "2048",  "image" =>  "bento/ubuntu-24.04"     },

]
