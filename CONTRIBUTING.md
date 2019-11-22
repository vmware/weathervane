# Contributing to Weathervane

The Weathervane project team welcomes contributions from the community. Before you start working with Weathervane, please read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## Community

Contributors and users are encouraged to collaborate using the following resources in addition to the GitHub issue tracker:

- [Slack](https://vmwarecode.slack.com/messages/weathervane): This is the primary community channel. If you don't have an @vmware.com or @emc.com email, please sign up at https://code.vmware.com/web/code/join to get a Slack invite.

If you have an idea or plan for a specific contribution to the Weathervane project, it would be best if you start by opening an issue on the Weathervane project, and label it with the kind/contribution label.  The Weathervane code base consists of many components that are interrelated in complex ways, and we would be happy to work with potential contributors to ensure that you have all of the information necessary to succeed.

## Acceptable Change Guidelines

The Weathervane project welcomes contributions from anyone who would like to contribute.  If you are interested in contributing you should read the following guidelines to understand the types of contributions that we will and will not accept.

### Acceptable changes:

* Bug fixes
* Addition of new implementations for the various services, for example support for additional application servers, database servers, etc.
* New data management or analysis features which do not affect data currently collected
* New features which do not affect the performance of existing configurations.  For example, support for new a caching mechanism would be acceptable as long as the benchmark can still be run without the new mechanisms so the existing configurations are not affected.
* New run management features or changes to the run harness that simplify run or data management or that add new capabilities.  These changes must not break or change the behavior of existing configuration files.
* New applications which can be run in place of or in addition to the Auction application.  While the only application currently supported is the Auction application, the Weathervane harness and workload driver could support additional applications, including multiple applications running simultaneously.  Adding a new application would not be a simple undertaking as it would require changes in many places in the Weathervane code base.  However, if you have an application that you want contribute to Weathervane, and have the rights and willingness to place the application into open-source under the Weathervane license terms, the Weathervane team will try to help guide you in implementing the necessary changes.
* Other changes which the project team deems appropriate to the goals and philosophy of the project.  If you are contemplating a contribution and are unsure whether it will be accepted by the Weathervane team,  open an issue with a brief description of the change and we will be happy to discuss it with you.

It is good practice to open an issue for any change that you are considering for which you will want to submit a pull request.  The Weathervane team will be happy to discuss the change and help guide you in the easiest way to implement it within the Weathervane code-base.

### Changes which will not be accepted at this time:

* Changes to the Auction application which affect the performance of existing configurations.  Even though there are certainly changes that could be made to the Auction application that would improve performance or scalability, the current intent of the Weathervane project is to maintain performance consistency for all releases in the 2.x release lineage.  At some point we will create a new branch for a 3.x release, and at that point optimizations  or even complete rewrites for the Auction application will be considered.  
* Changes which create compatibility issues with existing configuration files.
* Changes which would change the performance results for existing deployments or configuration files.
* Any other change which affects compatibility with existing releases. Changes which affect compatibility may be considered in the future when we open a branch for work on a 3.0 release.

As you can see from the above lists, we will be accepting only performance-neutral changes only on the 2.x branch. Performance neutral does not mean that in your runs of Weathervane you cannot tune the various services involved in a Weathervane deployment.  What you do on your own runs is totally up to you.  However, we will not accept changes to the configuration defaults for existing services that would result in performance changes.  

We will accept changes to support the addition of new service implementations, such as new database servers, that may give better performance than those currently supported. The goal of performance neutral is to ensure that users can rerun identical configurations with any release from the 2.x branch and still get the same results.  Note that this does mean that once a new service implementation is incorporated into Weathervane we will not accept changes that affect the performance of that service using the default settings.  We will allow the addition of new tuning parameters for any service as long as the default is the same as for the initial release on which that service was introduced.

## Developer Documentation

Documentation for developers interested in working on Weathervane can be found in the [docs](docs) directory.  These docs are thin on content at this time.  If there is something you need to know that is not covered, please open an issue, using the conventions in [ISSUES.md](ISSUES.md).

## Contribution Testing

Weathervane is a complex project with a large number of interacting components.  While we encourage the addition of unit tests, a complete regression test requires that changes be tested with complete runs of the benchmark in multiple configurations.  As a result, we require that contributors provide the output from one or more runs that demonstrate the contribution in action.  This output must be from runs performed at logLevel 3 in order to contain sufficient information.  We will work with contributors to determine what types of runs are needed.  We will review this information, as well as reviewing the code, as the first step in deciding whether to accept a pull request.

In addition to contributor-provided output, the project team has created a set of regression tests that we will use to test for both bugs and performance changes before any contribution is merged into the master branch.  Depending on the scope of the change, we will select the appropriate subset of these tests to run against a submitted pull request.  We will run these tests after reviewing the code and contributor-provided output.  In some cases a contribution may work only in an environment or with a piece of software that is unavailable to the project team. In that case we may request output from additional runs to ensure quality before accepting the change.

## Contribution Flow

This is a rough outline of what a contributor's workflow looks like:

- Create a topic branch from where you want to base your work
- Make commits of logical units
- Make sure your commit messages are in the proper format (see below)
- Push your changes to a topic branch in your fork of the repository
- Submit a pull request

Example:

``` shell
git remote add upstream https://github.com/vmware/weathervane.git
git checkout -b my-new-feature master
git commit -a
git push origin my-new-feature
```

### Staying In Sync With Upstream

When your branch gets out of sync with the vmware/master branch, use the following to update:

``` shell
git checkout my-new-feature
git fetch -a
git pull --rebase upstream master
git push --force-with-lease origin my-new-feature
```

### Updating pull requests

If your PR needs changes based on code review or testing, you'll most likely want to squash these changes into
existing commits.

If your pull request contains a single commit or your changes are related to the most recent commit, you can simply
amend the commit.

``` shell
git add .
git commit --amend
git push --force-with-lease origin my-new-feature
```

If you need to squash changes into an earlier commit, you can use:

``` shell
git add .
git commit --fixup <commit>
git rebase -i --autosquash master
git push --force-with-lease origin my-new-feature
```

Be sure to add a comment to the PR indicating your new changes are ready to review, as GitHub does not generate a
notification when you git push.

### Formatting Commit Messages

We follow the conventions on [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/).

Be sure to include any related GitHub issue references in the commit message.  See
[GFM syntax](https://guides.github.com/features/mastering-markdown/#GitHub-flavored-markdown) for referencing issues
and commits.

## Reporting Bugs and Creating Issues

When opening a new issue, try to roughly follow the commit message format conventions above.  Please read [ISSUES.md](ISSUES.md) for full details on the Weathervane conventions and procedures for issues.
