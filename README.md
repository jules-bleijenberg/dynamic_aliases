<h1>Git clone</h1>

```
git clone https://github.com/jules-bleijenberg/dynamic_aliases.git "$HOME/.dynamic_aliases"
```

<h1>Bare bones</h1>
Add following to .bashrc or .zshrc

```
source $HOME/.dynamic_aliases/main.sh
```

If you choose a different directory than $HOME/.dynamic_aliases add the following code

```
RR_WORKSPACE_DIR=$HOME/wherever/I/am/now
```

<h1>Supercharged</h1>
<strong>requires zioxide and fzf</strong><br>
Optional and higly recommended. Create a file called supercharged.sh. Add the contents below and source it in .bashrc or .zshrc (like done above with main.sh)

```
rr_workspace_fzf()
{
	load_aliases=1
	if [ $# -eq 0 ]; then
		directory="$(zoxide query -i)"
		if [ $? -gt 0 ]; then
			return
		fi
		cd $directory
		load_aliases=0
	elif [ -d $1 ]; then
		cd $1
		load_aliases=0
	elif [ ${1:0:1} != '-' ]; then
		z $1
		if [ $? -gt 0 ]; then
			return
		fi
		load_aliases=0
	fi
	if [ $load_aliases ]; then
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
