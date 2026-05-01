# pigsty os checking environment for rhel compatible distribution & ubuntu & debian

Specs = [

  { "name" => "build-el7" ,"ip" => "10.10.10.7"    , "cpu" => "4"    , "mem" => "8182"    , "image" =>  "generic/centos7"         },
  { "name" => "build-el8" ,"ip" => "10.10.10.8"    , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/rocky-8"      },
  { "name" => "build-el9" ,"ip" => "10.10.10.9"    , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/rocky-9"      },
  { "name" => "debian11"  ,"ip" => "10.10.10.11"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/debian-11"       },
  { "name" => "debian12"  ,"ip" => "10.10.10.12"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/debian-12"       },
  { "name" => "ubuntu20"  ,"ip" => "10.10.10.20"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/ubuntu-20.04"      },
  { "name" => "ubuntu22"  ,"ip" => "10.10.10.22"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "cloud-image/ubuntu-22.04"      },
  { "name" => "rhel7"     ,"ip" => "10.10.10.27"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/rhel7"           },
  { "name" => "rhel8"     ,"ip" => "10.10.10.28"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/rhel8"           },
  { "name" => "rhel9"     ,"ip" => "10.10.10.29"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/rhel9"           },
  { "name" => "alma8"     ,"ip" => "10.10.10.38"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/alma8"           },
  { "name" => "alma9"     ,"ip" => "10.10.10.39"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/alma9"           },
  { "name" => "oracle8"   ,"ip" => "10.10.10.48"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/oracle8"         },
  { "name" => "oracle9"   ,"ip" => "10.10.10.49"   , "cpu" => "4"    , "mem" => "8192"    , "image" =>  "generic/oracle9"         },

]
