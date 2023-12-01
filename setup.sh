#!/bin/bash

# Ask about the generic CARDS version to use

# Get the latest CARDS version from Nexus
CARDS_VERSION=$(curl -s https://nexus.phenotips.org/nexus/content/repositories/releases/io/uhndata/cards/cards-modules/maven-metadata.xml | grep --max-count=1 '<release>' | cut '-d>' -f2 | cut '-d<' -f1)
if [[ -z $CARDS_VERSION ]]
then
  # If Nexus isn't available, try to look on the local disk
  CARDS_VERSION=$(grep --max-count=1 '^  <version>' ../cards/pom.xml | cut '-d>' -f2 | cut '-d<' -f1)
fi
echo
echo "Which version of the CARDS platform should be used?"
read -e -i "$CARDS_VERSION" CARDS_VERSION

# Ask about the project name

echo "What is the project's codename, e.g. cards4sparc, cards4heracles"
read -e -i cards4 PROJECT_CODENAME

# Remove the cards4 prefix to get the short unprefixed name
PROJECT_SHORTNAME=${PROJECT_CODENAME#cards4}

echo
echo "What is the project's user facing name, e.g SPARC, Heracles"
read -e PROJECT_NAME

# Ask for the project logo

echo
LOGO=/
# ~ doesn't work in scripts, so we manually replace it with $HOME
until [[ -f $(realpath "${LOGO/\~/$HOME}") ]]
do
  echo "Please provide a logo for the project. It should be a file about 200px wide and 80px tall, and display well on a dark background."
  read -e LOGO
  LOGO=${LOGO/\~/$HOME}
done

echo
echo "Please provide a logo to be displayed on a light background. If the same image as before can be used, just press enter."
read -e LOGO_LIGHT
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

echo
echo "Does the project have backend code?"
HAS_BACKEND=maybe
until [[ $HAS_BACKEND == "yes" || $HAS_BACKEND == "no" ]]
do
  read -e -p "[yes|no] " -i "no" HAS_BACKEND

  if [[ $HAS_BACKEND != "yes" && $HAS_BACKEND != "no" ]]
  then
    echo "Unknown answer, please type either yes or no"
  fi
done

if [[ $HAS_BACKEND == "no" ]]
then
  git rm -rf backend
  sed -i -e '/backend/,+3d' feature/src/main/features/feature.json
  sed -i -e '/backend/d' pom.xml
fi

# Ask about other features to use

# Get the list of features already included in the base distribution
# Then get the list of all features known, excluding the cards4* projects
# Then subtract included features from the list of all known features
declare -a features=( $(find ~/.m2/repository/io/uhndata/cards/cards/${CARDS_VERSION}/ -type f -name '*slingosgifeature' | sed -r -e "s/.*${CARDS_VERSION}-(.*).slingosgifeature/-e \1/" -e /cards/d) )
features=( $(find ~/.m2/repository/io/uhndata/cards/ -type f -name "*${CARDS_VERSION}.slingosgifeature" | grep -v -e 'cards4' | grep -v ${features[*]} | sed -r -e "s/.*\/(.*)-${CARDS_VERSION}.slingosgifeature/\1/") )
declare -i featureCount=${#features[*]}
declare -a featureSelection
for (( i=0 ; i<featureCount; i++ ))
do
  featureSelection[${i}]=0
done
echo
echo "Other features to enable?"
SELECTION=-1
until [[ -z $SELECTION ]]
do
  for (( i=0 ; i<featureCount ; i++ ))
  do
    echo -n $(($i+1)) '['
    if [[ ${featureSelection[${i}]} -eq 1 ]]
    then
      echo -n '*'
    else
      echo -n ' '
    fi
    echo ']' ${features[$i]}
  done
  read -e SELECTION
  if [[ $SELECTION -ge 1 ]]
  then
    featureSelection[$((${SELECTION}-1))]=1
  elif [[ $SELECTION -le -1 ]]
  then
    featureSelection[$((-1 - ${SELECTION}))]=0
  fi
done

ADDITIONAL_SLING_FEATURES_DOCKER=''
ADDITIONAL_SLING_FEATURES_STARTSH=''
for (( i=0 ; i<featureCount ; i++ ))
do
  if [[ ${featureSelection[$i]} -eq 1 ]]
  then
    ADDITIONAL_SLING_FEATURES_DOCKER+=",mvn:io.uhndata.cards/${features[$i]}/\$\${CARDS_VERSION}/slingosgifeature"
    ADDITIONAL_SLING_FEATURES_STARTSH+=",mvn:io.uhndata.cards/${features[$i]}/\${CARDS_VERSION}/slingosgifeature"
  fi
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
