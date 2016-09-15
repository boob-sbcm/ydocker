#!/usr/bin/env bash
set -e

# loading settings
source ydocker.conf

function showHelp() {
  echo "
        ydocker.sh is a shell script responsible
        for building and running SAP Hybris Commerce Suite
        in Docker container

        Usage:
          -b    building Docker container
          -r    running Hybris Server in Docker container
          -c    running Docker container with CLI
          -i    showing info about Docker container
          -d    deleting Docker container
          -h    showing help
        "
}

function buildDockerImage() {
  echo -n "SAP username (e-mail): "
  read username
  echo -n "SAP password: "
  read -s password

  if [ "$COMMERCE_SUITE_VERSION" == "latest" ]
  then
    COMMERCE_SUITE_VERSION="" # when we leave this variable empty, we'll get the latest suite
  fi

  # get first endpoint for downloading Commerce Suite through Artifactory REST API
  COMMERCE_SUITE_DOWNLOAD_URL_PREPARATION=`curl -u $username:$password \
  https://repository.hybris.com/api/search/artifact\?name\=commerce-suite-$COMMERCE_SUITE_VERSION\&repos\=hybris-$ARTIFACT_TYPE \
  | python -mjson.tool | grep zip | tail -1 | awk '{print $2}' | sed -e 's/^"//' -e 's/"$//'`

  # get exact url of Commerce Suite from previously extracted endpoint
  COMMERCE_SUITE_DOWNLOAD_URL=`curl -u $username:$password $COMMERCE_SUITE_DOWNLOAD_URL_PREPARATION \
  | python -mjson.tool | grep downloadUri | tail -1 | awk '{print $2}' | sed -e 's/^"//' -e 's/"$//' | rev | cut -c 3- | rev`

  sudo docker build --build-arg SAP_USERNAME="$username" \
  --build-arg SAP_PASSWORD="$password" \
  --build-arg COMMERCE_SUITE_DOWNLOAD_URL="$COMMERCE_SUITE_DOWNLOAD_URL" \
  --build-arg RECIPE="$RECIPE" \
  -t "$DOCKER_IMAGE_NAME" .
}

function runDockerImageServer() {
  sudo docker run -p 127.0.0.1:"$HOST_PORT":"$CONTAINER_PORT" -t "$DOCKER_IMAGE_NAME"
}

function runDockerImageCli() {
  sudo docker run -i -t "$DOCKER_IMAGE_NAME" /bin/bash
}

function showDockerImageInfo() {
  sudo docker images | grep "$DOCKER_IMAGE_NAME"
}

function deleteDockerImage() {
  sudo docker rmi -f "$DOCKER_IMAGE_NAME"
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

while getopts "hbrcid" opt; do
    case "$opt" in
    h)
        showHelp
        exit 0
        ;;
    b)  buildDockerImage
        ;;
    r)  runDockerImageServer
        ;;
    c)  runDockerImageCli
        ;;
    i)  showDockerImageInfo
        ;;
    d)  deleteDockerImage
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift
