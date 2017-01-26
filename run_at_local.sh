# grab user id and send script to bluehive

RED='\033[0;31m'
YELLOW='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
bluehive="@bluehive.circ.rochester.edu"

echo -e "Please type your ${RED}NetID${NC}(____$bluehive). Press enter to continue."
read netid
echo "domain=$netid$bluehive" > ~/tmp_file
tail -n 101 run_at_local.sh >> ~/tmp_file
cat ~/tmp_file | ssh $netid$bluehive 'cat > setup.sh;chmod 700 setup.sh'
rm -f ~/tmp_file
ssh $netid$bluehive
exit

RED='\033[0;31m'
YELLOW='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
backup="@huo-backup.chem.rochester.edu"
git_str="git clone ssh://"
echo 'This script will convert the folder you want to backup to a Git repository and bring you to the backup system for the next step.'
echo '#!/bin/sh' > ~/tmp_file
echo "domain=$domain" >> ~/tmp_file
tail -n 45 | head -n 13 >> ~/tmp_file
cwd=$(pwd)
switch=1
i=0
while [[ $switch -eq 1 ]]
do
    switch=$(($switch+3))
    ((i++))
    echo -e "${RED}Please type the path of the folder you want to backup. You can use tab completion.${NC}"
    read -e path[$i]
    cd ${path[$i]}
    git init
    git add .
    git commit -m "backup $(date)"
    my_dir=$(pwd)
    echo -e "Do you want to rename the destination folder? ${YELLOW}If not, just press enter and it will have the same name as source.\n
${RED}Note:${CYAN}If different sources have the same names, you ${RED}MUST${CYAN} give a different name for ${RED}EACH${CYAN} one!\n
For example, if you backup the whole scratch and home, they both have a name of your netid.${NC}"
    read dest_name
    if [[ -z "$dest_name" ]]
    then
	dest_name=$(echo ${my_dir##*/})
    fi
    echo "$git_str$domain:$my_dir $dest_name" >> ~/tmp_file
    echo "source[$i]=$my_dir\ndest[$i]=$dest_name" >> ~/tmp_file
    cd $cwd
    echo -e "Do you want to backup another folder?\n${RED}[1] Yes\n${YELLOW}[2] No, and keep this script\n${CYAN}[3] No, and delete script${NC}"
    while [[ $switch -ne 1 ]] && [[ $switch -ne 2 ]] && [[ $switch -ne 3 ]] 
    do
	read switch
    done
done
echo "itr=$i" >> ~/tmp_file
tail -n 31 >> ~/tmp_file
echo -e "Please type your username on the backup machine. (${RED}YOUR FIRST NAME)${NC}"
read username
cat ~/tmp_file | ssh $username$backup 'cat > setup.sh; chmod 700 setup.sh'
rm -f ~/tmp_file
if [[ $switch -eq 3 ]]
then
    rm -f setup.sh
fi
echo -e "Logging in to your ${RED}backup${NC} account. Default password is ${RED}'+12345'${NC}. If you forget your password, please contact me."
ssh $username$backup
exit

RED='\033[0;31m'
YELLOW='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
$file=~/.ssh/id_rsa.pub
if [[ ! -f $file ]]
then
    echo -e "Public key does not exist. Going to generate a new key.\n ${RED}Note:${CYAN} if you do not want to use any password, just press enter, enter and enter${NC}"
    ssh-keygen -t rsa	
fi
echo -e "Copy public key to your bluehive. ${YELLOW}Password required${NC}"
cat ~/.ssh/id_rsa.pub | ssh $domain 'umask 0077; mkdir -p .ssh; cat >> .ssh/authorized_keys && echo "Key copied"'

bk_script=backup.sh
git_cmd="git pull origin master"
cwd=$(pwd)
ssh_cmd="ssh $domain '"
if [[ -f $bk_script ]]
then
    i=1
    while [[ $i -le $itr ]]
    do
	sed -i "/end=/i cd ${dest[$i]}\n$git_cmd\ncd $cwd" $bk_script
	ssh_cmd="$ssh_cmd cd $source[$i];git add .;git commit -m 'backup $(date)'"
    done
    sed -i "s/.*ssh.*/$ssh_cmd'" $bk_script
else
    echo '#!/bin/sh
cwd=$(pwd)
start=`date +%s.%N`
ssh' > $bk_script
    i=1
    while [[ $i -le $itr ]]
    do
	echo "cd ${dest[$i]}\n$git_cmd\ncd $cwd" >> $bk_script
	ssh_cmd="$ssh_cmd cd $source[$i];git add .;git commit -m 'backup $(date)'"
    done
    sed -i "s/.*ssh.*/$ssh_cmd'" $bk_script
    echo 'end=`date +%s.%N`
runtime=$( echo "$end - $start" | bc -l )
echo "Nightly Backup Successful: $(date) Total runtime: $runtime" >> mybackup.log' >> $bk_script
fi
echo -e "Now the script is saved as ~/backup.sh. The next step is to open crontab to add your scheduled task."
crontab -e 
