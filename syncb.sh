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

GIT_BRANCH_DEV="DEV"
PREFIX_GIT_BRANCH=$GIT_BRANCH_DEV"_"

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

#Проверим наличие ветки DEV в гите
if [ -z "$(git branch|grep -ioP '$GIT_BRANCH_DEV$')" ]; then
 GIT_BRANCH_CURRENT=$(git branch|grep -oiP '(?<=^\*\s)\S+$' -m1)
 
 #Первый комит в репозитории
 #git checkout -b DEV $(git rev-list --max-parents=0 HEAD)
 git checkout -f master && git pull --rebase
 
 #Перенесем историю для ветки DEV
 cd $CUR_PATH
 ./stog.sh $SVN_PATH $GIT_PATH
 cd $GIT_PATH
 #Вернемся к предыдущей ветке
 git checkout -f $GIT_BRANCH_CURRENT
fi

ALL_SVN_BRANCHES=$(svn ls $SVN_URL'branches'|tr "\n" "^"| sed ':a;N;$!ba;s/\r//g')


for SVN_BRANCH in $(echo $ALL_SVN_BRANCHES| tr "^" "\n" | grep -ioP '^(\d+\.*)+(?=\/$)' )
do

#Ветка в гите
GIT_BRANCH=$PREFIX_GIT_BRANCH$SVN_BRANCH

#Если такой ветки нет то нужно её создать
if [ -z $(git branch -r | grep -iP '^\s*origin\/'$GIT_BRANCH'$' -m1) ]; then
#Выясним ревизию и ветку от которой был бранч в SVN
SVN_FORK_REV=$(svn log --stop-on-copy $SVN_URL'branches/'$SVN_BRANCH | tail -n50 | grep -aioP '(?<=^r)\d*' | tail -n1)
#SVN_FORK_BRANCH=$(svn propget svn:mergeinfo $SVN_URL'branches/'$SVN_BRANCH | grep -iP $(expr $SVN_FORK_REV + 1) | grep -ioP '(?<=\/)[^\:]*' )

for TEST_SVN in $(echo $ALL_SVN_BRANCHES | tr "^" "\n" | tr " " "~"| sed 's/\/$//g' | xargs -I STR echo "branches/STR" && echo "trunk")
do

if [ $TEST_SVN == "trunk" ]; then
SVN_FORK_BRANCH=$TEST_SVN
break 1
fi

#echo "svn log --stop-on-copy $SVN_URL"$(echo $TEST_SVN|sed "s/\~/\%20/g; s/(/\\(/g; s/)/\\)/g")" | grep -ioP '^r$(expr $SVN_FORK_REV - 1)'"

TEST_SVN_NUM=$(echo $TEST_SVN|grep -oiP '(^\d+\.*)+.*'|grep -oiP '^\d+')
SVN_BRANCH_NUM=$(echo $SVN_BRANCH|grep -oiP '^\d+')

if [ -z $TEST_SVN_NUM ] || (( $TEST_SVN_NUM > $SVN_BRANCH_NUM )); then
continue 1
fi

echo "TEST_SVN_NUM="$TEST_SVN_NUM" SVN_BRANCH_NUM="$SVN_BRANCH_NUM

if [ "$(echo $TEST_SVN|grep -oiP '(\d+\.*)+.*')" != "$SVN_BRANCH" ] && [ -n "$(svn log --stop-on-copy $SVN_URL$(echo $TEST_SVN|sed "s/\~/\%20/g; s/(/\\(/g; s/)/\\)/g") | grep -ioP '^r$(expr $SVN_FORK_REV - 1)')" ]; then
echo 'Ветка '$SVN_BRANCH' была выписана от ветки '$TEST_SVN' в ревизии '$SVN_FORK_REV
SVN_FORK_BRANCH=$(echo $TEST_SVN|grep -oiP '(trunk)|((?<=branches/).*)')
break 1
fi

done

#svn propget svn:mergeinfo https://vcs.lanit.ru/svn/hcs/branches/7.4.0 | xargs -I STR sh -c 'echo "STR"|grep -ioP "(?<=\:).*"| tr "," "\n" | xargs -I REV sh -c '\''( ([[ -n $(echo "REV"|grep -ioP '\-') ]] && (( ( $(echo "REV"|grep -oiP "\d+(?=\-)") == 82069  || $(echo "REV"|grep -oiP "\d+(?=\-)") < 82069 ) && ( $(echo "REV"|grep -oiP "(?<=\-)\d+") == 82069  || $(echo "REV"|grep -oiP "(?<=\-)\d+") > 82069 ) )) ) || (( REV > 82069 || REV == 82069 )) ) && echo -e "$(echo "STR" | grep -oiP "(?<=\/)[^\:]*"):REV\n***\n" && exit 1 '\'''
#TODO 
#[[ -n $(echo "REV"|grep -ioP '\-') ]] && echo REV 
# сделать разбор диапазона REV1-REV25, е если искомая ревизия в этом диапазоне то вывести ветку и REV для контрольки

if [ $SVN_FORK_BRANCH == "trunk" ]; then
	SVN_FORK_BRANCH="DEV"
fi

echo $GIT_BRANCH' - '$SVN_FORK_REV
echo $SVN_FORK_BRANCH



#Ревизия в ветки от которой было ветвление
REVISION_COMMIT=$(git log --pretty=oneline --date-order --grep="SVN_$SVN_FORK_BRANCH_\d+" --perl-regexp -i -n1)
#Хеш коммита с ревизией
HASH_REVISION=$(echo $REVISION_COMMIT|grep -oiP '^[0-9,a-f]+(?=[\s\_])')
GIT_BRANCH_CURRENT=$(git branch|grep -oiP '(?<=^\*\s)\S+$' -m1)
#Создадим новую ветку
git checkout -b $GIT_BRANCH $HASH_REVISION

#Перенесем историю
cd $CUR_PATH
./stog.sh $SVN_PATH $GIT_PATH
cd $GIT_PATH

#Отправим новую ветку в репозиторий
#git push origin $GIT_BRANCH:$GIT_BRANCH
#Вернемся к предыдущей ветке
git checkout -f $GIT_BRANCH_CURRENT

else


#Если ветка в гите создана, то нужно перенести историю по ней

cd $GIT_PATH
git checkout $GIT_BRANCH

#Перенесем историю
cd $CUR_PATH
./stog.sh $SVN_PATH $GIT_PATH
cd $GIT_PATH

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

