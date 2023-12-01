# $PROJECT_NAME$

## Building

To build this project, if you didn't build the CARDS platform itself locally, you must first gather the _CARDS-platform_ Maven
artifacts:

```bash
./get_cards_platform_jars.sh
```

Then run:

```bash
mvn clean install -U
```

### Building Docker Images

Docker images for this project are built on top of a generic CARDS image.
You can either download one from the github repository, or build a local image from source.
In either case, the version of CARDS to use must match the version declared in the root `pom.xml` file as the `cards.version` property.

There are two sets of maven build profiles you can choose from:
- if you want to use a `local`, `published`, or `latest` image for the base CARDS project
- and if you want to build a `production` or `development` image

A development image will be slimmer, since it skips copying any of the built JARs into the Docker image, so it must be used on the same machine where it was built, using the local maven repository as a source for dependencies.
Therefore, the resultant image should only be used with the `--dev_docker_image` and `--cards_generic_jars_repo` flags for `generate_compose_yaml.py`.
This is useful for testing new code during development as it does not require a new Docker image to be built every time that code is changed.

A production image will be self-contained, and can be started on any computer, even without access to internet. In this case, the base CARDS image you use must also be a production image.

As for the base image to use, `local` will use a CARDS image built on the same computer, but with a version matching the `cards.version` property, e.g. `cards/cards:0.9.20`,
`published` will use an image with a matching version fetched from our github package repository, e.g. `ghcr.io/data-team-uhn/cards:0.9.20`,
and `latest` will use the latest image built locally, `cards/cards:latest`.
If neither of these are right, you can either change the value to use in `docker/pom.xml`, or in `docker/Dockerfile`,
or just once when building by overriding the `cardsBaseImage` maven parameter, e.g. `mvn install -P production -D cardsBaseImage=ghcr.io/data-team-uhn/cards:0.9.20_apple-cert`.
The default is to use the `local` image.

So, to build a development image based on the latest CARDS image, run:

```bash
mvn clean install -P development,latest
```

To build a production image based on the corresponding published CARDS image, run:

```bash
mvn clean install -P production,published
```

## Running

### Production Mode

#### Using Docker Compose

Enter the main `cards-deploy-tool` repository (https://github.com/data-team-uhn/cards-deploy-tool)
and start the project with:

```bash
python3 generate_compose_yaml.py --cards_docker_image cards/$PROJECT_CODENAME$:latest --oak_filesystem --composum
docker-compose build
docker-compose up -d
```

$PROJECT_CODENAME$ will be available at http://localhost:8080 once it starts.

### Development Mode

#### Using `./start_cards.sh`

Enter the main `cards` repository (https://github.com/data-team-uhn/cards)
and build the generic CARDS platform with:

```bash
mvn clean install
```

Then, start the project with (replace with the current version of this project):

```bash
PROJECT_VERSION=1.0.0-SNAPSHOT ./start_cards.sh --dev --project $PROJECT_CODENAME$ $ADDITIONAL_SLING_FEATURES$
```

$PROJECT_CODENAME$ will be available at http://localhost:8080 once it starts.

#### Using Docker Compose

Enter the main `cards-deploy-tool` repository (https://github.com/data-team-uhn/cards-deploy-tool)
and start the project with:

```bash
python3 generate_compose_yaml.py --dev_docker_image --cards_generic_jars_repo /path/to/$PROJECT_CODENAME$/.cards-generic-mvnrepo --cards_docker_image cards/$PROJECT_CODENAME$:latest --oak_filesystem --composum
docker-compose build
docker-compose up -d
```

$PROJECT_CODENAME$ will be available at http://localhost:8080 once it starts.
