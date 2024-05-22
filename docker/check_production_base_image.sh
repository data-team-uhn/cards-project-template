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

# First check that the Docker image exists on the local machine
if [[ ${cardsBaseImage} == cards/cards:latest ]]
then
  docker image inspect ${cardsBaseImage} >/dev/null 2>/dev/null
  if [[ $? -ne 0 ]]
  then
    echo "No local image found, please rebuild it following the instructions for building a production-ready docker image in the CARDS README, then try again." 1>&2
    exit -1
  fi
fi

# Then check if it is a production image
docker run --rm  --entrypoint /bin/sh ${cardsBaseImage} -c "ls -1 /root/.m2/repository/io/uhndata/cards/cards" >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
  echo "The local image is not a production image, please rebuild it following the instructions for building a production-ready docker image in the CARDS README, then try again." 1>&2
  exit -1
fi

# Then check if it is with the expected version
docker run --rm  --entrypoint /bin/sh ${cardsBaseImage} -c "ls -1 /root/.m2/repository/io/uhndata/cards/cards/${cardsBaseVersion}/" >/dev/null 2>/dev/null
if [[ $? -ne 0 ]]
then
  echo "The local image does not have the expected version ${cardsBaseVersion}, please build the correct version, then try again." 1>&2
  exit -1
fi
