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

# Check that this Docker image is actually present on the build machine
(docker image inspect cards/sling-feature-downloader >/dev/null 2>/dev/null) || { echo "Fail: Could not find the cards/sling-feature-downloader locally. Please get it from https://github.com/data-team-uhn/cards-sling-feature-downloader and build it. Exiting."; exit 1; }

GROUP_NAME=$(cat ../feature/pom.xml | grep --max-count=1 '<groupId>' | cut '-d>' -f2 | cut '-d<' -f1)
PROJECT_NAME=$(cat ../feature/pom.xml | grep --max-count=1 '^  <artifactId>' | cut '-d>' -f2 | cut '-d<' -f1)
PROJECT_VERSION=$(cat ../pom.xml | grep --max-count=1 '^  <version>' | cut '-d>' -f2 | cut '-d<' -f1)

mkdir -p .m2

# Add any packages that are required for running this project and are not included in the generic CARDS Docker image
# to this local .m2 directory
docker run \
	--rm \
	--user $UID:$(id -g) \
	-v ${HOME}/.m2:/host_m2:ro \
	-v $(realpath ../.cards-generic-mvnrepo):/cards-generic-mvnrepo:ro \
	-v $(realpath .m2):/m2 \
	-e MAVEN_FEATURE_NAME="mvn:${GROUP_NAME}/${PROJECT_NAME}/${PROJECT_VERSION}/slingosgifeature" \
	-e MAVEN_REPO_URLS="file:///cards-generic-mvnrepo/repository,http://localhost:8000" \
	--network none \
	--entrypoint /bin/sh \
	cards/sling-feature-downloader /download_single_feature_with_deps.sh
