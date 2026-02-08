# rpm: pigsty 3-node Enterprise Linux building environment templates: EL8 / EL9 / EL10

Specs = [

  # EL 8 / 9 / 10 (AlmaLinux Cloud Image)
  { "name" => "el8",    "ip" => "10.10.10.8" ,  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-8" },
  { "name" => "el9",    "ip" => "10.10.10.9" ,  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-9" },
  { "name" => "el10",   "ip" => "10.10.10.10",  "cpu" => "1",  "mem" => "2048",  "image" =>  "cloud-image/almalinux-10" },

]
