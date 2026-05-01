# pigsty citus/etcd testing environment with 5 nodes: 2C4G + 4 x 1C1G

Specs = [
  { "name" => "meta"   , "ip" => "10.10.10.10" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-1" , "ip" => "10.10.10.11" , "cpu" => "1" , "mem" => "1024" , "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-2" , "ip" => "10.10.10.12" , "cpu" => "1" , "mem" => "1024" , "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-3" , "ip" => "10.10.10.13" , "cpu" => "1" , "mem" => "1024" , "image" => "cloud-image/ubuntu-24.04" },
  { "name" => "node-4" , "ip" => "10.10.10.14" , "cpu" => "1" , "mem" => "1024" , "image" => "cloud-image/ubuntu-24.04" },
]

