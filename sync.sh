#!/usr/bin/env bash
cd `dirname $0` && DIR=$(pwd) && cd -
. ${DIR}/config.sh
APP_WORKDIR="$DIR/git-application"
SOURCE_WORKDIR="$DIR/git-source"

echo "Git uri ${APP_GIT_URI}"

if [[ ! -d ${APP_WORKDIR}/.git ]]; then
  mkdir -p ${APP_WORKDIR}/.git
  git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git init
  git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git remote add origin "${APP_GIT_URI}"
fi

if [[ ! -d ${SOURCE_WORKDIR}/.git ]]; then
  mkdir -p ${SOURCE_WORKDIR}/.git
  git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git init
  git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git remote add origin "${SOURCE_GIT_URI}"
fi

git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git fetch --all
git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git fetch --tags
git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git pull origin master
git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git fetch --all
git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git fetch --tags
git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git pull origin master

while read tag;
do
  echo "PROCESS TAG: $tag"
  if [[ ! -z ${START_FROM_TAG} ]] && [[ `php -r "echo version_compare('${tag}', '${START_FROM_TAG}');"` -lt 0 ]]; then
    echo "Skipping... (${tag} < ${START_FROM_TAG})"
  else
    sed -i -e 's/GIT_URI=.*/GIT_URI="'$(echo ${SOURCE_WORKDIR} | sed -e 's/[\.\:\/&]/\\&/g')'"/' ${APP_WORKDIR}/Dockerfile
    sed -i -e 's/GIT_REF=.*/GIT_REF="tags\/'$(echo ${tag} | sed -e 's/[\.\:\/&]/\\&/g')'"/' ${APP_WORKDIR}/Dockerfile
    git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git add -f ${APP_WORKDIR}/Dockerfile
    git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git commit -m "bump $tag"
    git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git tag -a "$tag" -m "bump $tag"
  fi
done < <(diff -a <(git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git show-ref --tags | awk '{print $2}') <(git --work-tree=${SOURCE_WORKDIR} --git-dir=${SOURCE_WORKDIR}/.git ls-remote --tags | grep -v '\^{}' | awk '{print $2}') | grep '>' | awk -F '/' '{print $3}')

git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git push --all origin
git --work-tree=${APP_WORKDIR} --git-dir=${APP_WORKDIR}/.git push --tags origin
