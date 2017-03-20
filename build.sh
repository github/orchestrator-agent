#!/bin/bash

# Simple packaging of orchestrator-agent
#
# Requires fpm: https://github.com/jordansissel/fpm
#
set -e

RELEASE_VERSION=$(cat RELEASE_VERSION)
TOPDIR=/tmp/orchestrator-agent-release
export RELEASE_VERSION TOPDIR
export GO15VENDOREXPERIMENT=1

usage() {
  echo
  echo "Usage: $0 [-t target ] [-a arch ] [ -p prefix ] [-h] [-d] [-r]"
  echo "Options:"
  echo "-h Show this screen"
  echo "-t (linux|darwin) Target OS Default:(linux)"
  echo "-a (amd64|386) Arch Default:(amd64)"
  echo "-d debug output"
  echo "-b build only, do not generate packages"
  echo "-p build prefix Default:(/usr/local)"
  echo "-r build with race detector"
  echo "-s release subversion"
  echo
}

function precheck() {
  local target
  local ok=0 # return err. so shell exit code

  if [[ "$target" == "linux" ]]; then
    if [[ ! -x "$( which fpm )" ]]; then
      echo "Please install fpm and ensure it is in PATH (typically: 'gem install fpm')"
      ok=1
    fi

    if [[ ! -x "$( which rpmbuild )" ]]; then
      echo "rpmbuild not in PATH, rpm will not be built (OS/X: 'brew install rpm')"
    fi
  fi

  if [[ -z "$GOPATH" ]]; then
    echo "GOPATH not set"
    ok=1
  fi

  if [[ ! -x "$( which go )" ]]; then
    echo "go binary not found in PATH"
    ok=1
  fi

  if [[ $(go version | egrep "go1[.][01234]") ]]; then
    echo "go version is too low. Must use 1.5 or above"
    ok=1
  fi

  return $ok
}

function setuptree() {
  local b prefix
  prefix="$1"

  mkdir -p $TOPDIR
  rm -rf ${TOPDIR:?}/*
  b=$( mktemp -d $TOPDIR/orchestrator-agentXXXXXX ) || return 1
  mkdir -p $b/orchestrator-agent
  mkdir -p $b/orchestrator-agent${prefix}/orchestrator-agent/
  mkdir -p $b/orchestrator-agent/etc/init.d
  echo $b
}

function oinstall() {
  local builddir prefix
  builddir="$1"
  prefix="$2"

  cd  $(dirname $0)
  gofmt -s -w  go/
  mkdir -p $builddir/orchestrator-agent${prefix}/orchestrator-agent/conf
  cp ./conf/orchestrator-agent.conf.json $builddir/orchestrator-agent${prefix}/orchestrator-agent/conf/orchestrator-agent.conf.json.sample
  cp etc/init.d/orchestrator-agent.bash $builddir/orchestrator-agent/etc/init.d/orchestrator-agent
  chmod +x $builddir/orchestrator-agent/etc/init.d/orchestrator-agent
}

function package() {
  local target builddir prefix packages
  target="$1"
  arch="$2"
  prefix="$3"
  builddir="$3"

  cd $TOPDIR

  echo "Release version is ${RELEASE_VERSION}"

  case $target in
    'linux')
      echo "Creating Linux Tar package"
      tar -C $builddir/orchestrator-agent -czf $TOPDIR/orchestrator-agent-"${RELEASE_VERSION}"-$target-$arch.tar.gz ./

      echo "Creating Distro full packages"
      fpm -v "${RELEASE_VERSION}" --epoch 1 -f -s dir -t rpm -n orchestrator-agent -C $builddir/orchestrator-agent --prefix=/ .
      fpm -v "${RELEASE_VERSION}" --epoch 1 -f -s dir -t deb -a "$target-$arch" -n orchestrator-agent -C $builddir/orchestrator-agent --prefix=/ --deb-no-default-config-files .

      cd $TOPDIR
      ;;
    'darwin')
      echo "Creating Darwin full Package"
      tar -C $builddir/orchestrator-agent -czf $TOPDIR/orchestrator-agent-"${RELEASE_VERSION}"-$target-$arch.tar.gz ./

      ;;
  esac

  echo "---"
  echo "Done. Find releases in $TOPDIR"
}

function build() {
  local target arch builddir gobuild prefix
  os="$1"
  arch="$2"
  builddir="$3"
  prefix="$4"
  ldflags="-X main.AppVersion=${RELEASE_VERSION}"
  echo "Building via $(go version)"
  gobuild="go build ${opt_race} -ldflags \"$ldflags\" -o $builddir/orchestrator-agent${prefix}/orchestrator-agent/orchestrator-agent go/cmd/orchestrator-agent/main.go"

  case $os in
    'linux')
      echo "GOOS=$os GOARCH=$arch $gobuild" | bash
    ;;
    'darwin')
      echo "GOOS=darwin GOARCH=amd64 $gobuild" | bash
    ;;
  esac
  [[ $(find $builddir/orchestrator-agent${prefix}/orchestrator-agent/ -type f -name orchestrator-agent) ]] &&  echo "orchestrator-agent binary created" || (echo "Failed to generate orchestrator-agent binary" ; exit 1)
}

function main() {
  local target arch builddir prefix build_only
  target="$1"
  arch="$2"
  prefix="$3"
  build_only=$4

  precheck "$target"
  builddir=$( setuptree "$prefix" )
  oinstall "$builddir" "$prefix"
  build "$target" "$arch" "$builddir" "$prefix"
  [[ $? == 0 ]] || return 1
  if [[ $build_only -eq 0 ]]; then
    package "$target" "$arch" "$builddir" "$prefix"
  fi
}

build_only=0
opt_race=
while getopts a:t:p:s:dbhr flag; do
  case $flag in
  a)
    arch="$OPTARG"
    ;;
  t)
    target="$OPTARG"
    ;;
  h)
    usage
    exit 0
    ;;
  d)
    debug=1
    ;;
  b)
    echo "Build only; no packaging"
    build_only=1
    ;;
  p)
    prefix="$OPTARG"
    ;;
  r)
    opt_race="-race"
    ;;
  s)
    RELEASE_VERSION="${RELEASE_VERSION}_${OPTARG}"
    ;;
  ?)
    usage
    exit 2
    ;;
  esac
done

shift $(( OPTIND - 1 ));
target=${target:-"linux"} # default for target is linux
arch=${arch:-"amd64"} # default for arch is amd64
prefix=${prefix:-"/usr/local"}

[[ $debug -eq 1 ]] && set -x
main "$target" "$arch" "$prefix" "$build_only"

echo "orchestrator-agent build done; exit status is $?"
