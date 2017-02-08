RED='\033[0;31m'
YELLOW='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' 
bluehive="@bluehive.circ.rochester.edu"

echo "Please type your ${RED}NetID${NC}(____$bluehive). Press enter to continue."
read netid
tail -n 108 run_at_local.sh > ~/tmp_file
cat ~/tmp_file | ssh $netid$bluehive 'cat > setup.sh;chmod 700 setup.sh'
rm -f ~/tmp_file
echo "Now this script will bring you to bluehive. You need run ${RED}'./setup.sh'${NC} to continue the setup."
ssh $netid$bluehive
exit

# script to bluehive
RED='\033[0;31m'
YELLOW='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
backup="@huo-backup.chem.rochester.edu"
bksh="backup.sh"
git_cmd='git add .\ngit commit -m "backup $(date)"\ngit push origin master:master'
echo -e "Please type your username on the backup machine. (${RED}YOUR FIRST NAME${NC})"
read username
domain=$username$backup
file=~/.ssh/id_rsa.pub
if [[ ! -f $file ]]
then
    echo -e "Public key does not exist. Going to generate a new key.\n ${RED}Note:${CYAN} if you do not want to use any password, just press enter, enter and enter${NC}"
    ssh-keygen -t rsa	
fi
echo -e "Copy public key to your backup account. ${YELLOW}Password required.${NC}\nDefault password is ${RED}'+12345'${NC}. If you forget your password, please contact me."
cat ~/.ssh/id_rsa.pub | ssh $domain 'umask 0077; mkdir -p .ssh; key=$(cat);if [[ -z $(grep "$key" .ssh/authorized_keys) ]];then echo "$key" >> .ssh/authorized_keys;echo "key copied";else echo "already exists";fi'
echo 'This script will convert the folder you want to backup to a Git repository and bring you to the backup system for the next step.'
echo '#!/bin/sh' > ~/tmp_file
cwd=$(pwd)
switch=1
i=0
while [[ $switch == 1 ]]
do
    switch=$(($switch+3))
    ((i++))
    echo -e "${RED}Please type the path of the folder you want to backup. You can use tab completion. Environment variable does not work. Please use real path.${NC}"
    read -e path[$i]
    cd ${path[$i]}
    path[$i]=$(pwd)
    git init
    my_dir=$(pwd)
    echo -e "Do you want to rename the destination folder?\n
${YELLOW}If not, just press enter and it will retain the source directory structure, i.e., $my_dir.\n
${RED}Note:${NC}Different destinations are ${RED}NOT${NC} allowed to have the same path, as data will be pushed into the same folder.\n
${RED}Leaving defualt will be the safest and easiest way to back up your data.${NC}"
    ctrl=1
    while [[ $ctrl == 1 ]]
    do
	echo "Type your desired destination path now. Leave blank for default."
    	read -e dest_name[$i]
    	if [[ -z "${dest_name[$i]}" ]]
    	then
    	    dest_name[$i]=${path[$i]}
	else
	    for j in `seq 1 $(($i-1))`
	    do 
		if [[ ${dest_name[$i]} == ${dest_name[$j]} ]]
		then
			echo -e "${RED}Warning${NC}: ${RED}${path[$i]}${NC} and ${RED}${path[$j]}${CYAN} have the same destination as ${RED}${dest_name[$i]}. ${CYAN}Please rename current one.${NC}"
			((ctrl--))
			break
		fi
	    done
    	fi
	((ctrl++))
    done
    echo "dest[$i]=${dest_name[$i]}" >> ~/tmp_file
    cd $cwd
    echo -e "Do you want to backup another folder?\n${RED}[1] Yes\n${YELLOW}[2] No, and keep this script\n${CYAN}[3] No, and delete script${NC}"
    while [[ $switch -ne 1 ]] && [[ $switch -ne 2 ]] && [[ $switch -ne 3 ]] 
    do
	read switch
    done
done
echo "itr=$i" >> ~/tmp_file
tail -n 6 setup.sh >> ~/tmp_file
cat ~/tmp_file | ssh $domain 'cat > setup.sh;sh setup.sh;rm -f setup.sh'
rm -f ~/tmp_file

echo -e "Going to create or append your backup.sh under your home folder."
if [[ ! -f $bksh ]]
then
    echo '#!/bin/sh
cwd=$(pwd)
start=`date +%s.%N`
end=`date +%s.%N`
runtime=$( echo "$end - $start" | bc -l )
echo "Nightly Backup Successful: $(date) Total runtime: $runtime" >> mybackup.log' > $bksh
fi

echo -e "#!/bin/bash\n#SBATCH -p action -A action\n#SBATCH -N 1\n#SBATCH --mem=512mb\n#SBATCH -J init_bk\n#SBATCH -t 10:00:00\nmodule load git" > backup.sbatch
for j in `seq 1 $i`
do
    echo -e "cd ${path[$j]}\ngit remote add origin ssh://$domain/~${dest_name[$j]}\n$git_cmd\ncd $cwd" >> backup.sbatch
    sed -i "/end=/i cd ${dest_name[$j]}\n$git_cmd\ncd $cwd" $bksh
done

sbatch backup.sbatch
rm -f backup.sbatch slurm*

echo -e "Now the script is saved as ~/backup.sh. The next step is to open crontab to add or modify your scheduled task."
crontab -e 

if [[ $switch == 3 ]]
then
    rm -f setup.sh
fi
exit

# script to backup
git config --global receive.denyCurrentBranch updateInstead
for i in `seq 1 $itr`
do
    mkdir -p ~/${dest[$i]}
    git init ~/${dest[$i]}
done
