# old: pigsty legacy debian/ubuntu Cloud Image templates

Specs = [

  # EL7 has no Rocky Cloud Image for VirtualBox ARM64.
  { "name" => "d11",    "ip" => "10.10.10.11",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/debian-11"    },
  { "name" => "u20",    "ip" => "10.10.10.20",  "cpu" => "2",  "mem" => "2048",  "image" =>  "cloud-image/ubuntu-20.04" },

]
