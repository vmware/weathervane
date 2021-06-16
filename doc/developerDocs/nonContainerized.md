# Weathervane Developer Documentation: Adding Non-Containerized Functionality

## Overview

In Weathervane version 1.x, it was possible to run the services of the auction application directly in the operating system (OS) of a server without the use of containers.  This functionality was removed in Weathervane 2.0 to focus on Kubernetes and containerized workloads. However, there are still use cases for which a version of Weathervane 2.0 running without containers would be an appropriate benchmark.  This document contains a summary of the changes that would be required to restore this functionality into Weathervane.  Note that there is not currently a plan to add this functionality, but this document is left as a roadmap for any developer wishing to take on this work.

The ability to run without containers in Weathervane 1.x was achieved by including a setup script that installed or placed all of the dependencies for the service into the OS and filesystem.  In order for this to work properly only a single OS, Centos 7, was supported when deploying Weathervane 1.x without containers.  When running with containers, at least one system configured using the setup script was required to act as a workload driver node.  Within the run harness, there were Service classes and supporting functionality that helped managed some of the complexity of coordinating the services of a multi-tier workload.  Some of this functionality still exists to support Docker-only (non-Kubernetes) deployment of Weathervane 2.0.  However, even that functionality has received minimal testing and documentation due to the focus on Kubernetes.

It is important to note that in addition to the changes to Weathervane itself, there are many tasks that are currently handled by a Kubernetes cluster that will need to be handled by the user of a non-containerized Weathervane.  These include configuring networking, allocating storage volumes, and managing the mapping of services to hosts.  You should read the Weathervane User's Guide for Weathervane 1.x, contained in the 1.x branch of the repository, for more information about these tasks and how they were managed in Weathervane 1.x. 

The tasks that must be completed to run Weathervane 2.0 directly on the OS are:

- Create an autoSetup script to configure the hosts
- Determine and document networking conventions for the hosts
- Determine and document storage conventions for the hosts
- Determine appropriate OS-level tuning for hosts.
- Decide whether the fixed configurations will be supported, or whether non-containerized Weathervane will only support custom configurations.
- Decide whether resource limits and shares will be used for non-containerized services
- Decide whether it is necessary to run multiple instances of the same service on a single host
- Make changes to the run harness  

Note that this document is unlikely to be complete.  There are probably issues that will arise that I have overlooked.  When this happens, I would suggest trying to understand how the same issue was handled in version 1.x as a way to get started.

## Creating the autoSetup script to configure the host

This section discusses the details of creating the autoSetup script for deploying the services on the hosts.  It is recommended that you refer to the autoSetup.pl script in the 1.x branch of Weathervane for an example.  Also refer to the Weathervane User's Guide in the 1.x branch for details about creating and cloning VMs to create a complete deployment.

The autoSetup.pl script in Weathervane 1.x performed the following tasks:

- Applied OS-level tuning changes
- Made necessary firewall changes
- Installed the software required to run all of the services (e.g. nginx, tomcat, etc.)
- Copied pre-compiled/created artifacts into the appropriate locations.  This includes the Java application, the files for the web server, etc. 
- Set up support services (e.g. a DNS server)

Pre-requisites that must be resolved before creating this file include:

- Determine which OS (or OSes) will be supported.  It will be easiest to use some version of Centos, as the dockerImages already use Centos 7 as the base image.

The best way to re-create this file would be to start with the autoSetup.pl file from the 1.x branch, the buildDockerImages.pl script from the 2.x branch, and the Dockerfiles from the dockerImages hierarchy on the 2.x branch.  The setup needed for each service can be extracted from the Dockerfile for that service and moved to the autoSetup.pl script.  

The following must be considered when creating the autoSetup script:

- There may be file placement conflicts between some of the services, e.g. the tomcat and auctionbidservice.  This will need to be checked for, and if it does occur, the configuration files may need to be updated to account for new file locations.

## Determine and document networking conventions for the hosts

### Hostnames

Weathervane 1.x assumed that all services were assigned to host with hostnames, and that those hostnames could be resolved to IP addresses either using DNS or /etc/hostnames.  A set of convention-based hostname selection rules could be used to avoid having to specify hostnames for each service.  The mapping of services to hosts was then done by mapping the convention-based names to the IP addresses of hosts using DNS or /etc/hosts.

In Weathervane 2.0 the convention-based naming was removed.  When running on Kubernetes, the Kubernetes cluster manages the assignment of services to hosts.  If using a Docker-only (non-Kubernetes) deployment, the only mapping supported is for mapping entire application instances to specific docker hosts.  There is no way to specify different hosts for different services unless using a custom (non-fixed) configuration.  However, custom configurations are not yet supported.  This is discussed more below.  

### Port Numbers

In Weathervane 1.x, the port numbers for each instance of a service are set to unique values to allow multiple instances of the same service to run on the same host.  The mechanism to manage this was preserved in 2.0 for the docker-only deployments.  This mechanism would need to be carried into the Service implementations for the non-containerized services.


## Determine and document storage conventions for the hosts

In Weathervane 1.x, the storage for the data services was located in a pre-defined location in the filesystem (see the User's Guide).  If external disks were required for these services, the user was responsible for creating them and mounting them in the appropriate locations.  In 2.0, storage is allocated using dynamic persistent volumes (kubernetes), or named volumes (docker).  As a result, the configuration files included in the docker images do not necessarily have the same conventions for storage location.  This is particularly true for Cassandra, which was not present in 1.x.  

You will need to define standard locations for the storage for the data services.  The use of the conventions in 1.x meant that it was not possible to run multiple instances of a data service on the same host.  If you want to run multiple instances on the same host, you will need a more advanced data layout than was used in 1.x.


## Determine appropriate OS-level tuning for hosts.

The autoSetup.pl script from the 1.x branch shows the tuning that was performed on the host VM.  Some of this involved copying pre-configured files (such as sysctl.conf) into the correct locations.  Most of these tunings may no longer be appropriate for more recent versions of Centos, and even if they are the appropriate files to edit may have changed.  This will need to be revisited from scratch.  Be sure to refer to the tuning guides for each service (e.g. Tomcat, Cassandra, etc.) for best practices.


## Decide whether the fixed configurations will be supported, or whether non-containerized Weathervane will only support custom configurations.

Currently, Weathervane 2.x only supports pre-configured (fixed) configurations of the auction application.  These configurations have been pre-tuned and tested.  On Kubernetes, the Kubernetes cluster manages the assignment of services (pods) to hosts.

There is currently no way to assign the individual services of a fixed configuration to particular hosts.  All services of an fixed-config application instance currently must be assigned to the same Kubernetes cluster or Docker host.  Weathervane does have the ability to define custom configurations, in which the user can specify the number of each type of service and the tuning of those services.  In custom configurations the service->host mapping can be defined using the detailed configuration file format.  However, custom configurations are currently disabled.  This was done to simplify testing and documentation, but it should still work if re-enabled.

If fixed configs are to be supported, you will need to:
  - Implement a way to express the mapping of services to hosts for these configurations in the config file
  - Add checks to make sure that hosts have enough resources to support the services assigned to it
          
## Decide whether resource limits and shares will be used for non-containerized services

Weathervane currently allows the setting of resource requests and limits.  By default, requests are used for all services (pods) and limits are only used for the app server pods.  CPU requests correspond to cgroup cpu shares at the OS level and cpu limits correspond to cgroup cpu limits.  For Kubernetes, the kubelet configures the cgroup when a pod is deployed.  For docker-only, the Docker runtime manages that task.  For non-containerized Weathervane, you will need to decide whether to use shares and limits for the services.  If you do, this will need to be managed within the run harness.

If you do not use cgroup limits, the results of a non-containerized run will not be comparable to that of a containerized run using limits.  You will also need to carefully tune the heap size of the Java components, as well as the rest of the configuration, for the largest VMs on which you might to run the workload.

## Decide whether it is necessary to run multiple instances of the same service on a single host

One of the most difficult issues to deal with when running a non-containerized Weathervane will running multiple instances of the same service on a single host.  This is an issue because most of the services assume, by default and in the container images, that certain files are in specific locations, and that services listen on particular port numbers.  In order to run multiple instances of the same service on a host, you will need to ensure that the configuration files for each instance point to unique filesystem locations and unique port numbers.  The run harness will need to manage customizing the configuration files properly, as well as making sure that all services in an application instance know the proper hostnames, or IP addresses, and port numbers to use when contacting other services.  

The run harness already has facilities for assigning unique port numbers to each instance of a service, and communicating that information to other services in an application instance.  This is done through the setPortNumbers and setExternalPortNumbers methods in the Service classes. In Weathervane 2.x these classes only exist in the Docker services.  In Weathervane 1.x they exist in all services.  You should look at how the Weathervane 1.x non-Docker services handle port numbers.

There is currently no facility in the run harness to manage custom file locations.  This will need to be handled in the configure method on the Service classes, which customizes the service configuration files.  There may also need to be special set-up in the autoSetup script to set up the locations on the host.  This will need to be evaluated for each service.

There are probably other complications regarding running multiple of the same service that I have missed here.  You should be sure to understand whether there are any limitations to running multiple nodes of a clustered service on the same host.


## Changes to the run harness

Most of the code-level changes required to implement running non-containerize Weathervane will occur in the run harness. Here is a high-level overview of the changes that will be needed:

### Separate the configuration files from the dockerImages sub-directories

In Weathervane 1.x, the configuration files for each service lived in a directory hierarchy under the weathervane/configFiles directory.  In 2.x, all of the config files have been moved to the appropriate location under the dockerImages directory.  These files need to be accessible for use in the configure method on the Service classes.  You will either need to move a copy back to the previous location, or use the files for each service from the dockerImages directory.  The later will probably be cleaner because you won't have to maintain two copies of the same config files.

### Understand the AppInstance Class Hierarchy

The AppInstance class contains functionality that applies to all services in an application instance.  The AuctionAppInstance class specializes a couple of methods (notably checkConfig and getServiceConfigParameters) for the Auction App.  AuctionKubernetesAppInstance overrides some of those implementations to do Kubernetes specific actions.

Everything is probably OK here as-is, but it is possible that in the move to remove non-containerized services, some Docker specific changes were made to the AuctionAppInstance class.  

### Add a class to represent the non-containerized hosts

In Weathervane 1.x, there was a hierarchy of Host-type classes in the Hosts package.  In that hierarchy, the host type on which the services ran (containerized or not) was LinuxGuest.  This class had methods for managing things like performance statistics collection and configuration file gathering on Linux hosts.  In 2.x, the Host hierarchy was changed to the ComputeResources hierarchy, and the two main sub-classes are Cluster, which is a super-type of the Kubernetes Cluster class, and Host, which is the super-type of the DockerHost class.  You will need to add a Host sub-class to represent the non-containerized hosts on which the services will run.  You should refer to the LinuxGuest class, and its super-classes, in 1.x to get an idea of what the responsibilities of this class will be.

If you decide to implement configuring cgroups for shares and limits, that functionality will probably belong in the new Host class.

### Add Service classes

Each type of service used in an application instance is represented by a sub-class of the Service type.  The Service classes are responsible for managing the lifecycle of the service instances.  You will need to create new Service classes for each service type.  These classes will manage such tasks as configuring the service (edit configuration files and put them in the right place), starting and stopping services, and collecting up any stats or configuration files at the end of a run.

You can refer to the service classes for the non-dockerized services from version 1.x, but you should also look at the Docker versions of the services from 2.x, as there have been some changes that may affect the operation of some of the methods.  Comparing the Docker services from 1.x to 2.x will help in determining whether changes are needed.

### Select the correct version of the Service class for the services

The instances of the Service class for the services of an application instance are created in Factories::ServiceFacory.pm.  In Weathervane 2.x, the choice between using Kubernetes or Docker is based on whether a service is running on a Kubernetes cluster or a Docker host.  This could be extended to use the fact that a service is running on a LinuxHost (or whatever name is given to the ComputeResource on which non-containerized services will run).  

It would also be possible to add a parameter to indicate that an application instance is supposed to run non-containerized. There was a useDocker parameter that served this function in 1.x.


## Known Issues

- For Docker-only deployments, multi-node Cassandra deployments are not currently supported.  This would be a limitation for a non-containerized deployment as well.

