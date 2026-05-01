# pigsty build-check environment spec with 30 nodes

Specs = [

  { "name" => "build-el7"   , "ip" => "10.10.10.7"  , "cpu" => "4" , "mem" => "8182" , "image" => "generic/centos7"    },
  { "name" => "build-el8"   , "ip" => "10.10.10.8"  , "cpu" => "4" , "mem" => "8192" , "image" => "cloud-image/rocky-8" },
  { "name" => "build-el9"   , "ip" => "10.10.10.9"  , "cpu" => "4" , "mem" => "8192" , "image" => "cloud-image/rocky-9" },

  { "name" => "pg-el7v12-1" , "ip" => "10.10.10.72" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7v13-1" , "ip" => "10.10.10.73" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7v14-1" , "ip" => "10.10.10.74" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7v15-1" , "ip" => "10.10.10.75" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7v16-1" , "ip" => "10.10.10.76" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7test-1", "ip" => "10.10.10.77" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },
  { "name" => "pg-el7test-2", "ip" => "10.10.10.78" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/rhel7"      },
  { "name" => "pg-el7test-3", "ip" => "10.10.10.79" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/centos7"    },

  { "name" => "pg-el8v12-1" , "ip" => "10.10.10.82" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8v13-1" , "ip" => "10.10.10.83" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8v14-1" , "ip" => "10.10.10.84" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8v15-1" , "ip" => "10.10.10.85" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8v16-1" , "ip" => "10.10.10.86" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8test-1", "ip" => "10.10.10.87" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/rhel8"      },
  { "name" => "pg-el8test-2", "ip" => "10.10.10.88" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-8" },
  { "name" => "pg-el8test-3", "ip" => "10.10.10.89" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/alma8"      },

  { "name" => "pg-el9v12-1" , "ip" => "10.10.10.92" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9v13-1" , "ip" => "10.10.10.93" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9v14-1" , "ip" => "10.10.10.94" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9v15-1" , "ip" => "10.10.10.95" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9v16-1" , "ip" => "10.10.10.96" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9test-1", "ip" => "10.10.10.97" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/rhel9"      },
  { "name" => "pg-el9test-2", "ip" => "10.10.10.98" , "cpu" => "2" , "mem" => "4096" , "image" => "cloud-image/rocky-9" },
  { "name" => "pg-el9test-3", "ip" => "10.10.10.99" , "cpu" => "2" , "mem" => "4096" , "image" => "generic/alma9"      },

]