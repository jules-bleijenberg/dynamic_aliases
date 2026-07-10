<h1>Bare bones</h1>
Add following to .bashrc or .zshrc
```
. $HOME/.rerun_workspace/main.sh
```

If you choose a different directory than $HOME/.dynamic_aliases add the following code
```
RR_WORKSPACE_DIR=$HOME/wherever/I/am/now
```

<h1>Supercharged</h1>
Optional and recommended to add to .bashrc or .zshrc (requires zioxide and fzf)
```
rr_workspace_fzf()
{
	changed_directory=1
	if [ $# -eq 0 ]; then
		directory="$(zoxide query -i)"
		if [ $? -gt 0 ]; then
			return
		fi
		cd $directory
		changed_directory=0
	elif [ -d $1 ]; then
		cd $1
		changed_directory=0
	elif [ ${1:0:1} != '-' ]; then
		z $1
		if [ $? -gt 0 ]; then
			return
		fi
		changed_directory=0
	fi
	if [ $changed_directory ]; then
		rr_workspace_main
	elif [ "$1" == "-a" -a $# -eq 1 ]; then
		rr_add_alias_from_history
	else
		rr_workspace_main $@
	fi
}

rr_add_alias_from_history()
{
	selected_command=$(fc -rln -50 | cut -d " " -f 2- | fzf)
	if [ $? -gt 0 ]; then
		return
	fi
	printf "%s\n" "Selected Command: \"$selected_command\""
	read -e -N 1 -p 'Alias>' user_input
	if [ $? -gt 0 ]; then
		return
	fi
	rr_workspace_main -a "$user_input $selected_command"
}

alias r='rr_workspace_fzf'
```
