#!/bin/sh

set -e

REPO_DIR=`pwd`
APP_VERSION=$(cat gradle.properties | grep -oP 'version=\K(.+)')

echo "> builder.bash version=${APP_VERSION}, path=${REPO_DIR}"

generateDocs(){
  echo "> Generating docs version=${1}, target=${2}"
  mkdir -p "${2}"
  hugo --baseURL=http://mageddo.github.io/dns-proxy-server/$1 \
  --destination $2 \
  --ignoreCache --source docs/

  echo "> Generated docs version=$1, out files:"
  ls -lha $2
}

copyFileFromService(){

  serviceName=$1
  from=$2
  to=$3

  docker-compose up --no-start --build --force-recreate $serviceName 1>&2
  id=$(docker ps -a | grep $serviceName | awk '{print $1}')
  docker cp "$id:$from" "$to"
}

validateRelease(){
  echo "> validate release, version=${APP_VERSION}, git=$(git rev-parse $APP_VERSION 2>/dev/null)"
  if git rev-parse "$APP_VERSION^{}" >/dev/null 2>&1; then
    echo "> Tag already exists $APP_VERSION"
    exit 3
  fi
}

case $1 in

  validate-release )
    validateRelease
  ;;

  build-frontend )
    ./builder.bash validate-release || exit 0

    echo "> Building frontend files..."
    docker-compose build --progress=plain build-frontend
    rm -rf ./src/main/resources/META-INF/resources/static
    copyFileFromService build-frontend /static ./src/main/resources/META-INF/resources/static

    echo "> Build, test and generate the binaries"
    mkdir -p "${REPO_DIR}/build"

  ;;

  build-backend )

    OS=linux
    ARCH=$1
    BUILD_SERVICE_NAME="build-${OS}-${ARCH}"
    IMAGE_SERVICE_NAME="image-${OS}-${ARCH}"
    ARTIFACTS_DIR="${REPO_DIR}/build/artifacts"

    echo "> building backend to: os=${OS}, arch=${ARCH}"

    mkdir -p ${ARTIFACTS_DIR}

    VERSION=${APP_VERSION} \
    docker-compose build --progress=plain ${BUILD_SERVICE_NAME}

    copyFileFromService ${BUILD_SERVICE_NAME} /app/build/artifacts /tmp/
    mv -v /tmp/artifacts/* ${ARTIFACTS_DIR}

    VERSION=${APP_VERSION} \
    docker-compose build --progress=plain "${IMAGE_SERVICE_NAME}"

  ;;

  compress-upload-artifacts )
    echo "> compress the files ..."

    ARTIFACTS_DIR="${REPO_DIR}/build/artifacts"
    COMPRESSED_ARTIFACTS_DIR="${REPO_DIR}/build/compressed-artifacts"

    mkdir -p ${COMPRESSED_ARTIFACTS_DIR}
    cd ${ARTIFACTS_DIR}

    ls ${ARTIFACTS_DIR} | grep -v "native-image-source" |\
    while read -r f ; do
      tgz="${COMPRESSED_ARTIFACTS_DIR}/dns-proxy-server-${f}.tgz"
      tar -czvf ${tgz} ${f}
      echo "> compressed ${f} to ${tgz} ..."
    done

    echo "> Uploading the release artifacts"
    cd $REPO_DIR
    DESC=$(cat RELEASE-NOTES.md | awk 'BEGIN {RS="|"} {print substr($0, 0, index(substr($0, 3), "###"))}' | sed ':a;N;$!ba;s/\n/\\r\\n/g')
    github-cli release mageddo dns-proxy-server $APP_VERSION $CURRENT_BRANCH "${DESC}" ${COMPRESSED_ARTIFACTS_DIR}/*.tgz

  ;;

  docker-push )
    echo "> Push docker images to docker hub"
    docker tag defreitas/dns-proxy-server:${APP_VERSION} defreitas/dns-proxy-server:latest &&\
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin &&\
    VERSION=${APP_VERSION} docker-compose push image-linux-amd64 image-linux-aarch64
  ;;

  deploy )

  echo "> Deploy started , current branch=$CURRENT_BRANCH"

  ./builder.bash validate-release || exit 0

  ./builder.bash build-frontend
  ./builder.bash build-backend amd64 #also builds the jar
  ./builder.bash build-backend aarch64

  ./builder.bash compress-upload-artifacts

  ./builder.bash docker-push
  ;;

  deploy-docs )

    echo "> Docs build"
    P="${REPO_DIR}/build/hugo"

    echo "> Generating in ${P} ..."

    MINOR_VERSION=$(echo $APP_VERSION | awk -F '.' '{ print $1"."$2}');
    rm -r "${P}/docs" || echo "> build dir already clear"

    # Generate link for generated docs versions
    versionsFile=docs/content/versions/_index.en.md
    { git ls-tree origin/gh-pages | grep -E -o '[0-9]+\.[0-9]+'; echo "${MINOR_VERSION}"; } |\
    sort -h -r |\
    while read -r v; do echo "* [${v}](http://mageddo.github.io/dns-proxy-server/${v})"; done |\
    cat >> $versionsFile

    TARGET="${P}/docs/${MINOR_VERSION}"
    generateDocs ${MINOR_VERSION} ${TARGET}

    LATEST_VERSION=latest
    TARGET_LATEST="${P}/docs/${LATEST_VERSION}"
    generateDocs ${LATEST_VERSION} ${TARGET_LATEST}

    echo "> Preparing new files ..."
    git checkout -f gh-pages
    rsync -t --info=ALL4 --recursive ${P}/docs/ ./
    git status

    echo "> Uploading ..."
    git add ${LATEST_VERSION} ${MINOR_VERSION}
    git commit -m "${MINOR_VERSION} docs"
    git push origin gh-pages
  ;;

esac
