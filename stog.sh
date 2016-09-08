#/bin/bash

#Нужны админские права для изменения настроек гита
git config --system core.longpaths true
GIT_USER_NAME=$(git config --global user.name)
GIT_USER_EMAIL=$(git config --global user.email)
git config --global user.name "bot"
git config --global user.email bot@sib-soft.ru

SVN_PATH=c:/SVN/
GIT_PATH=c:/sib-soft/hcs-sibir/

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



cd $SVN_PATH
SVN_PATH=$(pwd)
cd $GIT_PATH
GIT_PATH=$(pwd)
cd $CUR_PATH


SVN_PATH=$((echo $SVN_PATH|grep -iP '/$') || echo $SVN_PATH/)
GIT_PATH=$((echo $GIT_PATH|grep -iP '/$') || echo $GIT_PATH/)




#Ветка git в которой выполняется поиск
cd $GIT_PATH
GIT_BRANCH=$(git branch|grep -oiP '(?<=^\*\s)\S+$' -m1)
echo $GIT_BRANCH
cd $CUR_PATH


#Временная ветка для проливки патчей из SVN
TMP_BRANCH_GIT="FROM_SVN"

#Путь к файлу с игнорами
DIFF_IGNORE=$CUR_PATH'ignore'

cd $SVN_PATH
#svn cleanup --remove-unversioned
SVN_BRANCH=$(basename $(svn info --show-item url))
SVN_BRANCH=$(echo "${SVN_BRANCH^^}")
SVN_REV=$(svn info --show-item last-changed-revision)
echo $SVN_REV
cd $CUR_PATH




#Если каталог не существует, то выйдем с ошибкой
if [ ! -d "$GIT_PATH" ]; then
echo "Каталог к репозиторию указан не верно"
#if [ -n $(echo "$GIT_PATH"| grep -oiP '\/[^\/]*') ]; then
#mkdir $GIT_PATH
#fi
exit 1
else
cd $GIT_PATH
if [ ! -d "$(pwd)/.git" ]; then
echo "Каталог не под контролем GIT"
cd $CUR_PATH
exit 1
fi
fi

#Стянем изменения в локальную ветку
#git fetch

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

#echo $LAST_REVISION_COMMIT
echo $HASH_LAST_REVISION
echo $LAST_REVISION


rm -f $DIFF_IGNORE

echo $DIFF_IGNORE


(echo "gradle" && echo "out" && echo ".idea" && echo ".gradle" && echo ".svn" && echo ".git") > $DIFF_IGNORE
cat $GIT_PATH'.gitignore' >> $DIFF_IGNORE


cd $SVN_PATH
svn propget svn:ignore >> $DIFF_IGNORE
#svn cleanup --remove-unversioned
#svn status|grep -iP '^[\?|\!]'
cd $CUR_PATH


cd $GIT_PATH

#Очистка каталога с репозиторием git
git clean -d -x -f
git pull --rebase origin $GIT_BRANCH
git diff --diff-filter=ACMRTUXB $GIT_BRANCH $HASH_LAST_REVISION > $CUR_PATHgit_$GIT_BRANCH2svn_$SVN_BRANCH.patch


#Если промежуточная ветка установлена, то грохнем её
[[ -n $(git branch --list $TMP_BRANCH_GIT) ]] && git checkout -f $GIT_BRANCH && git branch -D $TMP_BRANCH_GIT

#diff -arwEBNdu --exclude-from=$DIFF_IGNORE $SVN_PATH $GIT_PATH > $CUR_PATHgit_$GIT_BRANCH2svn_$SVN_BRANCH.patch

#Получить локальную ветку промежуточную ветку выписав её на основе удаленной
git checkout -b $TMP_BRANCH_GIT origin/$GIT_BRANCH

#Удалим аккумулятивный мессадж для патча
rm -f $CUR_PATHsvn_$SVN_BRANCH2git_$GIT_BRANCH.msg

#svn log -r $LAST_REVISION:HEAD $SVN_PATH
# --search s.molokovskikh --search-and 2016-08-* | grep -aoP '^r\K[^\s]*(?=\s)' | xargs -I REV sh -c 'svn diff -r $(expr REV - 1):REV > $(basename $(svn info --show-item url)).patch & (svn log -r REV)'
START_REVISION=$(svn log -r$(expr $LAST_REVISION + 1):$(expr $LAST_REVISION + 100) $SVN_PATH | grep -aoP '^r\K[^\s]*(?=\s)' -m1)
echo $START_REVISION
svn log -r $START_REVISION:HEAD $SVN_PATH | grep -aoP '^r\K[^\s]*(?=\s)' | xargs -I REV sh -c '(svn diff --git -r $(expr REV - 1):REV '$SVN_PATH' | git apply --index --ignore-whitespace --reject) && ((svn log -r REV '$SVN_PATH'|sed -n 3,10p| iconv -f WINDOWS-1251 -t UTF-8 |sed -E ":a; N; $!ba; s/\-+\n//g; s/^\s*$/\n/g; s/\n+/\n/g" | sed -E "s/\-{10,}//g;" && echo -e "\n'SVN_$SVN_BRANCH'_REV" ) > '$CUR_PATH$SVN_BRANCH'_REV.msg) && ( svn log -r REV '$SVN_PATH' | iconv -f WINDOWS-1251 -t UTF-8 | grep -aP "^r\d{4,}" -m1 | grep -oP "(?<=\|)\s+[^\|]*\s+(?=\|)"|tail -n1|grep -oP "\d{4}\-\d{2}\-\d{2}\s+\d{2}\:\d{2}\:\d{2}" > '$CUR_PATH$SVN_BRANCH'_REV.date ) && (svn log -r REV '$SVN_PATH'|grep -aP "^r\d{4,}" -m1 | grep -oP "(?<=\|)\s+[^\|]*\s+(?=\|)" -m1 | sed -E "s/\s*//g" | head -n1 > '$CUR_PATH$SVN_BRANCH'_REV.author ) && git commit -a -F '$CUR_PATH$SVN_BRANCH'_REV.msg --date="$(cat '$CUR_PATH$SVN_BRANCH'_REV.date)"  --author="$(cat '$CUR_PATH$SVN_BRANCH'_REV.author) <$(cat '$CUR_PATH$SVN_BRANCH'_REV.author)@fake.com>" && cat '$CUR_PATH$SVN_BRANCH'_REV.msg >> '$CUR_PATH'svn_'$SVN_BRANCH'2git_'$GIT_BRANCH'.msg && rm -f '$CUR_PATH$SVN_BRANCH'_REV.msg && rm -f '$CUR_PATH$SVN_BRANCH'_REV.date && rm -f '$CUR_PATH$SVN_BRANCH'_REV.author'

git status

#Сборка бекенда
[[ -f gradlew ]] && chmod +x gradlew && ./gradlew
#Результат сборки 0 - ошибок нет , 1 - сборка упала
BUILD_STATUS=$?
echo $BUILD_STATUS

#Создадим один аккумулятивный дельта-патч
[[ $BUILD_STATUS = 0 ]] && git diff --diff-filter=ACMRTUXB $GIT_BRANCH $TMP_BRANCH_GIT > $CUR_PATHsvn_$SVN_BRANCH2git_$GIT_BRANCH.patch

#Удалим двойные переносы из файла коммита
sed -i -E ":a; N; $!ba; s/\-+\n//g; s/^\s*$/\n/g; s/\n+/\n/g" $CUR_PATHsvn_$SVN_BRANCH2git_$GIT_BRANCH.msg

#Удалим локальный тестовый бранч
git checkout -f $GIT_BRANCH && git branch -D $TMP_BRANCH_GIT

#Если сборка успешна выполним всё тоже самое для целевой ветки
[[ $BUILD_STATUS = 0 ]] && echo 'Do It For '$GIT_BRANCH # && git push origin $GIT_BRANCH:$GIT_BRANCH

cd $CUR_PATH

#Восстановим настройки гита
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

