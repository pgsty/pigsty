# simu: pigsty complex 20-node simubox for production simulation & complete testing

Specs = [


  # 3 x infra nodes
  { "name" => "meta1"  , "ip" => "10.10.10.10" , "cpu" => "4" , "mem" => "16384" ,  "image" => "bento/rockylinux-9"  },
  { "name" => "meta2"  , "ip" => "10.10.10.11" , "cpu" => "4" , "mem" => "16384" ,  "image" => "bento/rockylinux-9"  },
  { "name" => "meta3"  , "ip" => "10.10.10.12" , "cpu" => "4" , "mem" => "16384" ,  "image" => "bento/rockylinux-9"  },

  # 2 x haproxy
  { "name" => "proxy1" , "ip" => "10.10.10.18" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "proxy2" , "ip" => "10.10.10.19" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },

  # 4 x minio
  { "name" => "minio1" , "ip" => "10.10.10.21" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "minio2" , "ip" => "10.10.10.22" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "minio3" , "ip" => "10.10.10.23" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "minio4" , "ip" => "10.10.10.24" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },

  # 5 x etcd
  { "name" => "etcd1"  , "ip" => "10.10.10.25" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "etcd2"  , "ip" => "10.10.10.26" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "etcd3"  , "ip" => "10.10.10.27" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "etcd4"  , "ip" => "10.10.10.28" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "etcd5"  , "ip" => "10.10.10.29" , "cpu" => "1" , "mem" => "2048"  ,  "image" => "bento/rockylinux-9"  },

  # 6 x pgsql nodes
  { "name" => "pg-src-1" , "ip" => "10.10.10.31" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "pg-src-2" , "ip" => "10.10.10.32" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "pg-src-3" , "ip" => "10.10.10.33" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "pg-dst-1" , "ip" => "10.10.10.41" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "pg-dst-2" , "ip" => "10.10.10.42" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },
  { "name" => "pg-dst-3" , "ip" => "10.10.10.43" , "cpu" => "2" , "mem" => "4096"  ,  "image" => "bento/rockylinux-9"  },

]
