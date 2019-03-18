# Weathervane Implementation Overview

This document gives an overview of the Weathervane implementation. It begins with a
brief discussion of the implementation technologies used in the various
components of Weathervane. It then gives an overview of each of the components. Each
of these components is represented by a sub-project in the project directory.

## Implementation Technologies

This section gives a brief introduction to the various programming laguages and
key technologies used in Weathervane. 

The following programming languages are used in the various components of
Weathervane:
* Java
* Perl
* JavaScript

For the components written in Java, the following are key technologies:
* Spring
 * Spring Framework
 * Spring MVC
 * Spring Data MongoDB
 * Spring Data JPA
 * Spring AMQP
 * Spring Boot
 * Spring Hateos
* Java Persistence API (JPA)
* Jackson JSON Library
* Netty (Workload Driver only)

For the components written in Perl, the following are key technologies:
* The Moose object-oriented extensions

For the components written in JavaScript, the following are key technologies:
* jQuery
* Backbone.js
* Bootstrap

The build system used for Weathervane is Gradle.

## Weathervane Components

Weathervane consists of a number of components that play various roles in the execution of the benchmark. This section describes each of the components, in the order that they will appear when viewing the code in an IDE.  

### auctionApp

auctionApp contains the implementation of the web service that contains
the main functionality of the Auction application.  It contains the services that
handle user log-ins, manage the auctions, accept and process bids, and handle
queries for various pieces of information that are relevant to a user of the
Auction application.  This component exposes the REST API that is used by
the front-end browser interface (auctionWeb) to Auction, as well as by the simulated
users in the workload driver.

auctionApp also contains all of the code required for interacting with the data
services, including the databases, MongoDB, and the filesystem.  It includes the
classes for the domain model for the Auction application, as well as for the
data-access objects (DAOs) and repository classes used to bridge between the
object model and the relational and NoSQL data stores.  It also contains the
code for the ImageStore, including implementations for placing the imageStore
in-memory, in a filesystem, or in MongoDB.

auctionApp is written in Java.

### auctionWeb

auctionWeb contains the code for the browser interface to the Auction
application.  This interface is a stand-alone single-page browser application
that communicates with a Auction deployment over the REST API.  The
implementation is packaged as a war file for deployment on application servers,
or as a tar file for deployment on web servers.

Note that the browser application is not used by the benchmark and is provided
for testing and demonstration purposes only.

auctionWeb is implemented in JavaScript.

### dbLoader

The dbLoader has two main responsibilities:
* Through the DBLoader main class, it is used to load data into the data
services of the Auction application. This data can be re-used for multiple
benchmark runs as long as there are no relevant changes in the data services
configuration.  
* Through the DBPrep main class, it is used to reverse any changes in the
pre-loaded data at the end of each run, and to prepare the data before the start
of the next run.  Preparing the data mainly consists of setting the start times
of the auctions that will be active during a run.

The DBPrep program is also used to check whether the data services are loaded
with the appropriate data for the deployment configuration, number of users, and
duration of a run.

The dbLoader uses the auctionData component.

The dbLoader is written in Java.

### workloadDriver

The workloadDriver runs the simulated users that create the load for the
Auction application.  It is a general-purpose driver of load to HTTP
interfaces, and is not limited to Weathervane or Auction.

The workloadDriver is written in Java.

### Run Harness

The Run Harness contains the logic that turns Weathervane from a group of independent
pieces into a unified benchmarking tool.  It manages all aspects of running the
benchmark, including:

* Configuring and starting all of the application services used by the Auction application
* Loading and preparing the data used by the Auction data services
* Configuring and starting the workload driver nodes
* Collecting statistics and log files from all nodes and services
* Cleaning up at the end of a run
* Parsing result and log files
* Managing multi-run experiments.

The file weathervane.pl in the main weathervane directory is the entry-point to the run
harness.  The remainder of the run harness is located under the runHarness
directory.  The run harness also makes use of the configuration files in the
configFiles directory and the workload profile templates in workloadTemplates.

The run harness is written in Perl.  Someday it might be rewritten in a language
that has better native support for objects and multi-threading, such as Java, Scala,
or Python.
