#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
  # Reference: http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
  SOURCE="${BASH_SOURCE[0]}"
  BIN_DIR="$( dirname "$SOURCE" )"
  while [ -h "$SOURCE" ]
  do
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$BIN_DIR/$SOURCE"
    BIN_DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
  done
  BIN_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

set -euo pipefail
. $BIN_DIR/bin/report_build_error.sh
setup_report_build_error

# run buildall.sh -help to see options
ROOT=`dirname "$0"`
ROOT=`cd "$ROOT" >/dev/null; pwd`

if [[ "'$ROOT'" =~ [[:blank:]] ]]
then
   echo "IMPALA_TOOL_HOME cannot have spaces in the path"
   exit 1
fi

# Grab this *before* we source impala-config.sh to see if the caller has
# kerberized environment variables already or not.
NEEDS_RE_SOURCE_NOTE=1
: ${MINIKDC_REALM=}
if [[ ! -z "${MINIKDC_REALM}" ]]; then
  NEEDS_RE_SOURCE_NOTE=0
fi

export IMPALA_TOOL_HOME="$ROOT"
if ! . "$ROOT"/bin/impala-config.sh; then
  echo "Bad configuration, aborting buildall."
  exit 1
fi

# Change to IMPALA_TOOL_HOME so that coredumps, etc end up in IMPALA_TOOL_HOME.
cd "${IMPALA_TOOL_HOME}"

bootstrap_dependencies() {
  if [[ "${SKIP_PYTHON_DOWNLOAD}" = true ]]; then
    echo "SKIP_PYTHON_DOWNLOAD is true, skipping python dependencies download."
  else
    echo ">>> Downloading Python dependencies"
    # Download all the Python dependencies we need before doing anything
    # of substance. Does not re-download anything that is already present.
    if ! "$IMPALA_TOOL_HOME/infra/python/deps/download_requirements"; then
      echo "Warning: Unable to download Python requirements."
      echo "Warning: bootstrap_virtualenv or other Python-based tooling may fail."
    else
      echo "Finished downloading Python dependencies"
    fi
  fi

  echo ">>> Init python virtualenv."
  $IMPALA_TOOL_HOME/bin/impala-python -V

  echo ">>> Downloading and extracting toolchain dependencies."
  if [ ! -d "$IMPALA_TOOLCHAIN/breakpad-$IMPALA_BREAKPAD_VERSION" ];then
    tar -zxf $IMPALA_TOOLCHAIN/breakpad-$IMPALA_BREAKPAD_VERSION*gz -C $IMPALA_TOOLCHAIN
  fi
  echo ">>> Finished extracting toolchain dependencies."
}


bootstrap_dependencies