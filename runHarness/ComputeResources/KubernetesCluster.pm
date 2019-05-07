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
package KubernetesCluster;

use Moose;
use MooseX::Storage;
use ComputeResources::Cluster;
use VirtualInfrastructures::VirtualInfrastructure;
use WeathervaneTypes;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;
use Utils qw(runCmd);

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Cluster';

has 'stopKubectlTop' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

has 'kubectlTopPodRunning' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

has 'kubectlTopNodeRunning' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
		
	super();
};

override 'registerService' => sub {
	my ( $self, $serviceRef ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $servicesRef    = $self->servicesRef;

	my $name = $serviceRef->name;
	$logger->debug( "Registering service $name with cluster ", $self->name );

	push @$servicesRef, $serviceRef;

};

sub kubernetesGetPods {
	my ( $self, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesGetPods in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl get pod --namespace=$namespace -o wide";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesGetPods failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	return $outString;
}

sub kubernetesDeleteAll {
	my ( $self, $resourceType, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesDeleteAll with resourceType $resourceType in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl delete $resourceType --all --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesDeleteAll failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
}

sub kubernetesDeleteAllWithLabel {
	my ( $self, $selector, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesDeleteAllWithLabel with label $selector in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	my $outString;
	my $cmdFailed;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl delete all --selector=$selector --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesDeleteAllWithLabel delete all failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl delete configmap --selector=$selector --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesDeleteAllWithLabel delete configmap failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
}

sub kubernetesDeleteAllWithLabelAndResourceType {
	my ( $self, $selector, $resourceType, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesDeleteAllWithLabelAndResourceType with resourceType $resourceType, label $selector in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl delete $resourceType --selector=$selector --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesDeleteAllWithLabelAndResourceType failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
}

sub kubernetesDelete {
	my ( $self, $resourceType, $resourceName, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesDelete resourceName $resourceName of type $resourceType in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl delete $resourceType $resourceName --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		if ( !($outString =~ /NotFound/) ) {
			die "kubernetesDelete failed: $cmdFailed";
		}
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
}

# Does a kubectl exec in the first pod where the impl label matches  
# serviceImplName.  It does the exec in the container with the same name.
sub kubernetesExecOne {
	my ( $self, $serviceTypeImpl, $commandString, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesExecOne exec $commandString for serviceTypeImpl $serviceTypeImpl, namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	# Get the list of pods
	my $cmd;
	my $outString;
	my $cmdFailed;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod -o=jsonpath='{.items[*].metadata.name}' --selector=impl=$serviceTypeImpl --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesExecOne get pod failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	my @names = split /\s+/, $outString;
	if ($#names < 0) {
		$console_logger->error("kubernetesExecOne: There are no pods with label $serviceTypeImpl in namespace $namespace");
		exit(-1);
	}
	
	# Get the name of the first pod
	my $podName = $names[0];
	
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl exec -c $serviceTypeImpl --namespace=$namespace $podName -- $commandString";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesExecOne exec failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
	return $outString;
	
}

# Does a kubectl exec in all p[ods] where the impl label matches  
# serviceImplName.  It does the exec in the container with the same name.
sub kubernetesExecAll {
	my ( $self, $serviceTypeImpl, $commandString, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesExecAll exec $commandString for serviceTypeImpl $serviceTypeImpl, namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	# Get the list of pods
	my $cmd;
	my $outString;
	my $cmdFailed;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod -o=jsonpath='{.items[*].metadata.name}' --selector=impl=$serviceTypeImpl --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesExecAll get pod failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	my @names = split /\s+/, $outString;
	if ($#names < 0) {
		$console_logger->error("kubernetesExecOne: There are no pods with label $serviceTypeImpl in namespace $namespace");
		exit(-1);
	}
	
	foreach my $podName (@names) { 	
		$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl exec -c $serviceTypeImpl --namespace=$namespace $podName -- $commandString";
		($cmdFailed, $outString) = runCmd($cmd);
		if ($cmdFailed) {
			die "kubernetesExecAll exec failed: $cmdFailed";
		}
		$logger->debug("Command: $cmd");
		$logger->debug("Output: $outString");
	}
}

sub kubernetesApply {
	my ( $self, $fileName, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesApply apply file $fileName in namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl apply -f $fileName --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesApply failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
}

sub kubernetesGetNodeIPs {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesGetNodeIPs ");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl get node  -o=jsonpath='{.items[*].status.addresses[?(@.type == \"ExternalIP\")].address}'";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesGetNodeIPs failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
	my @ips = split /\s/, $outString;
	if ($#ips < 0) {
		$logger->warn("kubernetesGetNodeIPs: There are no node IPs");
	}

	return \@ips;
	
}

sub kubernetesGetNodePortForPortNumber {
	my ( $self, $labelString, $portNumber, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesGetNodePortForPortNumber LabelString $labelString, port $portNumber, namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get service --selector=$labelString -o=jsonpath='{range .items[*]}{.spec.ports[*].port}{\",\"}{.spec.ports[*].nodePort}{\"\\n\"}{end}' --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesGetNodePortForPortNumber failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
	my @lines = split /\n/, $outString;
	if ($#lines < 0) {
		$logger->error("kubernetesGetNodePortForPortNumber: There are no services with label $labelString in namespace $namespace");
		return "";
	}
	
	my $line = $lines[0];
	my @portLists = split /,/, $line;
	if ($#portLists < 1) {
		$logger->error("kubernetesGetNodePortForPortNumber: There are no nodePorts on services with label $labelString in namespace $namespace");
		return "";
	}

	my @ports = split /\s+/, $portLists[0];
	my @nodePorts = split /\s+/, $portLists[1];
	if ($#ports != $#nodePorts) {
		$logger->error("kubernetesGetNodePortForPortNumber: There are not nodePorts for every port on the services with label $labelString in namespace $namespace");
		return "";
	}
	
	my $index = 0;
	foreach 	my $port (@ports) {
		if ($port == $portNumber) {
			return $nodePorts[$index];
		}
		$index++;
	}

	$logger->error("kubernetesGetNodePortForPortNumber: There is no port $portNumber on the services with label $labelString in namespace $namespace");
	return "";
		
}

sub kubernetesGetSizeForPVC {
	my ( $self, $pvcName, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesGetSizeForPVC pvcName kubernetesGetSizeForPVC, namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl get pvc $pvcName -o=jsonpath='{.spec.resources.requests.storage}' --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesGetSizeForPVC failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	
	if ($outString =~ /not\sfound/) {
		$logger->info("kubernetesGetSizeForPVC: There are no pvcs named $pvcName in namespace $namespace");
		return "";		
	}

	$logger->info("kubernetesGetSizeForPVC: Returning $outString for pvcName $pvcName in namespace $namespace");
	return $outString;
		
}

sub kubernetesAreAllPodRunningWithNum {
	my ( $self, $podLabelString, $namespace, $num ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesAreAllPodRunningWithNum podLabelString $podLabelString, namespace $namespace, num $num");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod --selector=$podLabelString -o=jsonpath='{.items[*].status.phase}' --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesAreAllPodRunningWithNum failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");

	my @stati = split /\s+/, $outString;
	if ($#stati < 0) {
		$logger->debug("kubernetesAreAllPodRunningWithNum: There are no pods with label $podLabelString in namespace $namespace");
		return 0;
	}
	
	my $numFound = $#stati + 1;
	if ($numFound != $num) {
		$logger->debug("kubernetesAreAllPodRunningWithNum: Found $numFound of $num pods with label $podLabelString in namespace $namespace");
		return 0;
	}
	
	foreach my $status (@stati) { 
		if ($status ne "Running") {
			$logger->debug("kubernetesAreAllPodRunningWithNum: Found a non-running pod: $status");
			return 0;
		}	
	}
	$logger->debug("kubernetesAreAllPodRunningWithNum: All pods are running");
	return 1;
}

sub kubernetesAreAllPodUpWithNum {
	my ( $self, $serviceTypeImpl, $commandString, $namespace, $findString, $num ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesAreAllPodUpWithNum exec $commandString for serviceTypeImpl $serviceTypeImpl, namespace $namespace, findString $findString, num $num");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	my $outString;	
	my $cmdFailed;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod -o=jsonpath='{.items[*].metadata.name}' --selector=impl=$serviceTypeImpl --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesAreAllPodUpWithNum get pod failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	my @names = split /\s+/, $outString;
	if ($#names < 0) {
		$console_logger->error("kubernetesAreAllPodUpWithNum: There are no pods with label $serviceTypeImpl in namespace $namespace");
		exit(-1);
	}
	
	my $numFound = $#names + 1;
	if ($numFound != $num) {
		$logger->debug("kubernetesAreAllPodUpWithNum: Found $numFound of $num pods with label $serviceTypeImpl in namespace $namespace");
		return 0;
	}
	
	foreach my $podName (@names) { 	
		$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl exec -c $serviceTypeImpl --namespace=$namespace $podName -- $commandString";
		($cmdFailed, $outString) = runCmd($cmd);
		$logger->debug("Command: $cmd");
		$logger->debug("Output: $outString");
		if ($cmdFailed) {
			$logger->debug("kubernetesAreAllPodUpWithNum not up on pod $podName: $outString");
			return 0;
		}
		if ( !($findString eq '') && !($outString =~ /$findString/) ) {
			$logger->debug("kubernetesAreAllPodUpWithNum: No match of $findString to Output on pod $podName");
			return 0;
		}	
	}
	$logger->debug("kubernetesAreAllPodUpWithNum: Matched $findString to $num pods");
	return 1;
}

sub kubernetesDoPodsExist {
	my ( $self, $podLabelString, $namespace ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	$logger->debug("kubernetesDoPodsExist podLabelString $podLabelString, namespace $namespace");

	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	my $cmd;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod --selector=$podLabelString -o=jsonpath='{.items[*].status.phase}' --namespace=$namespace";
	my ($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesDoPodsExist failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");

	my @stati = split /\s+/, $outString;
	if ($#stati < 0) {
		$logger->debug("kubernetesDoPodsExist: There are no pods with label $podLabelString in namespace $namespace");
		return 0;
	}

	return 1;
}

sub kubernetesGetLogs {
	my ( $self, $podLabelString, $serviceTypeImpl, $namespace, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesGetLogs podLabelString $podLabelString, namespace $namespace");
	
	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	# Get the list of pods
	my $cmd;
	my $outString;
	my $cmdFailed;
	$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl get pod -o=jsonpath='{.items[*].metadata.name}' --selector=impl=$serviceTypeImpl --namespace=$namespace";
	($cmdFailed, $outString) = runCmd($cmd);
	if ($cmdFailed) {
		die "kubernetesGetLogs get pod failed: $cmdFailed";
	}
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	my @names = split /\s+/, $outString;
	if ($#names < 0) {
		$console_logger->error("kubernetesGetLogs: There are no pods with label $serviceTypeImpl in namespace $namespace");
		exit(-1);
	}
	
	my $maxLogLines = $self->getParamValue('maxLogLines');

	foreach my $podName (@names) {
		if ($maxLogLines > 0) {
			$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl logs --tail $maxLogLines -c $serviceTypeImpl --namespace=$namespace $podName";
		} else {
			$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl logs -c $serviceTypeImpl --namespace=$namespace $podName";
		}
		($cmdFailed, $outString) = runCmd($cmd);
		if ($cmdFailed) {
			die "kubernetesGetLogs logs failed: $cmdFailed";
		}

		$logger->debug("Command: $cmd");
		my $logName          = "$destinationPath/${podName}.log";
		my $applog;
		open( $applog, ">$logName" )
	  	||	 die "Error opening $logName:$!";
	  			
		print $applog $outString;
	
		close $applog;

	}
	
	return 0;
}

sub kubernetesTopPodAllNamespaces {
	my ( $self, $intervalSec, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesTopPodAllNamespaces intervalSec $intervalSec, destinationPath $destinationPath");
	
	if ($self->kubectlTopPodRunning) {
		return;
	}
	$self->kubectlTopPodRunning(1);
	
	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	# Fork a process to run in the background
	my $pid = fork();
	if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
	} elsif ( $pid == 0 ) {

		open( FILE, ">$destinationPath/kubectl_top_pod-all-ns.txt" )
			 or die "Couldn't open $destinationPath/kubectl_top_pod--all-ns.txt: $!";		
		
		# ToDo: Need a way to stop process at end of run
		while (!$self->stopKubectlTop) {
	 		my $cmd;
			my $outString;
			my $cmdFailed;
			$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl top pod --heapster-scheme=https --all-namespaces";
			($cmdFailed, $outString) = runCmd($cmd);
			if ($cmdFailed) {
				die "kubernetesTopPodAllNamespaces top pod failed: $cmdFailed";
			}
			my $time;
			$cmd = "date +%H:%M";
			($cmdFailed, $time) = runCmd($cmd);
			if ($cmdFailed) {
				die "kubernetesTopPodAllNamespacse date failed: $cmdFailed";
			}
			chomp($time);
			print FILE "$time\n";
			print FILE $outString;
			sleep $intervalSec;
		}
		close FILE;
		exit;
	}

}

sub kubernetesTopNode {
	my ( $self, $intervalSec, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Clusters::KubernetesCluster");
	my $console_logger = get_logger("Console");
	$logger->debug("kubernetesTopNode intervalSec $intervalSec, destinationPath $destinationPath");
	
	if ($self->kubectlTopNodeRunning) {
		return;
	}
	$self->kubectlTopNodeRunning(1);
	
	my $kubernetesConfigFile = $self->getParamValue('kubernetesConfigFile');

	# Fork a process to run in the background
	my $pid = fork();
	if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
	} elsif ( $pid == 0 ) {

		open( FILE, ">$destinationPath/kubectl_top_node.txt" )
			 or die "Couldn't open $destinationPath/kubectl_top_node.txt: $!";		
		
		# ToDo: Need a way to stop process at end of run
		while (!$self->stopKubectlTop) {
	 		my $cmd;
			my $outString;
			my $cmdFailed;
			$cmd = "KUBECONFIG=$kubernetesConfigFile  kubectl top node --heapster-scheme=https";
			($cmdFailed, $outString) = runCmd($cmd);
			if ($cmdFailed) {
				die "kubernetesTopNode top node failed: $cmdFailed";
			}
			my $time;
			$cmd = "date +%H:%M";
			($cmdFailed, $time) = runCmd($cmd);
			if ($cmdFailed) {
				die "kubernetesTopNode date failed: $cmdFailed";
			}
			chomp($time);
			print FILE "$time\n";
			print FILE $outString;
			sleep $intervalSec;
		}
		close FILE;
		exit;
	}

}

__PACKAGE__->meta->make_immutable;

1;
