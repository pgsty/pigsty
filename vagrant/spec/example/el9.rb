# pigsty el8 testing environment with 3 nodes: rhel, rocky, and alma linux, 3 x 2C4G

Specs = [
  { "name" => "meta"   , "ip" => "10.10.10.10" , "cpu" => "2" , "mem" => "4096" , "image" =>  "generic/rhel9"       },
  { "name" => "node-1" , "ip" => "10.10.10.11" , "cpu" => "2" , "mem" => "4096" , "image" =>  "cloud-image/rocky-9"  },
  { "name" => "node-2" , "ip" => "10.10.10.12" , "cpu" => "2" , "mem" => "4096" , "image" =>  "generic/alma9"       },
]

