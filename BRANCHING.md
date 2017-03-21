# Weathervane Branching and Releases

## Version Numbers

The Weathervane project follows the conventions for [semantic versioning](http://semver.org/) when assigning version numbers to releases.  Quoting the summary from http://semver.org/:

> Given a version number MAJOR.MINOR.PATCH, increment the:
> 1. MAJOR version when you make incompatible API changes,
> 1. MINOR version when you add functionality in a backwards-compatible manner, and
> 1. PATCH version when you make backwards-compatible bug fixes.
>
> Additional labels for pre-release and build metadata are available as extensions to the MAJOR.MINOR.PATCH format.

For the purposes of Weathervane, the major version will be incremented only when changes are made that break performance repeatability or compatibility with existing configuration files.  Note that we are not currently accepting changes that would cause a major version change.  See [CONTRIBUTING.md](CONTRIBUTING.md) for acceptable change guidelines.   

## Branching Strategy

The approach taken by the Weathervane team to branching is as follows:
- The master branch always contains the most recent major version. Currently, the master branch is on the 1.x.y release train.
- All work that encompasses bug-fixes or small feature enhancements will be merged into the master branch and be included in the next official release.  Basically, anything that is done by a single person in a topic branch, and that passes all of the acceptance criteria, will be merged into master. The merge point will be tagged with an appropriate version number.  Note that this implies that even members of the Weathervane project team will integrate changes to the master branch via pull requests.
- Any work that will require multiple collaborators, and whose goal is acceptable to the project maintainers, will go into a new branch off of master. We will require an Issue be opened and discussed before creating a new branch.
  - If a branch involves contributors who are not members of the Weathervane project team, their work will still need to be integrated into the branches using pull requests.  Members of the Weathervane team may push directly into a non-master branch.
  - There is a document in the master branch, [Branches.md](Branches.md), which lists the current branches, a summary of their purpose, and a link to the associated issue.
  - There must be an owner for each branch, and the owner is responsible for keeping the sub-branch up to date with the master branch as much as possible to simplify the final merging.
  - When work on the branch is complete, it should be merged to master and deleted.  The Issue should then be closed.

## Release Strategy

The Weathervane team will generate release packages for each minor release.  In addition, a release package will be generated for patch releases which fix significant bugs, or upon request.  Otherwise we expect users to update by pulling from the Weathervane repository.

Note that Weathervane release packages will not contain pre-compiled binaries.  You will need to build Weathervane after unpacking a Weathervane release.  The build process is documented in the [Weathervane User's Guide](weathervane_users_guide.pdf).
