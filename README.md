Add following to .bashrc or .zshrc
```
. $HOME/.rerun_workspace/main.sh
```

Optional and recommended to add (requires zioxide and fzf)
```
rr_workspace_fzf()
{
	directory=""
	if [ $# -eq 0 ]; then
		directory="$(zoxide query -i)"
		if [ $? -gt 0 ]; then
			return
		fi
	elif [ -d $1 ]; then
		directory=$1
	fi
	if [ "$directory" != "" ]; then
		cd $directory
		rr_workspace_main
		jb_print_todo
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
