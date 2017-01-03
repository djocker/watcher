#!/usr/bin/env bash
cd `dirname $0` && DIR=$(pwd) && cd -
. ${DIR}/config.sh
WORKDIR="$DIR/application-git"


if [[ ! -d ${DIR}/.git ]]; then
    git --git-dir=${DIR}/.git init
    git --git-dir=${DIR}/.git add .
    git --git-dir=${DIR}/.git commit -m "initial"
fi

if [[ ! -d ${WORKDIR} ]] || [[ ! -d ${WORKDIR}/.git ]]; then
    mkdir -p ${WORKDIR}/.git
    git --git-dir=${WORKDIR}/.git init
    git --git-dir=${WORKDIR}/.git remote add origin "${APP_GIT_URI}"
fi

git --git-dir=${WORKDIR}/.git pull origin master


while read tag;
do
    echo "PROCESS TAG: $tag"
    if [[ ! -z ${START_FROM_TAG} ]] && [[ `php -r "echo version_compare('${tag}', '${START_FROM_TAG}');"` -lt 0 ]]; then
        echo "Skipping..."
    else
        sed -i -e 's/GIT_URI=.*/GIT_REF=tags\/'${APP_GIT_URI}'/' Dockerfile
        sed -i -e 's/GIT_REF=.*/GIT_REF=tags\/'${tag}'/' Dockerfile
        git --git-dir=${DIR}/.git add -f Dockerfile
        git --git-dir=${DIR}/.git commit -m "bump $tag"
        git --git-dir=${DIR}/.git tag -a "$tag" -m "bump $tag"
    fi
done < <(diff -a <(git --git-dir=${DIR}/.git show-ref --tags | awk '{print $2}') <(git --git-dir=${WORKDIR}/.git ls-remote --tags | grep -v '\^{}' | awk '{print $2}') | grep '>' | awk -F '/' '{print $3}')

# For auto push uncomment line below
git --git-dir=${DIR}/.git push --all origin
git --git-dir=${DIR}/.git push --tags origin
