# Weathervane Regression Tests

This directory contains the configuration files that the Weathervane team uses for its system-level regression-test configurations.  It is not expected that anyone outside the Weathervane project team will be able to run these tests directly, as they rely on the hardware and VM configuration on our regression testbed.  However, these files can serve as useful examples of Weathervane configuration files.

## Test Cases

Test Case 0: 
This tests the default configuration.  All of the parameters have their default values.

Test Case 1: 
This is a test case with a small configuration.  
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded

Test Case 2: 
This is a test case with a medium configuration.  
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded

Test Case 3: 
This is a test case with a large configuration.  
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 4: 
This is a test case with a small configuration.  
webServerImpl/dbServerImpl/imageStoreType = httpd/mysql/mongodb
single mongoDb

Test Case 5: 
This is a test case with a medium configuration.  
webServerImpl/dbServerImpl/imageStoreType = httpd/mysql/filesystem
single mongodb

Test Case 6: 
This is a test case with a large configuration.  
webServerImpl/dbServerImpl/imageStoreType = httpd/mysql/filesystem
single mongodb
mongoDb sharded
useVirtualIp=true

Test Case 7: 
This is a test case with a small configuration.  
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb replicated

Test Case 8: 
This is a test case with a large configuration.  
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb replicated
useVirtualIp=true

Test Case 9: 
This is a test case with a large configuration.  
RunStrategy = targetUtilization, targetUtilizationServiceType = dbServer
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 10: 
This is a test case with a large configuration.  
Uses userLoadPath without repeats
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 11: 
This is a test case with a large configuration.  
Uses userLoadPath with repeats
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 12: 
This is a test case with a large configuration.  
Uses configPath with repeats
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 11: 
This is a test case with a large configuration.  
Uses userLoadPath and configPath
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 14: 
This is a test case with a small configuration.  
runStrategy = findMax
webServerImpl/dbServerImpl/imageStoreType = httpd/mysql/mongodb
single mongoDb

Test Case 15: 
This is a test case with a large configuration.  
useDocker = true
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 16: 
This is a test case with a large configuration.  
useDocker = true, dockerNet = host
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb sharded
useVirtualIp=true

Test Case 17: 
This is a test case with a large configuration.  
useDocker = true, dockerNet = host, run in large Docker-only VMs
webServerImpl/dbServerImpl/imageStoreType = nginx/postgresql/mongodb
mongoDb single
useVirtualIp=true

Test Case 18:
This is a test case with two workloads, each with two appInstances.
Each appInstance uses a different combination of services.
W1I1: nginx/postgres/filesystem
W1I2: httpd/postgres/mongodb
W2I1: nginx/mysql/filesystem
W2I2: nginx/postgres/mongodb/docker

Test Case 19:
This is a test case that uses the configuration from a VMmark 3 tile.

## Regression Testbed and VM Placement Information

* Cluster is three Dell R730 with two Xeon E5-2687W v3 @ 3.10GHz (Haswell).  
  * HyperThreading and Turbo Boost are disabled
  * All Auctionxxx VMs and data services VMs are on vsanDatastore
  * Test18xxx non-data services VMs are on FileData datastore (all SSDs)
  * VMmarkxxx non-data services VMs are on DB1Data datastore (all SSDs)
- The VM to Host assignment for Test 0 is as follows:
  * All services run on AuctionDriver1 on w1-perf-h04.
- The VM to Host assignment for Tests 1, 2,and 3 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1, AuctionWeb4, AuctionApp3, AuctionApp6, AuctionMsg1, AuctionNosql1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionCs2, AuctionLb2, AuctionWeb2, AuctionApp1, AuctionApp4, AuctionApp7, AuctionMsg2, AuctionNosql2, AuctionNosql3,
  * w1-perf-h03 (20 Cores, 256GB): AuctionCs3, AuctionLb3, AuctionWeb3, AuctionApp2, AuctionApp5, AuctionApp8, AuctionDb1
- The VM to Host assignment for Test 4 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1,, AuctionMsg1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionApp1, Test4Nosql1,
  * w1-perf-h03 (20 Cores, 256GB): Test4Db1
- The VM to Host assignment for Tests 5, 6, and 14 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1, AuctionWeb4, AuctionApp3, AuctionApp6, AuctionMsg1, Test5Nosql1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionCs2, AuctionLb2, AuctionWeb2, AuctionApp1, AuctionApp4, AuctionApp7, AuctionMsg2, Test5File1,
  * w1-perf-h03 (20 Cores, 256GB): AuctionCs3, AuctionLb3, AuctionWeb3, AuctionApp2, AuctionApp5, AuctionApp8, Test5Db1 
- The VM to Host assignment for Tests 7, 8, and 9 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1, AuctionWeb4, AuctionApp3, AuctionApp6, AuctionMsg1, Test7Nosql1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionCs2, AuctionLb2, AuctionWeb2, AuctionApp1, AuctionApp4, AuctionApp7, AuctionMsg2, Test7Nosql2, Test7Nosql3
  * w1-perf-h03 (20 Cores, 256GB): AuctionCs3, AuctionLb3, AuctionWeb3, AuctionApp2, AuctionApp5, AuctionApp8, Test7Db1 
- The VM to Host assignment for Tests 10, 11, 12, and 13 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1, AuctionWeb4, AuctionApp3, AuctionApp6, AuctionMsg1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionCs2, AuctionLb2, AuctionWeb2, AuctionApp1, AuctionApp4, AuctionApp7, AuctionMsg2, Test10Nosql1,
  * w1-perf-h03 (20 Cores, 256GB): AuctionCs3, AuctionLb3, AuctionWeb3, AuctionApp2, AuctionApp5, AuctionApp8, Test10Db1
- The VM to Host assignment for Tests 15 and 16 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): AuctionCm1, AuctionCs1, AuctionLb1, AuctionWeb1, AuctionWeb4, AuctionApp3, AuctionApp6, AuctionMsg1,
  * w1-perf-h02 (20 Cores, 256GB): AuctionCs2, AuctionLb2, AuctionWeb2, AuctionApp1, AuctionApp4, AuctionApp7, AuctionMsg2, Test15Nosql1,
  * w1-perf-h03 (20 Cores, 256GB): AuctionCs3, AuctionLb3, AuctionWeb3, AuctionApp2, AuctionApp5, AuctionApp8, Test15Db1
- The VM to Host assignment for Test 17 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): Test17Docker1 ()
  * w1-perf-h02 (20 Cores, 256GB): Test17Docker2 ()
  * w1-perf-h03 (20 Cores, 256GB): Test17Docker3 ()
- The VM to Host assignment for Test 18 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): W1I1Lb1, W1I1Web1, W1I1App1, W1I1App2, W1I1Nosql1, W1I1Msg1, W1I1Db1, W1I1File1
  * w1-perf-h02 (20 Cores, 256GB): W1I2Web1, W1I2App1, W1I2Nosql1, W1I2Msg1, W1I2Db1, W2I2Web1, W2I2App1, W2I2Nosql1, W2I2Msg1, W2I2Db1
  * w1-perf-h03 (20 Cores, 256GB): W2I1Lb1, W2I1Web1, W2I1App1, W2I1App2, W2I1Nosql1, W2I1Msg1, W2I1Db1, W2I1File1
- The VM to Host assignment for Test 19 is as follows:
  * w1-perf-h01 (20 Cores, 256GB): VMmarkLb, VMmarkWebA, VMmarkWebB, VMmarkDb, VMmarkNosql
  * w1-perf-h02 (20 Cores, 256GB): VMmarkAppA, VMmarkAppB, VMmarkEAppA, VMmarkEAppB
  * w1-perf-h03 (20 Cores, 256GB): VMmarkELb, VMmarkEWebA, VMmarkEWebB, VMmarkEDb, VMmarkENosql

- The workload driver VMs will all run on the workloadDriver cluster
  - Cluster is two Dell R720 with two Xeon CPU E5-2690 0 @ 2.90GHz (Sandy Bridge)
  - HyperThreading and Turbo Boost are enabled
  - The VM to Host assignment is as follows:
    - w1-perf-h04: Driver1, 3, 5, 7, 9, 11, 13, 15
    - w1-perf-h05: Driver2, 4, 6, 8, 10, 12, 14, 16

