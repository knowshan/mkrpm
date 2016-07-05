#!/bin/bash

# Display usage
usage(){
cat << EOF
HELP:
Create RPM package out of git repo
OPTIONS:
-h|--help                  Display this usage message

This script will create RPM package from git repo using files in PACKAGE_CONFIG.
RPM name: $GH_USER_NAME-$REPO_NAME
Version : YYYY.MM.DD.HH.MM datetime from latest commit
Release : $TRAVIS_BUILD_NUMBER

EOF
exit 0
}

function read_options(){
  # Get output (options list) from getopt  
  TEMP_OPTS=`getopt -o h --longoptions help -- $@`

  # $? exit code will be non-zero if options passed using $@ aren't passed according getopt command options  
  if [ $? != 0 ]; then
    echo "ERROR: Terminating $0.." >&2 
    # Display help/usage and exit
    usage
    exit 1
  fi
  
  eval set -- "$TEMP_OPTS"
  
  # Start-While parse command-line options
  while true
  do
    case "$1" in
      -h|--help)
        echo 'help'
        usage
      ;;
      # Package name
      -n|--name)
        packagename="$2"
        shift 2
      ;;
      # Package version
      -v|--version)
        packageversion=$2
        shift 2
      ;;
      # Package release
      -r|--release)
        packagerelease=$2
        shift 2
      ;;
      --)
        # -- indicates end of options list - break out of the loop
        shift 
        break 
      ;;
      *)
        # For any option other than above - return Invalid Option error
        echo "ERROR: Invalid Option: $1" >&2
        exit 1 
      ;;
    esac
  done

}

function build_tools_check(){
  # Check if system has basic build tools installed in PATH
  #  - rpmbuild and git
  r=`which git`
  if [[ $? != 0 ]]; then
    echo 'Command "git" not found. Please install git.'
    ec=1
  fi
  r=`which rpmbuild`
  if [[ $? != 0 ]]; then
    echo 'Command "rpmbuild" not found. Please install rpmbuild.'
    ec=1
  fi
  if [[ ! -r "$WORKSPACE" ]]; then
    echo "ERROR: $WORKSPACE directory doesn't exist or unreadable." >&2
    ec=1
  fi
  if [[ $ec == 1 ]]; then
    exit 1
  fi
  RPM_RPMS_DIR=$(rpm --eval '%{_rpmdir}')
  RPM_SRPMS_DIR=$(rpm --eval '%{_srcrpmdir}')
  RPM_SPECS_DIR=$(rpm --eval '%{_specdir}')
  RPM_SRC_DIR=$(rpm --eval '%{_sourcedir}')
  mkdir -p "$RPM_RPMS_DIR"
  mkdir -p "$RPM_SRPMS_DIR"
  mkdir -p "$RPM_SPECS_DIR"
  mkdir -p "$RPM_SRC_DIR"

}


# Read Input: 
# Call read_options to read options using getopt
GIT_DIR=$WORKSPACE/.git
if [[ "$?" != 0 ]]; then
  echo "#mkrpm: Couldn't get 'git status'. Is this $GIT_DIR a git repository?"
  exit 1
fi

read_options "$@"
build_tools_check

# Set package name
if [[ -z "$packagename" ]]; then
    package_name=$(git remote -v | awk -F '/' '/(fetch)/ {print $4"-"$5}' | cut -d '.' -f1)
fi

# Set package version based on date-time
if [[ -z "$packageversion" ]]; then
    package_version="$(date -d@$(git log -1 --pretty='format:%at') +%Y.%m.%d.%H.%M)"
fi

# Set package release number
if [[ -z "$packagerelease" ]]; then
    package_release="$TRAVIS_BUILD_NUMBER"
fi


# rpmdate - used in changelog
rpmdate="$(date -d@$(git log -1 --pretty='format:%at') +'%a %b %d %Y')"
commit_author=$(git log -1 --date=short --pretty='format:%aN <%ae>')
commit_metadata="$rpmdate $commit_author"
commit_hash=$(git log -1 --pretty='format:%H')
commit_msg=$(git log -1 --pretty='format:%s')



echo "#mkrpm: Building package: $package_name"

# PACKAGE_CONFIG dir where rpm scriptlets and build-install options are defined
PACKAGE_CONFIG_DIR="$WORKSPACE/PACKAGE_CONFIG"

# Create tarball and move it to rpm sources directory
tar --transform "s,$(echo $WORKSPACE | tr -d '/'),$package_name-$package_version," -czf $package_name-$package_version.tgz $WORKSPACE
cp $package_name-$package_version.tgz "$RPM_SRC_DIR"
echo "#mkrpm: Source tgz $RPM_SRC_DIR/$package_name-$package_version.tgz"
echo "#mkrpm: Creating RPM spec file."

pushd "$PACKAGE_CONFIG_DIR"

# Create sedcommands to generate RPM spec file from template
mkdir -p scripts
echo "* $commit_metadata" > scripts/changelog
echo "- Git Repo: $TRAVIS_REPO_SLUG" >> scripts/changelog
echo "- Commit Hash: $commit_hash" >> scripts/changelog
echo "- Change message: $commit_msg" >> scripts/changelog

summary=$(curl -s https://api.github.com/repos/$user_name/$repo_name | jq .description)

if [[ -z $summary ]]; then
  summary="$package_name"
fi

if [[ -r license ]]; then
  license=$(<license)
else
  echo "RPM package requires a software license specified."
  exit 1
fi

echo "s/^Name:/& $package_name/" > sedcommands
echo "s/^Summary:/& $package_name/" >> sedcommands
echo "s/^Version:/& $version/" >> sedcommands
echo "s/^Release:/& $release/" >> sedcommands
echo "s/^License:/& $license/" >> sedcommands

if [[ -r dependencies ]]; then
  echo "" > dependencies_requires
  while read line
  do
    echo  "Requires: $line" >> dependencies_requires
  done < dependencies
  echo "/^Buildroot:/r dependencies_requires" >> sedcommands
fi

if [[ -r install_dir ]]; then
  install_dir=$(<install_dir)
  echo "s|INSTALLATION_DIRECTORY$|$install_dir|" >> sedcommands
fi

if [[ -r scripts/build_script ]]; then
  echo "/%build$/r scripts/build_script" >> sedcommands
fi

if [[ -r scripts/install_script ]]; then
  echo "/%install/,/%clean/{//!d}" >> sedcommands
  echo "/%install$/r scripts/install_script" >> sedcommands
fi

if [[ -r scripts/pre_install ]]; then
  echo "/%pre$/r scripts/pre_install" >> sedcommands
fi

if [[ -r scripts/post_install ]]; then
  echo "/%post$/r scripts/post_install" >> sedcommands
fi

if [[ -r scripts/pre_uninstall ]]; then
  echo "/%preun$/r scripts/pre_uninstall" >> sedcommands
fi

if [[ -r scripts/post_trans ]]; then
  echo "/%posttrans$/r scripts/post_trans" >> sedcommands
fi

if [[ -r scripts/pre_trans ]]; then
  echo "/%pretrans$/r scripts/pre_trans" >> sedcommands
fi

if [[ -r packaged_files ]]; then
  echo "/%files/,/%changelog/{//!d}" >> sedcommands
  echo "/%files$/r packaged_files" >> sedcommands
fi

if [[ -r scripts/changelog ]]; then
  echo "/%changelog$/r scripts/changelog" >> sedcommands
fi

# If building itself - use latest template.spec file, Else, use deployed template.spec file
if [[ $package_name == 'knowshan-mkrpm' ]]; then
  sed -f sedcommands "$WORKSPACE/template.spec" > "$RPM_SPECS_DIR"/$package_name.spec
else
  sed -f sedcommands < /usr/local/share/mkrpm/template.spec > "$RPM_SPECS_DIR"/$package_name.spec
fi

popd

echo "#mkrpm: Building RPM using spec file "$RPM_SPECS_DIR"/$package_name.spec"

rpmbuild --clean -ba "$RPM_SPECS_DIR"/$package_name.spec

if [[ "$?" == "0" ]]; then
  echo -e "\033[35mSRPM $RPM_SRPMS_DIR/$package_name-$package_version-$package_release.src.rpm\033[0m"
  echo -e "\033[35mRPM $RPM_RPMS_DIR/x86_64/$package_name-$package_version-$package_release.x86_64.rpm\033[0m"
  mkdir $WORKSPACE/build_$package_release
  cp $RPM_SRPMS_DIR/$package_name-$package_version-$package_release.src.rpm $WORKSPACE/build_$package_release/ 
  cp $RPM_RPMS_DIR/x86_64/$package_name-$package_version-$package_release.x86_64.rpm $WORKSPACE/build_$package_release/
  rm -v -f $WORKSPACE/$package_name-$package_version.tgz
else
  echo "#mkrpm: RPM Build failed!!"
  rm -v -f $WORKSPACE/$package_name-$package_version.tgz
  exit 1
fi
