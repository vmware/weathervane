# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package WeathervaneTypes;

# predeclare types
use MooseX::Types -declare => [
	qw(
	  ServiceType
	  )
];

# import builtin types
use MooseX::Types::Moose qw/Str Int/;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

our @workloadImpls = ('auction');

# valid service types 
our %serviceTypes = ( 
	'auction' => ['coordinationServer', 'webServer', 'dbServer', 'nosqlServer', 'msgServer', 'appServer', 'auctionBidServer'], 
);

# services that can be run on docker
our %dockerServiceTypes = ( 
	'auction' => ['webServer', 'dbServer', 'nosqlServer', 'msgServer', 'appServer', 'auctionBidServer', 'coordinationServer'], 
);


# Services are started in the order data->backend->frontend
# Within each type they are started in the given order ad stopped in reverse order

# Map workload to serviceTier to serviceType in each tier
our %workloadToServiceTypes = ('auction' => {
	'data' => ['dbServer', 'nosqlServer', 'msgServer', 'coordinationServer'],
	'backend' => ['appServer', 'auctionBidServer'],
	'frontend' => ['webServer'],
	'infrastucture' => [],
	}
);

# Valid service implementations for each service type
our %serviceImpls = (
	'coordinationServer'    => ['zookeeper'],
	'webServer'   => [ 'nginx' ],
	'appServer'   => [ 'tomcat' ],
	'auctionBidServer'   => [ 'auctionbidservice' ],
	'nosqlServer' => ['cassandra'],
	'dbServer'    => [ 'postgresql' ],
	'msgServer'   => ['rabbitmq'],
);

our @virtualInfrastructureTypes = ('vsphere');
our @imageStoreTypes            = ( 'memory', 'cassandra' );
our @oses                  = ('centos6', 'ubuntu');
our @viTypes                    = ('vsphere');
our @viHostTypes                = ('esxi');
our @viMgmtHostTypes            = ('virtualCenter');

our @runStrategy   = ( 'fixed', 'interval', 'findMaxSingleRun', 'findMaxSingleRunSync', 
							'findMaxSingleRunWithScaling',
							'findMaxMultiAI', 'findMaxMultiRun', 'single' );
our @runProcedures = ( 'full',   'loadOnly', 'prepareOnly', 'runOnly', 'stop' );

# These are all of the workload profiles that are supported for each workload
our %workloadProfiles = (
	"auction" => ["official", "official2"],
	);

# These are all of the appInstance sizes that are supported for each workload
our %appInstanceSizes = (
    "auction" => ["micro", "microLowCpu", "xsmall", "small2", "small", "smallLowCpu", "medium"],
    );

# These are the allowed values for appIngressMethod
our %appIngressMethods = (
    "auction" => ["loadbalancer", "nodeport", "clusterip",],
    );

# Define a ServiceType to be one of a set of strings
subtype ServiceType, as Str, where { $_ ~~ @{$serviceTypes{'auction'}} }, message { "That is not a valid Weathervane ServiceType" };

