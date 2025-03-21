# pigsty el7 testing environment with 3 nodes: centos, rhel, and oracle linux, 3 x 2C4G

Specs = [
  { "name" => "meta"   , "ip" => "10.10.10.10" , "cpu" => "2" , "mem" => "4096" , "image" =>  "generic/centos7" },
  { "name" => "node-1" , "ip" => "10.10.10.11" , "cpu" => "2" , "mem" => "4096" , "image" =>  "generic/rhel7"   },
  { "name" => "node-2" , "ip" => "10.10.10.12" , "cpu" => "2" , "mem" => "4096" , "image" =>  "generic/oracle7" },
]

