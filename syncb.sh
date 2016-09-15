#/bin/bash


#Нужны админские права для изменения настроек гита
git config --system core.longpaths true
GIT_USER_NAME=$(git config --global user.name)
GIT_USER_EMAIL=$(git config --global user.email)
git config --global user.name "bot"
git config --global user.email bot@sib-soft.ru

SVN_PATH=d:/repos/svn/trunk/
GIT_PATH=d:/repos/git/

#Разбираем переданные аргументы скрипта в  переменные

if [ $# -gt 0 ]; then
SVN_PATH=$1
fi

if [ $# -gt 1 ]; then
GIT_PATH=$2
fi


#Текущий каталог
CUR_PATH=$(pwd)
CUR_PATH=$((echo $CUR_PATH|grep -iP '/$') || echo $CUR_PATH/)

PREFIX_GIT_BRANCH="DEV_"

cd $SVN_PATH
SVN_PATH=$(pwd)
cd $GIT_PATH
GIT_PATH=$(pwd)
cd $CUR_PATH


SVN_PATH=$((echo $SVN_PATH|grep -iP '/$') || echo $SVN_PATH/)
GIT_PATH=$((echo $GIT_PATH|grep -iP '/$') || echo $GIT_PATH/)




#Проверка каталогов

if [ ! -d "$SVN_PATH" ]; then
echo "Каталог к репозиторию SVN указан не верно"
exit 1
else

cd $SVN_PATH

svn info
if [ $? = "0" ]; then
SVN_URL=$(svn info | grep -ioP '(?<=^repository root:).*$' | sed 's/\s*//g')
SVN_URL=$((echo $SVN_URL|grep -iP '/$') || echo $SVN_URL/)
else
echo 'Каталог "'$SVN_PATH'" не под контролем SVN'
cd $CUR_PATH
exit 1
fi

fi


if [ ! -d "$GIT_PATH" ]; then
echo "Каталог к репозиторию GIT указан не верно"
exit 1
else
cd $GIT_PATH
git status
if [ $? != "0" ]; then
echo 'Каталог "'$GIT_PATH'" не под контролем GIT'
cd $CUR_PATH
exit 1
fi

fi


cd $GIT_PATH

for SVN_BRANCH in $(svn ls $SVN_URL'branches' | grep -ioP '^(\d+\.*)+(?=\/$)')
do

#Ветка в гите
GIT_BRANCH=$PREFIX_GIT_BRANCH$SVN_BRANCH

#Если такой ветки нет то нужно её создать
if [ -z $(git branch -r | grep -iP '^\s*origin\/'$GIT_BRANCH'$' -m1) ]; then
#Выясним ревизию и ветку от которой был бранч в SVN
SVN_FORK_REV=$(svn log --stop-on-copy $SVN_URL'branches/'$SVN_BRANCH | tail -n20 | grep -aioP '(?<=^r)\d*' | tail -n1)
SVN_FORK_BRANCH=$(svn propget svn:mergeinfo $SVN_URL'branches/'$SVN_BRANCH | grep -iP $SVN_FORK_REV | grep -ioP '(?<=\/)[^\:]*' )

echo $GIT_BRANCH' - '$SVN_FORK_REV
echo $SVN_FORK_BRANCH

else

#Если ветка в гите создана, то нужно найти коммит с ревизией

#Последняя ревизия
LAST_REVISION_COMMIT=$(git log --pretty=oneline --date-order --grep="SVN_$SVN_BRANCH_\d+" --perl-regexp -i -n1)

#Если ревизия не получена используем старый шаблон
if [ -z "$LAST_REVISION_COMMIT"  ]; then
	LAST_REVISION_COMMIT=$(git log --pretty=oneline --date-order --grep="(?<=SVN)[\s\S]*revision[\#\:\s]*" -i -n1 --perl-regexp origin/$GIT_BRANCH)
fi

#Если ревизия не получена используем старый шаблон 2
if [ -z "$LAST_REVISION_COMMIT"  ]; then
	LAST_REVISION_COMMIT=$(git log --pretty=oneline --date-order --grep="revision[\#\:]\s*\d{4,}" -i --perl-regexp  -n1 origin/$GIT_BRANCH)
fi


#Хеш коммита с ревизией
HASH_LAST_REVISION=$(echo $LAST_REVISION_COMMIT|grep -oiP '^[0-9,a-f]+(?=[\s\_])')
#Сообщение с номером с ревизии
MSG_LAST_REVISION=$(echo $LAST_REVISION_COMMIT|grep -oiP '(?<=[\s\_]).*')

#MSG_LAST_REVISION='43456 gdhgdg 678543'
#Номер с ревизией
LAST_REVISION=$(echo $MSG_LAST_REVISION|sed -e 's/[^0-9]/ /g'|grep -oiP '\d+'|tail -n1)

echo $GIT_BRANCH
#echo $LAST_REVISION_COMMIT
echo $HASH_LAST_REVISION
echo $LAST_REVISION


fi

done


#Ветка git в которой выполняется поиск
#cd $GIT_PATH
#GIT_BRANCH=$(git branch|grep -oiP '(?<=^\*\s)\S+$' -m1)
#echo $GIT_BRANCH
#cd $CUR_PATH

cd $CUR_PATH

#Восстановим настройки гита
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

