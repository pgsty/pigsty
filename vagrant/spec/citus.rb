# citus: 6-group citus cluster with 1 infra node (13 nodes total)

Specs = [

  # 1 x infra node (also serves as coordinator pg-citus0)
  { "name" => "meta"     , "ip" => "10.10.10.10" , "cpu" => "2" , "mem" => "4096" ,  "image" => "generic/rocky9"  },

  # 6 x citus worker groups (2 nodes each: primary + replica)
  { "name" => "citus1-1" , "ip" => "10.10.10.21" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus1-2" , "ip" => "10.10.10.22" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

  { "name" => "citus2-1" , "ip" => "10.10.10.31" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus2-2" , "ip" => "10.10.10.32" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

  { "name" => "citus3-1" , "ip" => "10.10.10.41" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus3-2" , "ip" => "10.10.10.42" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

  { "name" => "citus4-1" , "ip" => "10.10.10.51" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus4-2" , "ip" => "10.10.10.52" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

  { "name" => "citus5-1" , "ip" => "10.10.10.61" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus5-2" , "ip" => "10.10.10.62" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

  { "name" => "citus6-1" , "ip" => "10.10.10.71" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },
  { "name" => "citus6-2" , "ip" => "10.10.10.72" , "cpu" => "1" , "mem" => "2048" ,  "image" => "generic/rocky9"  },

]
