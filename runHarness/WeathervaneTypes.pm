# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
	'auction' => ['configurationManager', 'elasticityService', 'coordinationServer', 'ipManager', 'lbServer', 'webServer', 'dbServer', 'nosqlServer', 'fileServer', 'msgServer', 'appServer'], 
);

# valid service tiers
our %serviceTiers = ( 
	'auction' => ['infrastructure', 'data', 'backend', 'frontend'], 
);

# services that can be run on docker
our %dockerServiceTypes = ( 
	'auction' => ['lbServer', 'webServer', 'dbServer', 'nosqlServer', 'msgServer', 'appServer', 'coordinationServer', 'configurationManager'], 
);


# Services are started in the order data->backend->frontend
# Within each type they are started in the given order ad stopped in reverse order

# Map workload to serviceTier to serviceType in each tier
our %workloadToServiceTypes = ('auction' => {
	'infrastructure' => ['configurationManager', 'elasticityService'],
	'data' => ['dbServer', 'nosqlServer', 'fileServer'],
	'backend' => ['msgServer', 'coordinationServer', 'appServer', 'webServer'],
	'frontend' => ['lbServer', 'ipManager'],
	}
);

# Valid service implementations for each service type
our %serviceImpls = (
	'ipManager'   => ['keepalived'],
	'configurationManager'    => ['webConfig'],
	'elasticityService'    => ['scheduledES', 'simpleES'],
	'coordinationServer'    => ['zookeeper'],
	'lbServer'    => ['haproxy'],
	'webServer'   => [ 'httpd', 'nginx' ],
	'appServer'   => [ 'tomcat' ],
	'dbServer'    => [ 'mysql', 'postgresql' ],
	'nosqlServer' => ['mongodb'],
	'msgServer'   => ['rabbitmq'],
	'fileServer'  => ['nfs'],
);

our @virtualInfrastructureTypes = ('vsphere');
our @imageStoreTypes            = ( 'filesystem', 'filesystemApp', 'memory', 'mongodb' );
our @oses                  = ('centos6', 'ubuntu');
our @viTypes                    = ('vsphere');
our @viHostTypes                = ('esxi');
our @viMgmtHostTypes            = ('virtualCenter');

our @runStrategy   = ( 'single', 'findMax', 'targetUtilization' );
our @runProcedures = ( 'full',   'loadOnly', 'prepareOnly', 'runOnly', 'stop' );

our @pinModes = ( 'all', 'odd', 'even');

# These are all of the workload profiles that are supported
our %workloadProfiles = (
	"auction" => 
	["official",      "attendAuctions",       "addItem",            "getImageForItem",
	"getBidHistory", "getAttendanceHistory", "getPurchaseHistory", "getItemDetail",
	"loginLogout",   "addImageForItem",      "joinLeave",          "noAddImages"],
	);

# Define a ServiceType to be one of a set of strings
subtype ServiceType, as Str, where { $_ ~~ @{$serviceTypes{'auction'}} }, message { "That is not a valid Weathervane ServiceType" };

