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

# Start with the generic CARDS image
# If you want to use the hosted version, or a specific version of cards, pass an argument like this to docker build:
# --build-arg="GENERIC_CARDS_DOCKER_IMAGE=ghcr.io/data-team-uhn/cards:0.9.20_apple-cert"
# --build-arg="GENERIC_CARDS_DOCKER_IMAGE=cards/cards:0.9.20"
FROM ${cardsBaseImage}

# Configure the image for this project
RUN mkdir /external_project
COPY project_code.txt /external_project
COPY project_name.txt /external_project
COPY docker_compose_env.json /external_project
COPY project_logo.png /metadata/logo.png

# Copy in the required JARs
COPY .m2/repository /root/.m2/repository

# Set the current project version
ENV PROJECT_NAME=$PROJECT_CODENAME$
ENV PROJECT_VERSION=${project.version}
