#/bin/bash


SVN_PATH=c:/repos/svn/trunk/
GIT_PATH=c:/repos/git/


#Разбираем переданные аргументы скрипта в  переменные

if [ $# -gt 0 ]; then
SVN_PATH=$1
fi

if [ $# -gt 1 ]; then
GIT_PATH=$2
fi

if [ $# -gt 2 ]; then
PATCH_FILE=$3
fi

#Текущий каталог
CUR_PATH=$(pwd)
CUR_PATH=$((echo $CUR_PATH|grep -iP '/$') || echo $CUR_PATH/)


cd $SVN_PATH
SVN_PATH=$(pwd)
cd $GIT_PATH
GIT_PATH=$(pwd)
cd $CUR_PATH


SVN_PATH=$((echo $SVN_PATH|grep -iP '/$') || echo $SVN_PATH/)
GIT_PATH=$((echo $GIT_PATH|grep -iP '/$') || echo $GIT_PATH/)


echo $SVN_PATH
echo $GIT_PATH

#Путь к файлу с игнорами
DIFF_IGNORE=$CUR_PATH'ignore'


#Проверка каталогов

#if [ ! -d "$SVN_PATH" ]; then
#echo "Каталог к репозиторию SVN указан не верно"
#exit 1
#else

#cd $SVN_PATH
#svn info --show-item url
#if [ $? = "0" ]; then
#SVN_BRANCH=$(basename $(svn info --show-item url))
#SVN_BRANCH=$(echo "${SVN_BRANCH^^}")
#SVN_REV=$(svn info --show-item last-changed-revision)
#else
#echo 'Каталог "'$SVN_PATH'" не под контролем SVN'
#cd $CUR_PATH
#exit 1
#fi

#fi


#if [ ! -d "$GIT_PATH" ]; then
#echo "Каталог к репозиторию GIT указан не верно"
#exit 1
#else
#cd $GIT_PATH
#git status
#if [ $? = "0" ]; then
#echo 'Каталог "'$GIT_PATH'" не под контролем GIT'
#cd $CUR_PATH
#exit 1
#fi

#fi

SVN_BRANCH="TRUNK"
SVN_REV="111499"

cd $CUR_PATH


if [ -z "$PATCH_FILE" ]; then
PATCH_FILE=$CUR_PATH"git_"$GIT_BRANCH"2svn_"$SVN_BRANCH".patch"
fi


GIT_BRANCH="DEV"

#Ветка git в которой выполняется поиск
#cd $GIT_PATH
#GIT_BRANCH=$(git branch|grep -oiP '(?<=^\*\s)\S+$' -m1)
#cd $CUR_PATH


echo $SVN_BRANCH
echo $SVN_REV
echo $GIT_BRANCH


rm -f $DIFF_IGNORE


SUBSYSTEMS="dtko tech-state indices"
WEBSUBSYSTEMS="dtko tech-state tariff rate-consumtion information-discovery"
RESTSUBSYSTEMS="dtko tech-state rate-consumption tariff"


for subsystem in $SUBSYSTEMS
do
TEMPLATE_FIND=$TEMPLATE_FIND$([[ -n $TEMPLATE_FIND ]] && echo " -or ")" -iregex '.*\/service\-.*\/.*"$(echo $subsystem|sed 's/\-/\\\-/g')"\-service.*'"
done

for subsystem in $WEBSUBSYSTEMS
do
TEMPLATE_FIND=$TEMPLATE_FIND$([[ -n $TEMPLATE_FIND ]] && echo " -or ")" -iregex '.*\/web/web\-packages\/.*"$(echo $subsystem|sed 's/\-/\\\-/g')".*'"
done

for subsystem in $RESTSUBSYSTEMS
do
TEMPLATE_FIND=$TEMPLATE_FIND$([[ -n $TEMPLATE_FIND ]] && echo " -or ")" -iregex '.*\/web\/rest\/.*"$(echo $subsystem|sed 's/\-/\\\-/g')".*'"
done


eval "find "$GIT_PATH" -type f -not \( "$TEMPLATE_FIND" \)"
eval "find "$SVN_PATH" -type f -not \( "$TEMPLATE_FIND" \)"

eval "find "$GIT_PATH" -type f -not \( "$TEMPLATE_FIND" \)" | sed s/$(echo $GIT_PATH|sed 's/\//\\\//g')//g  | xargs -I F echo "F"  >> $DIFF_IGNORE
eval "find "$SVN_PATH" -type f -not \( "$TEMPLATE_FIND" \)" | sed s/$(echo $SVN_PATH|sed 's/\//\\\//g')//g  | xargs -I F echo "F"  >> $DIFF_IGNORE
#eval "find "$GIT_PATH" -type f -not \( "$TEMPLATE_FIND" \)" >> $DIFF_IGNORE
#eval "find "$SVN_PATH" -type f -not \( "$TEMPLATE_FIND" \)" >> $DIFF_IGNORE

#exit 0

#cd $SVN_PATH
#svn cleanup --remove-unversioned
#svn status|grep -iP '^[\?|\!]'
#cd $CUR_PATH


#cd $GIT_PATH
#Очистка каталога с репозиторием git
#git clean -d -x -f
#cd $CUR_PATH


diff -arwEBNdu --ignore-file-name-case --exclude-from=$DIFF_IGNORE $GIT_PATH $SVN_PATH > $PATCH_FILE
