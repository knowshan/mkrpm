## RPMs?? 
RPM is a package management system used by many Linux distributions. RPM packages themeselves are also commonly referred as RPMs. RPM or any other OS native package manager is a convenient way to manage software on a system. System admins love OS native package managers as in many cases they do better job than language specific package managers like pip, gem and npm.

RPM is created using a spec file which contains information about source code, build-install steps, package pre-post installartion steps, version, release and changelogs. mkrpm is a helper script to create RPM spec file and build an RPM using a Docker container.

## Why mkrpm?
As you know, RPM creation requires copy of source code and also a spec file containing things like package version, release, scripts, changelog etc. mkrpm will help you create spec file as part of CI build process on the fly using Git commit information. It is intended to make RPM build process easy and flexible.

## HowTo
There are two things needed for creating RPM using mkrpm:
 * Travis CI configuration to run docker container
 * RPM_CONFIG files that will be used by this script

Note, that mkrpm can be easily modified to work with other CI environments by updating few variables.

This documentation will help you get started with RPM build process in few minutes, but please refer to official Travis CI documentation and Fedora RPM guide for more undertsnading about tools of the trade.

### Travis Configuration File
Add following travis configuration to call mkrpm. You can merge this with your existing Travis configuration file as well. These lines will be same for many projects. All we are doing here is starting a docker cotainer with Travis environment variables and then calling mkrpm. If your project needs any specific libraries or packages for performing the build (e.g. C++ boost or ruby-devel) then you can install them in Travis install section.


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
mkrpm uses files in RPM_CONFIG directory to populate RPM spec file. Most common RPM sections and their corresponding RPM\_CONFIG files are as below:

| RPM section     | mkrpm file    |
| ------------    | -----------   |
| License:        | RPM_CONFIG/license |
| Requires:       | RPM_CONFIG/dependencies |
| %build          | RPM_CONFIG/scripts/build_script |
| %install        | RPM_CONFIG/install_dir OR <br> RPM_CONFIG/scripts/install_script <br> See details below. |
| %pre            | RPM_CONFIG/scripts/pre_install |
| %post           | RPM_CONFIG/scripts/post_install |
| %pretrans       | RPM_CONFIG/scripts/pre_trans |
| %posttrans      | RPM_CONFIG/scripts/post_trans |


Above details can be overwhelming if you are not familiar with RPM. Below are few examples for creating RPM_CONFIG files for typical use cases.

#### Packaging all repository content as it is in an RPM

1. Create RPM_CONFIG directory in your project.
2. Add RPM_CONFIG/license file with valid software license (examples Apache, MIT, GNU)
3. Add RPM_CONFIG/install\_dir 


#### Creating  custom installation directory structure using install script


#### Building source code and packaging build artifacts in an RPM
