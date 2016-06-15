## mkrpm
mkrpm is a helper script to create RPM using Travis CI and Docker containers. RPM creation requires a corresponding spec file with information like source code copy, build-install scripts,  package version, release, pre-post scriptlets, changelog etc.  This information can be provided in PACKAGE_CONFIG format described below so that mkrpm and any other packaging helper scripts can use it for building packages. mkrpm will populate RPM metadata like version, release and changelog using Git commit log and Travis CI environment variables.

This script is inspired from a similar script that I originally wrote for an internal RPM infrastructure using Jenkins and VM/EC2 instances. I'm planning to add support for Jenkins environment variables soon.

### Coming Soon..
I'm planning to add support for following things soon:
 * Custom package name or prefix or suffix: This might be useful for creating nightly RPMs with suffix like REPO_NAME-nightly.
 * Grab version and release information from tags.
 * Support for external spec files - mkrpm will only modify package version, release and source code archive name.


## HowTo
There are two things needed for creating RPM using mkrpm:
 * Travis CI configuration to run docker container
 * PACKAGE_CONFIG files that will be used by this script

Following documentation will help you get started with RPM build process using mkrpm. Refer to official Travis CI documentation and Fedora RPM guide if you need more understanding about these tools.

### Travis Configuration File
Add following Travis configuration to call mkrpm. You can merge this with your existing Travis configuration file as well. These lines will be same for most projects. Change CentOS version as needed. All we are doing here is starting a CentOS based Docker container with Travis CI environment variables and then calling mkrpm. These Docker images are based on official CentOS images with addition of 'Development Tools'. Note, that you can use any appropriate image with mkrpm installed.

If your project requires any specific libraries or packages for the build (e.g. C++ boost or ruby-devel) then you can install them in Travis install section.


	sudo: required

	env:
	  - WORKSPACE='/project'

	services:
	  - docker

	language: bash

	before_install:
	  - sudo docker pull knowshan/centos6-mkrpm

	install:
	  - sudo docker run -d -it -e WORKSPACE="${WORKSPACE}" -e TRAVIS_REPO_SLUG="${TRAVIS_REPO_SLUG}" -e TRAVIS_BUILD_NUMBER="${TRAVIS_BUILD_NUMBER}" -v $PWD:"${WORKSPACE}" --name centos6 knowshan/centos6-mkrpm

	script:
	  - sudo docker exec centos6 mkrpm



### Adding PACKAGE_CONFIG files
mkrpm uses files in PACKAGE_CONFIG directory to populate RPM spec file. Most common RPM sections and their corresponding RPM\_CONFIG files are as below:

| RPM section     | mkrpm file    | Details |
| ------------    | -----------   | ------- |     
| License:        | PACKAGE_CONFIG/license | Software license for the package. See [list of valid licenses](https://fedoraproject.org/wiki/ParagNemade/CommonRpmlintErrors#invalid-license). 
| Requires:       | PACKAGE_CONFIG/dependencies | List of dependencies with one package name on each line |
| %build          | PACKAGE_CONFIG/scripts/build_script | Script for building code. It could be as simple as one line 'make' or long shell script. |
| %install        | PACKAGE_CONFIG/install_dir OR <br> PACKAGE_CONFIG/scripts/install_script <br> See details below. | Installation directory for built files or custom installation script |
| %pre            | PACKAGE_CONFIG/scripts/pre_install | Script to run before package installation on the target system |
| %post           | PACKAGE_CONFIG/scripts/post_install | Script to run after package installation on the target system |
| %pretrans       | PACKAGE_CONFIG/scripts/pre_trans | Script to run before package transaction on the target system |
| %posttrans      | PACKAGE_CONFIG/scripts/post_trans | Script to run after package transaction on the target system |


Note, that install_dir and install_script files are mutually exclusive. If you use both then install_dir is ignored and install_script is used.

Above details can be overwhelming if you are not familiar with RPM build process. See examples below for typical use cases.

## Sample configurations
### Packaging all repository content as it is in an RPM (install_dir)
Following PACKAGE_CONFIG is simplest way to create a self-contained package with source code as it is. This will put everything in repo under install_dir directory tree.

1. Create PACKAGE_CONFIG directory in your project.
2. Add a valid license (examples Apache License, MIT, GNU etc.) to PACKAGE_CONFIG/license file.
3. Add PACKAGE_CONFIG/install_dir
4. That's it! You don't need to specify anything else for such simple package. When we use custom install_script then we need to specify additional details about packaged files as well.


### Custom installation directory structure
1. Create PACKAGE_CONFIG directory in your project.
2. Add a valid license (examples Apache License, MIT, GNU etc.) to PACKAGE_CONFIG/license file.
3. Add custom install_script which will copy files from build directory to RPM_BUILD_ROOT as shown below. You can add commands like below or call 'make install' or use RPM macro %make_install.

		mkdir -p $RPM_BUILD_ROOT/usr/local/bin
		mkdir -p $RPM_BUILD_ROOT/usr/local/share/mkrpm
		install mkrpm.sh $RPM_BUILD_ROOT/usr/local/bin/mkrpm
		install template.spec  $RPM_BUILD_ROOT/usr/local/share/mkrpm/
		

### Building source code and packaging build artifacts in an RPM
1. Create PACKAGE_CONFIG directory in your project.
2. Add a valid license (examples Apache License, MIT, GNU etc.) to PACKAGE_CONFIG/license file.
3. Add custom build_script - It could be simply make or make target or RPM macro %make. This will depend on your project specific Makefile.

		%make

4. The build_script could contain things like npm install or grunt task as well. Just make sure that your build container has these tools like npm and grunt installed before calling mkrpm. One advantage of installing npm packages inside RPM is that you get a self contained binary package that could be easily deployed on target systems.
5. Add custom install_script which will copy files from build directory to RPM_BUILD_ROOT. Example below shows RPM macro:

        %make_install

6. Add PACKAGE_CONFIG/packaged_files file with list of files and directories. Refer to [Fedora wiki](https://fedoraproject.org/wiki/How_to_create_an_RPM_package#.25files_section) on how to add files section. You could simply add '/' and get everything package, but this is bad practice and hence discouraged. See example below:

        %doc /usr/local/share/man/man1/httperf.1
        %doc /usr/local/share/man/man1/idleconn.1
        /usr/local/bin/httperf

### Including npm modules (self-contained) as part of the RPM

## Examples
 * httperf
