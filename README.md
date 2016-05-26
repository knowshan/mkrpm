## mkrpm
mkrpm is a helper script to create RPM using Travis CI and Docker containers. RPM creation requires a corresponding spec file with information like source code copy, package version, release, scripts, changelog etc. mkrpm will help you create RPM spec file as part of CI build process on the fly using Git commit information. It is intended to make RPM build process easy. 

## HowTo
There are two things needed for creating RPM using mkrpm:
 * Travis CI configuration to run docker container
 * RPM_CONFIG files that will be used by this script

This documentation will help you get started with RPM build process using mkrpm, but please refer to official Travis CI documentation and Fedora RPM guide if you need more undertsnading about these tools.

### Travis Configuration File
Add following travis configuration to call mkrpm. You can merge this with your existing Travis configuration file as well. These lines will be same for most projects. Change CentOS version as needed. All we are doing here is starting a CentOS 6 docker cotainer with Travis CI environment variables and then calling mkrpm. This docker container image is based on official CentOS 6 image with addition on 'Development Tools'.

If your project requires any specific libraries or packages for performing the build (e.g. C++ boost or ruby-devel) then you can install them in Travis install section.


	sudo: required

	env:
	  - WORKSPACE='/project'

	services:
	  - docker

	language: bash

	before_install:
	  - sudo docker pull knowshan/centos-buildsys

	install:
	  - sudo docker run -d -it -e WORKSPACE="${WORKSPACE}" -e TRAVIS_REPO_SLUG="${TRAVIS_REPO_SLUG}" -e TRAVIS_BUILD_NUMBER="${TRAVIS_BUILD_NUMBER}" -v $PWD:"${WORKSPACE}" --name centos6 knowshan/centos-buildsys

	script:
	  - sudo docker exec centos6 mkrpm



### Adding RPM_CONFIG files
mkrpm uses files in RPM_CONFIG directory to populate RPM spec file. Most common RPM sections and their corresponding RPM\_CONFIG files are as below:

| RPM section     | mkrpm file    | Details |
| ------------    | -----------   | ------- |     
| License:        | RPM_CONFIG/license | Software license for the package. See [list of valid licenses](https://fedoraproject.org/wiki/ParagNemade/CommonRpmlintErrors#invalid-license). 
| Requires:       | RPM_CONFIG/dependencies | List of dependencies with one package name on each line |
| %build          | RPM_CONFIG/scripts/build_script | Script for building code. It could be as simple as one line 'make' or long shell script. |
| %install        | RPM_CONFIG/install_dir OR <br> RPM_CONFIG/scripts/install_script <br> See details below. | Installation directory for built files or custom installation script |
| %pre            | RPM_CONFIG/scripts/pre_install | Script to run before package installation on the target system |
| %post           | RPM_CONFIG/scripts/post_install | Script to run after package installation on the target system |
| %pretrans       | RPM_CONFIG/scripts/pre_trans | Script to run before package transaction on the target system |
| %posttrans      | RPM_CONFIG/scripts/post_trans | Script to run after package transaction on the target system |


Note that, install_dir and install_script files are mutually exclusive. If you use both then install_dir is ignored and install_script is used.

Above details can be overwhelming if you are not familiar with RPM build process. See examples below for typical use cases.

## Examples
### Packaging all repository content as it is in an RPM (install_dir)
Following RPM_CONFIG is simplest way to create a self-contained package with source code as it is. This will put everything in repo under install_dir directory tree.

1. Create RPM_CONFIG directory in your project.
2. Add a valid license (examples Apache License, MIT, GNU etc.) to RPM_CONFIG/license file.
3. Add RPM_CONFIG/install_dir


### Custom installation directory structure
1. Create RPM_CONFIG directory in your project.
2. Add a valid license (examples Apache License, MIT, GNU etc.) to RPM_CONFIG/license file.
3. Create custom install_script

		mkdir -p $RPM_BUILD_ROOT/usr/local/bin
		mkdir -p $RPM_BUILD_ROOT/usr/local/share/mkrpm
		install mkrpm.sh $RPM_BUILD_ROOT/usr/local/bin/mkrpm
		install template.spec  $RPM_BUILD_ROOT/usr/local/share/mkrpm/
		

### Building source code and packaging build artifacts in an RPM


### Including npm modules (self-contained) as part of the RPM
