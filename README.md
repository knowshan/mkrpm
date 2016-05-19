RPM is a package management system used by many Linux distributions. RPM packages are also commonly referred as RPM files. RPM or any other OS native package manager is a convenient way to manage software on a system.

RPM is created using a spec file which contains information about source code, build-install steps and package pre-post installartion steps. This little shell script is a helper script to create RPM spec file and build an RPM using a Docker container.

## HowTo
There are two things that need to 
 * Add Travis CI configuration
 * Add RPM_CONFIG files that will be used by this script

Note, that this script can be easily modified to work with other CI environments by updating few variables.

### Travis Configuration Files

Add following travis configuration to call this script. You can merge this with your existing Travis configuration file as well. These lines will be same for many projects. All we are doing here is starting a docker cotainer with Travis environment variables and then calling mkrpm script. If your project needs any specific libraries or packages for performing the build (e.g. C++ boost or ruby-devel) then you can install them in Travis install section.


	sudo: required

	env:
	  - WORKSPACE='/project'

	services:
	  - docker

	language: bash

	before_install:
	  - sudo docker pull knowshan/centos-buildsys

	install:
	  - sudo docker run -d -it -e WORKSPACE="${WORKSPACE}" -e TRAVIS_REPO_SLUG="${TRAVIS_REPO_SLUG}" 	  -e TRAVIS_BUILD_NUMBER="${TRAVIS_BUILD_NUMBER}" -v $PWD:"${WORKSPACE}" --name centos6 knowshan/centos-buildsys

	script:
	  - sudo docker exec centos6 mkrpm



### Adding RPM_CONFIG files

Below are few examples for creating RPM_CONFIG files for typical use cases. I will add more comprehensive documentation soon.

#### Packaging all repository content as it is in an RPM

1. Create RPM_CONFIG directory in your project.
2. Add RPM_CONFIG/license file with valid software license (examples Apache, MIT, GNU)
3. Add RPM_CONFIG/install\_dir 


#### Creating  custom installation directory structure using install script


#### Building source code and packaging build artifacts in an RPM
