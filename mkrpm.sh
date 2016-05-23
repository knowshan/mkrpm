#!/bin/bash

# Display usage
usage(){
cat << EOF
HELP:
Create RPM package out of git repo
OPTIONS:
-h|--help                  Display this usage message

This script will create RPM package from git repo using files in RPM_CONFIG.
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
project=$(echo $TRAVIS_REPO_SLUG | tr '/' '-')
package_name="$project"
user_name=$(echo $TRAVIS_REPO_SLUG | cut -d '/' -f1)
repo_name=$(echo $TRAVIS_REPO_SLUG | cut -d '/' -f2)

read_options "$@"
build_tools_check

if [[ ! -r "$WORKSPACE" ]]; then
    echo "ERROR: $WORKSPACE directory doesn't exist or unreadable." >&2
    exit 1
fi 

echo "#mkrpm: Building project: $project"

# Get date-time for RPM versioning
pushd "$WORKSPACE"
version="$(date -d@$(git log -1 --pretty='format:%at') +%Y.%m.%d.%H.%M)"
if [[ -z "$version" ]]; then
  echo "#mkrpm: Couldn't find latest git commit. Is this project in git repository?"
  exit 1
fi

# rpmdate - used in changelog
rpmdate="$(date -d@$(git log -1 --pretty='format:%at') +'%a %b %d %Y')"
commit_author=$(git log -1 --date=short --pretty='format:%aN <%ae>')
commit_metadata="$rpmdate $commit_author"
commit_hash=$(git log -1 --pretty='format:%H')
commit_msg=$(git log -1 --pretty='format:%s')

# RPM release number
release="$TRAVIS_BUILD_NUMBER"
popd

# RPM_CONFIG dir where rpm scriptlets and build-install options are defined
RPM_CONFIG_DIR="$WORKSPACE/RPM_CONFIG"

# Create tarball and move it to rpm sources directory
tar --transform "s,$(echo $WORKSPACE | tr -d '/'),$package_name-$version," -cvzf $package_name-$version.tgz $WORKSPACE
cp $package_name-$version.tgz "$RPM_SRC_DIR"
echo "#mkrpm: Source tgz $RPM_SRC_DIR/$package_name-$version.tgz"
echo "#mkrpm: Creating RPM spec file."

pushd "$RPM_CONFIG_DIR"

# Create sedcommands to generate RPM spec file from template
mkdir -p scripts
echo "* $commit_metadata" > scripts/changelog
echo "- Commit Hash: $commit_hash" >> scripts/changelog
echo "- Change message: $commit_msg" >> scripts/changelog

summary=$(curl -s https://api.github.com/repos/$user_name/$repo_name | jq .description)

if [[ -z $summary ]]; then
  summary="$project"
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
if [[ $project == 'knowshan-mkrpm' ]]; then
  sed -f sedcommands "$WORKSPACE/template.spec" > "$RPM_SPECS_DIR"/$project.spec
else
  sed -f sedcommands < /usr/local/share/mkrpm/template.spec > "$RPM_SPECS_DIR"/$project.spec
fi

popd

echo "#mkrpm: Building RPM using spec file "$RPM_SPECS_DIR"/$project.spec"

rpmbuild --clean -ba "$RPM_SPECS_DIR"/$project.spec

if [[ "$?" == "0" ]]; then
  echo -e "\033[35mSRPM $RPM_SRPMS_DIR/$package_name-$version-$release.src.rpm\033[0m"
  echo -e "\033[35mRPM $RPM_RPMS_DIR/x86_64/$package_name-$version-$release.x86_64.rpm\033[0m"
  mkdir $WORKSPACE/build_$release
  cp $RPM_SRPMS_DIR/$package_name-$version-$release.src.rpm $WORKSPACE/build_$release/ 
  cp $RPM_RPMS_DIR/x86_64/$package_name-$version-$release.x86_64.rpm $WORKSPACE/build_$release/
  rm -v -f $WORKSPACE/$package_name-$version.tgz
else
  echo "#mkrpm: RPM Build failed!!"
  rm -v -f $WORKSPACE/$package_name-$version.tgz
  exit 1
fi

