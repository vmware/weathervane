

# Weathervane

## Overview

Weathervane is an application-level performance benchmark designed to allow the investigation of performance tradeoffs in modern virtualized and cloud infrastructures. It consists of an application, a workload driver that can drive a realistic and repeatable load against the application, and a run-harness that automates the process of executing runs and collecting results and relevant performance data. It can be used to investigate the performance characteristics of cloud and virtual infrastructures by deploying the application on the environment of interest, driving a load against the application, and examining the resulting performance metrics. A common use-case would involve varying some component or characteristic of the infrastructure in order to compare the effect of the alternatives on application-level performance.

![A Weathervane Deployment](doc/images/wvDeployment1.png)

The figure above shows the logical layout of a Weathervane deployment. The Weathervane application is a web-application for hosting real-time auctions. This Auction application uses a scalable architecture that allows deployments to be easily sized for a large range of user loads. A deployment of the application involves a wide variety of support services, such as caching, messaging, NoSQL data-store, and relational database tiers. These services can be deployed in VMs or in Docker containers.  The number of instances of some of the services can be scaled elastically at run time in response to a preset schedule or to monitored performance metrics. In addition, Weathervane supports deploying and driving loads against multiple instances of the Auction application in a single run, thus enabling performance investigations of resource constraints or other aspects of multi-tenancy.  The Weathervane run-harness manages the complexity of configuring, deploying, and tuning the application, automating most of the tasks involved in configuring the application services and running the benchmark.

Additional background information about Weathervane can be found at [https://blogs.vmware.com/performance/2015/03/introducing-weathervane-benchmark.html](https://blogs.vmware.com/performance/2015/03/introducing-weathervane-benchmark.html) and [http://blogs.vmware.com/performance/2017/04/weathervane-performance-benchmarking-now-open-source.html](http://blogs.vmware.com/performance/2017/04/weathervane-performance-benchmarking-now-open-source.html).

## Warning

You should exercise caution and good judgement about where you deploy Weathervane.  Weathervane can place a significant load on system resources that can impact the performance of unrelated workloads.  As a result Weathervane is not intended to be used in production environments.  

In addition, the setup procedure for Weathervane may open ports or present other security issues that are not acceptable in many secure environments.  A Weathervane deployment is intended only for a performance test environment and may not be hardened sufficiently for all security requirements.  As a result, Weathervane should never be installed on virtual machines or OS instances that have been or may ever be deployed in a production environment, or that contain sensitive or personal information.  

## Getting Started

Weathervane runs on one or more hosts or virtual machines (VMs) running the Centos 7 operating system.  It includes a script to automate the initial configuration of the VM, including the installation of all necessary services.  Simple runs of the benchmark can be performed on a single VM, but the application and workload driver can be scaled out to perform benchmark runs involving dozens of VMs.

The process of setting up and running Weathervane is covered in detail in the [Weathervane User's Guide](weathervane_users_guide.pdf).  

## Documentation

The [Weathervane User's Guide](weathervane_users_guide.pdf) covers all aspects of installing, deploying, and running the Weathervane benchmark.

## Communicating about Weathervane

The Weathervane project team can be contacted in the following ways:

- [Slack](https://vmwarecode.slack.com/messages/weathervane): This is the primary community channel. If you don't have an @vmware.com or @emc.com email, please sign up at https://code.vmware.com/web/code/join to get a Slack invite.

- [Gitter](https://gitter.im/vmware/weathervane): Gitter is monitored but go to slack if you need a response quickly.

Feel free to contact us with questions or comments.  Please use these method to contact us for questions specific to your use of Weathervane.

We also encourage the use of Issues in the GitHub repository for any questions or suggestions that may be of general interest.  We may move discussion of questions or issues from Slack to a GitHub Issue if we feel that the question or answer may be of more general interest.  Before creating an Issue, please read [ISSUES.md](ISSUES.md).

## Issues

The Weathervane project encourages liberal use of Issues for bugs, feature requests, documentation shortcoming, or general questions.  Please read the issue guideline in [ISSUES.md](ISSUES.md) before filing an Issue.  Be sure to follow the guidelines regarding issue labels to ensure a prompt response.

## Releases & Major Branches

The branching and release strategy for Weathervane is discussed in [BRANCHING.md](BRANCHING.md).

## Contributing

The Weathervane project team welcomes contributions from the community. Before you start working with Weathervane, please read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Weathervane is available under the the [BSD 2-clause "Simplified" License](LICENSE.txt).

Weathervane uses additional components which are downloaded when the project is built and which have additional licensing terms. The licenses for these components can be found in the [license file](LICENSE.txt).
