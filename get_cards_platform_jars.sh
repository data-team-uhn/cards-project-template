#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.


if [[ -n $1 ]]
then
  if [[ $1 =~ .*-SNAPSHOT ]]
  then
    GENERIC_CARDS_DOCKER_IMAGE="cards/cards:latest"
  else
    GENERIC_CARDS_DOCKER_IMAGE="ghcr.io/data-team-uhn/cards:$1"
  fi
else
  GITHUB_CARDS_DOCKER_IMAGE="ghcr.io/data-team-uhn/cards:$(cat pom.xml | grep --max-count=1 '<cards.version>' | cut '-d>' -f2 | cut '-d<' -f1)"
  LOCAL_CARDS_DOCKER_IMAGE="cards/cards:latest"

  whiptail --no-button="Local" --yes-button="Published" --yesno "Use the local or published CARDS image?" 10 80  3>&1 1>&2 2>&3
  VARIANT=$?
  if [[ $VARIANT -eq 1 ]]
  then
    docker run --rm  --entrypoint /bin/sh $LOCAL_CARDS_DOCKER_IMAGE -c "ls -al /root/.m2/repository" >/dev/null 2>/dev/null
    STATUS=$?
    if [[ $STATUS -eq 125 ]]
    then
      whiptail --msgbox "No local image found, please rebuild it following the instructions for building a production-ready docker image in the CARDS README, then try again." 9 78
      exit -1
    elif [[ $STATUS -eq 1 ]]
    then
      whiptail --msgbox "The local image is not a production image, please rebuild it following the instructions for building a production-ready docker image in the CARDS README, then try again." 9 78
      exit -1
    fi
  fi

  if [[ $VARIANT -eq 1 ]]
  then
    GENERIC_CARDS_DOCKER_IMAGE=$LOCAL_CARDS_DOCKER_IMAGE
  else
    GENERIC_CARDS_DOCKER_IMAGE=$GITHUB_CARDS_DOCKER_IMAGE
  fi
fi
mkdir -p .cards-generic-mvnrepo

# Copy the files from the generic CARDS Docker image ~/.m2 directory to this local .cards-generic-mvnrepo directory
docker run \
	--rm \
	-v $(realpath .cards-generic-mvnrepo):/cards-generic-mvnrepo \
	-e HOST_UID=$UID \
	-e HOST_GID=$(id -g) \
	--network none \
	--entrypoint /bin/sh \
	$GENERIC_CARDS_DOCKER_IMAGE -c 'cp -r /root/.m2/repository /cards-generic-mvnrepo && chown -R ${HOST_UID}:${HOST_GID} /cards-generic-mvnrepo'

if [[ $? -ne 0 ]]
then
  whiptail --msgbox "Error: Failed to extract the needed files from the generic CARDS image." 9 78
  exit 1
elif [[ -z $1 ]]
then
  whiptail --msgbox "CARDS generic jars extracted!" 9 78
fi
