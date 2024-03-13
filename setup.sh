#!/bin/bash

#  Copyright 2023 DATA @ UHN. See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Check the user's authorship configuration
if ! $(git config user.name 1> /dev/null) || ! $(git config user.email 1> /dev/null)
then
  whiptail --backtitle "New CARDS repository setup" --msgbox "You must configure the user name and email address with \"git config user.name Some Name\" and \"git config user.email somebody@email.com\" and then rerun this script. Exiting." 9 78
  exit 1
fi

if ! whiptail --backtitle "New CARDS repository setup" --title "Please confirm git authorship details" --yesno "Committing as $(git config user.name) <$(git config user.email)>, OK?" 8 78
then
  whiptail --backtitle "New CARDS repository setup" --msgbox "You can configure the user name and email address with \"git config user.name Some Name\" and \"git config user.email somebody@email.com\" and then rerun this script. Exiting." 9 78
  exit 1
fi

# Ask about the generic CARDS version to use

# Get the available CARDS versions from Maven Central
declare -a RELEASED_VERSIONS=( $(curl -s https://repo1.maven.org/maven2/io/uhndata/cards/cards-modules/maven-metadata.xml | grep '<version>' | tac | cut '-d>' -f2 | cut '-d<' -f1) )
declare -i RELEASED_VERSIONS_COUNT=${#RELEASED_VERSIONS[*]}
# Look on the local disk
LOCAL_CARDS_VERSION=$(grep --max-count=1 '^  <version>' ../cards/pom.xml 2>/dev/null | cut '-d>' -f2 | cut '-d<' -f1)
declare VERSION
declare HAS_DEFAULT
for (( i=0 ; i<RELEASED_VERSIONS_COUNT; i++ ))
do
  VERSION="${VERSION} ${RELEASED_VERSIONS[$i]} ${RELEASED_VERSIONS[$i]} ${HAS_DEFAULT:-ON} "
  HAS_DEFAULT=OFF
done
if [[ -n $LOCAL_CARDS_VERSION ]]
then
  VERSION="${LOCAL_CARDS_VERSION} ${LOCAL_CARDS_VERSION} ${HAS_DEFAULT:-ON} ${VERSION}"
  HAS_DEFAULT=OFF
fi
VERSION="${VERSION} other other ${HAS_DEFAULT:-ON}"
CARDS_VERSION=$(whiptail --backtitle "New CARDS repository setup" --title "Base CARDS version" --radiolist --notags "Which version of the CARDS platform should be used?" 38 78 30 $VERSION 3>&1 1>&2 2>&3)
if [[ $? == 1 ]]
then
  exit 1
fi
if [[ $CARDS_VERSION == "other" ]]
then
  until [[ $CARDS_VERSION != "other" && -n $CARDS_VERSION ]]
  do
    CARDS_VERSION=$(whiptail --backtitle "New CARDS repository setup" --title "Base CARDS version" --inputbox "Which version of the CARDS platform should be used? e.g. 0.9.22" 8 78 3>&1 1>&2 2>&3)
    if [[ $? == 1 ]]
    then
      exit 1
    fi
  done
fi

# Ask about the project name

PROJECT_CODENAME=$(whiptail --backtitle "New CARDS repository setup" --title "Project name" --inputbox "What is the project's codename? e.g. cards4sparc, cards4lfs" 8 78 cards4 3>&1 1>&2 2>&3)
if [[ $? == 1 ]]
then
  exit 1
fi

# Remove the cards4 prefix to get the short unprefixed name
PROJECT_SHORTNAME=${PROJECT_CODENAME#cards4}
if [[ $? == 1 ]]
then
  exit 1
fi

PROJECT_NAME=$(whiptail --backtitle "New CARDS repository setup" --title "Project name" --inputbox "What is the project's user facing name? e.g SPARC, LFS Data Core" 8 78 3>&1 1>&2 2>&3)
if [[ $? == 1 ]]
then
  exit 1
fi

# Ask for the project logo
# ~ doesn't work in scripts, so we manually replace it with $HOME
LOGO=/
until [[ -f $(realpath "${LOGO/\~/$HOME}") ]]
do
  LOGO=$(whiptail --backtitle "New CARDS repository setup" --title "Project logo" --inputbox "Please provide a logo for the project. It should be a file about 200px wide and 80px tall, and display well on a dark background." 8 78 3>&1 1>&2 2>&3)
  LOGO=${LOGO/\~/$HOME}
done

LOGO_LIGHT=$(whiptail --backtitle "New CARDS repository setup" --title "Project logo" --inputbox "Please provide a logo to be displayed on a light background. If the same image as before can be used, just press enter." 8 78 3>&1 1>&2 2>&3)
LOGO_LIGHT=${LOGO_LIGHT/\~/$HOME}

# Copy the logos in the right place and use the right path in the Media.json configuration file

mkdir -p "resources/src/main/media/SLING-INF/content/libs/cards/resources/media/${PROJECT_SHORTNAME}"
cp "$LOGO" "resources/src/main/media/SLING-INF/content/libs/cards/resources/media/${PROJECT_SHORTNAME}/"
sed -i -e "s/\\\$PROJECT_LOGO\\\$/${PROJECT_SHORTNAME}\\/$(basename $LOGO)/g" resources/src/main/resources/SLING-INF/content/libs/cards/conf/Media.json
if [[ -f $LOGO_LIGHT ]]
then
  cp "$LOGO_LIGHT" "resources/src/main/media/SLING-INF/content/libs/cards/resources/media/${PROJECT_SHORTNAME}/"
  sed -i -e "s/\\\$PROJECT_LOGO_LIGHT\\\$/${PROJECT_SHORTNAME}\\/$(basename $LOGO_LIGHT)/g" resources/src/main/resources/SLING-INF/content/libs/cards/conf/Media.json
  cp "$LOGO_LIGHT" "docker/project_logo.png"
else
  sed -i -e "s/\\\$PROJECT_LOGO_LIGHT\\\$/${PROJECT_SHORTNAME}\\/$(basename $LOGO)/g" resources/src/main/resources/SLING-INF/content/libs/cards/conf/Media.json
  cp "$LOGO" "docker/project_logo.png"
fi

# Check if the backend module can be removed
if ! whiptail --backtitle "New CARDS repository setup" --title "Modules setup" --yesno "Does the project have backend code?" 8 78
then
  git rm -rf backend
  sed -i -e '/backend/,+3d' feature/src/main/features/feature.json
  sed -i -e '/backend/d' pom.xml
fi

# Ask about other features to use

# Get the list of features already included in the base distribution
# Then get the list of all features known, excluding the cards4* projects
# Then subtract included features from the list of all known features
./get_cards_platform_jars.sh ${CARDS_VERSION}
declare -a features=( $(find .cards-generic-mvnrepo/repository/io/uhndata/cards/cards/${CARDS_VERSION}/ -type f -name '*slingosgifeature' | sed -r -e "s/.*${CARDS_VERSION}-(.*).slingosgifeature/-e \1/" -e /cards/d) )
features=( $(find .cards-generic-mvnrepo/repository/io/uhndata/cards/ -type f -name "*${CARDS_VERSION}.slingosgifeature" | grep -v -e 'cards4' | grep -v ${features[*]} | sed -r -e "s/.*\/(.*)-${CARDS_VERSION}.slingosgifeature/\1/") )
declare -i featureCount=${#features[*]}
declare featurelist
for (( i=0 ; i<featureCount; i++ ))
do
  featurelist+="${features[$i]} ${features[$i]} OFF "
done
selectedFeatures=$(whiptail --backtitle "New CARDS repository setup" --title "Modules setup" --checklist --notags "Other features to enable?" 38 78 30 $featurelist 3>&1 1>&2 2>&3)

ADDITIONAL_SLING_FEATURES_DOCKER=''
ADDITIONAL_SLING_FEATURES_STARTSH=''
for i in $selectedFeatures
do
  ADDITIONAL_SLING_FEATURES_DOCKER+=",mvn:io.uhndata.cards/${i//\"/}/\$\${CARDS_VERSION}/slingosgifeature"
  ADDITIONAL_SLING_FEATURES_STARTSH+=",mvn:io.uhndata.cards/${i//\"/}/\${CARDS_VERSION}/slingosgifeature"
done
ADDITIONAL_SLING_FEATURES_DOCKER=${ADDITIONAL_SLING_FEATURES_DOCKER#,}
ADDITIONAL_SLING_FEATURES_STARTSH=${ADDITIONAL_SLING_FEATURES_STARTSH#,}
if [[ -z $ADDITIONAL_SLING_FEATURES_DOCKER ]]
then
  sed -i -e '/ADDITIONAL_SLING_FEATURES/,+4d' docker/docker_compose_env.json
  sed -i -e "s/\\\$ADDITIONAL_SLING_FEATURES\\\$//g" README.template.md
else
  sed -i -e "s/\\\$ADDITIONAL_SLING_FEATURES\\\$/${ADDITIONAL_SLING_FEATURES_DOCKER//\//\\\/}/g" docker/docker_compose_env.json
  sed -i -e "s/\\\$ADDITIONAL_SLING_FEATURES\\\$/-f '${ADDITIONAL_SLING_FEATURES_STARTSH//\//\\\/}'/g" README.template.md
fi

git rm README.md
git mv README.template.md README.md
find . -type f -exec sed -i -e "s/\\\$PROJECT_CODENAME\\\$/${PROJECT_CODENAME}/g" -e "s/\\\$PROJECT_NAME\\\$/${PROJECT_NAME}/g" -e "s/\\\$PROJECT_SHORTNAME\\\$/${PROJECT_SHORTNAME}/g" -e "s/\\\$CARDS_VERSION\\\$/${CARDS_VERSION}/g" {} +
git rm setup.sh
git add .
git commit
