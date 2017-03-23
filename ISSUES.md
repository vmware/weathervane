# Weathervane Issues Guidelines

## General Guidelines

The Weathervane project encourages the use of issues for bug reports, features requests, general user issues, and questions that may have applicability to more than one user.  If you are unsure whether you should open an issue, contact us in the Weathervane room [Slack](https://vmwarecode.slack.com/messages/weathervane). This is the primary community channel. If you don't have an @vmware.com or @emc.com email, please sign up at https://code.vmware.com/web/code/join to get a Slack invite.  

If you are filing a bug report, expect us to ask you for the output directory created from a run on which you experienced the bug.  The output must be captured at logLevel 3 in order to provide us with sufficient information to diagnose the bug.  Due the complex nature of a Weathervane deployment, we may ask you to perform additional runs, and provide their associated output, as we may not be able to replicate your deployment configuration in our environment.

## Issue Labels

The Weathervane project uses a hierarchical approach to issue labels.  The top-level label categories are:
- *kind*: These labels indicate the general category of the issue.  Every issue must have a kind label, and will almost always have only one.  If you feel that multiple kind labels are appropriate for your issue, then you should consider whether you have two separate issues before filing.
- *component*: These labels indicate which Weathervane components are involved in the issue. An issue will often have multiple component labels.  General questions may not need any component labels.
- *resolution*: These labels are used to indicate how an issue was resolved.  They should be applied to issues that are closed.  An issue will typically have only one resolution.

You should give some thought to your choice of labels for an issue, but please use all that you feel are appropriate.  The Weathervane team may adjust the labels when the issue is triaged.

### Kind labels

The following labels are used to indicate the general category of the issue.  As mentioned above, all issues should have at least one kind label, and most should have only one.  The available kind labels are:

- *kind/bug*: Used to indicate a bug report.
- *kind/bug/p0*: Used to indicate an urgent bug report.  Use this kind judiciously.
- *kind/performance-bug*: Used when reporting a bug that impacts performance results.
- *kind/developer-docs*: Used to report a bug in the developer-oriented documentation.
- *kind/user-docs*: Used to report a bug in the user-oriented documentation, such as the User's Guide.
- *kind/contribution*: Used for discussions of contributions to the Weathervane project.
- *kind/feature-new*: Used when requesting a new feature.
- *kind/feature-enhancement*: Used when requesting an improvement or change to an existing feature.
- *kind/question*: Used when opening an issue to ask a general question.
- *kind/other*: Use this label when you want to open an issue and don't think that any of the existing kind labels are appropriate. When you use this label, it would be helpful if you indicate in the issue what you believe an appropriate kind label would be for the issue.

### Component labels

The following labels are used to indicate which Weathervane components are impacted by or related to the issue.  If you don't know, you can leave these out and the Weathervane team will help identify the correct labels.

- *component/auctionApp*: Issues related to the core Auction Java application.
- *component/auctionConfigurationManager*: Issues related to the Configuration Manager microservice.
- *component/auctionSimpleElasticityService*: Issues related to the Simple Elasticity Service.
- *component/autoSetup*: Issues related to the autoSetup.pl script or the setup process in general.
- *component/build*: Issues related to the build files and process.
- *component/dbLoader*: Issues related to the database loader and data preparation process.
- *component/docker*: Issues related to docker, the docker images, and the script for building the images.
- *component/runHarness*: Issues related to the run harness.
- *component/workloadDriver*: Issues related to the workload driver.
- *component/auctionWeb*: Issues related to the front-end web interface.

### Resolution Labels

The following labels are used to indicate the resolution of an issue.

- *resolution/answered*: Used for questions or issues that are not bugs, and that have been answered.
- *resolution/fixed*: Used for kind/bug or kind/bug/p0 that have been fixed and put back to the master branch.
- *resolution/implemented*: Used for kind/feature-new or kind/feature-enhancement that have been implemented and put back to the master branch.
- *resolution/duplicate*: Used for issues that are duplicates of previously opened issues.  The resolution message should include a link the the matching issue.
- *resolution/not-a-bug*: Used for bug-related issues that are deemed to not correspond to an actual bug.
- *resolution/wontfix*: Used for any issue, particularly bug fixes or feature requests, that won't be implemented.
