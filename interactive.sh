#! /usr/bin/bash

# Colors
GREEN='\033[0;92m';
RED='\033[0;91m';
OPT_LEFT_COLOR='\033[0;92m';
OPT_COLOR='\033[0;97m';
NO_COLOR='\033[0;97m';
GRAY='\033[0;92m';

# Print a line :]
print_line () {
	printf "$@\n";
}

# Print header
print_header () {	
	printf "\n${GREEN} --- $@ --- \n${NO_COLOR}\n";
}

# Workspace oriented (one file per folder)
#		A workspace is usefull in a directory in which the same commands are often used
#		A workspace directory contains a .rr_array file with the commands

option_keys=("a" "s" "d" "f" "g" "h" "j" "k" "l")
alias_keys=( "a" "s" "d" "f" "j" "k" "l" )
max_len=0
selected_option="INVALID"
selected_option_key=" "

set_aliases()
{
	# remove aliases of deleted elements
  for (( i = 0; i < max_len; i++ )); do
		alias_key=${alias_keys[$i]}
		remove_alias_key=${alias_keys[$i]}_r
		unalias "$alias_key"
		unalias "$remove_alias_key"
  done
	# get max alias size
	if [[ ${#rr_array[@]} -le ${#alias_keys[@]} ]]; then
		max_len=${#rr_array[@]}
	else
		max_len=${#alias_keys[@]}
	fi
	# set aliases and print them
  for (( i = 0; i < max_len; i++ )); do
		alias_key=${alias_keys[$i]}
		remove_alias_key=${alias_keys[$i]}_r
    print_line "${OPT_LEFT_COLOR}$alias_key) ${NO_COLOR}${rr_array[$i]}";
		alias "$alias_key=${rr_array[$i]}"
		alias "$remove_alias_key=remove_alias $i"
  done
}

load_aliases()
{
	# check if there are commands stored in pwd dir
	if [[ ! -s $PWD/.rr_array ]]
	then
		print_line "${OPT_COLOR}.rr file not found";
		return
	fi
	# load commands into array
  mapfile -t rr_array < <(cat $PWD/.rr_array)
	set_aliases
}

add_alias()
{
	# get last executed command
	last_executed_command=$(fc -ln -2 | head -1 | cut -d " " -f 2-)
	# check if .rr_array file exists in pwd dir
	if [[ -s $PWD/.rr_array ]]
	then
		# append last executed command
		rr_array=("${rr_array[@]}" "${last_executed_command}")
	else
		# create new rr_array
		rr_array=("${last_executed_command}")
	fi
	#	rr_array=("${last_executed_command}" "${rr_array[@]:0:8}")
	# reload aliases
	set_aliases
	save_workspace
}

remove_alias()
{
	# if param is valid array index remove it
	if [[ $1 -lt $max_len && $1 -ge 0 ]]; then
		for i in "${!rr_array[@]}"; do
			if [[ $1 -ne $i ]]; then
				new_rr_array+=( "${rr_array[i]}" )
			fi
		done
		rr_array=("${new_rr_array[@]}")
		unset new_rr_array
		set_aliases
		save_workspace
	fi
}

handle_options()
{
	# print options
	for ((i = 0; i < ${#option_keys[@]} && i < $#; i++));
	do
		j=$((i+1))
		#echo "${option_keys[i]}) ${!j}"
		printf "${GREEN}${option_keys[i]}) ${NO_COLOR}${!j}\n";
	done
	# get user input
	print_header "Your Choice"
	read -n 1 -p ">" user_input
	# handle user input
	selected_option_key=${user_input}
	selected_option="INVALID"
	if [[ "${user_input}" = "q" ]];
	then
		print_line "${GREEN}Terminated successfully${NO_COLOR}"
		selected_option="EXIT"
		return
	fi
	for ((i = 0; i < ${#option_keys[@]} && i < $#; i++));
	do
		j=$((i+1))
		if [[ "${option_keys[i]}" = "${user_input}" ]];
		then
			selected_option=${!j}
			break
		fi
	done
	echo ""
	echo "options handled"
	echo ""
}

run_and_print_command ()
{
	clear;
	print_header "Command"
	print_line "$1"
	print_header "Output"
	eval "$1"
}

recursive_run () {
	print_header "Commands"
	handle_options "${rr_array[@]}"
  case $selected_option in
		"EXIT")
			return
  		;;
		"INVALID")
	    case $selected_option_key in
				w)
					save_workspace
	  			clear
	  			;;
				e)
	        print_line "${GREEN}Adding command${NO_COLOR}"
					read -e -p ">" command_to_execute;
					if [[ -n $command_to_execute ]]; then
							run_and_print_command "${command_to_execute}"
						  history -s "${command_to_execute}"
							rr_array=("${command_to_execute}" "${rr_array[@]:0:8}")
					else
							clear
					fi
					;;
				r)
					swap_commands
					;;
				t)
	  			clear
	  			;;
				c)
					change_workspace
	  			return
					;;
				esac
  		;;
		*)
			run_and_print_command "${selected_option}"
  		;;
	esac
  recursive_run
}

load_workspace()
{
	# check if file exists
  mapfile -t rr_array < <(cat $PWD/.rr_array)
  for i in "${!rr_array[@]}"; do
    display_index=$((i+1))
    print_line "${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rr_array[$i]}${NO_COLOR}";
  done
	recursive_run
}

save_workspace()
{
	# Assumes current directory is workspace
	if [[ ${#rr_array[@]} -gt 0 ]];
	then
		printf "%s\n" "${rr_array[@]}" > .rr_array
	else
		rm .rr_array
	fi
}

change_workspace()
{
	print_header "Select Workspace"
	handle_options "${rr_dir_array[@]}"
	case $selected_option in
		"EXIT")
			return
  		;;
		"INVALID")
	    case $selected_option_key in
				w)
					save_workspace
	  			clear
	  			;;
				e)
	        print_line "${GREEN}Adding command${NO_COLOR}"
					read -e -p ">" command_to_execute;
					if [[ -n $command_to_execute ]]; then
							run_and_print_command "${command_to_execute}"
						  history -s "${command_to_execute}"
							rr_array=("${command_to_execute}" "${rr_array[@]:0:8}")
					else
							clear
					fi
					;;
				r)
					swap_commands
					;;
				t)
	  			clear
	  			;;
				c)
					change_workspace
	  			return
					;;
				esac
				;;
		*)
			cd ${selected_option}
			print_line "Current directory $PWD"
			;;
	esac
	load_aliases
	# load_workspace
}

create_workspace()
{
	rr_array=()
	echo "Creating workspace"
	echo "Write a command you would like to add"
	read -p ")" user_input
	rr_array+=($user_input)
}

print_commands () {
  for i in "${!rr_array[@]}"; do
    display_index=$((i+1))
		if [[ "$#" -eq 1 && $i -eq $1 ]]; then
		  print_line "	${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rr_array[$i]}${NO_COLOR}";
		else
		  print_line "${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rr_array[$i]}${NO_COLOR}";
		fi
  done
}

swap_commands () {
	clear
  print_header "Swapping commands"
	print_commands
	read -n 1 -p "" first_input;
	if [[ -n $first_input ]]; then
		first_index=$((first_input-1))
		clear
	  print_header "Swapping commands"
		print_commands first_index
		read -n 1 -p "" second_input;
		if [[ -n $second_input ]]; then
		  second_index=$((second_input-1))
			copy_elem="${rr_array[$second_index]}"
			rr_array[$second_index]="${rr_array[$first_index]}"
			rr_array[$first_index]="${copy_elem}"
			swap_commands
		fi
	fi
	clear
}

alias r=change_workspace
alias ra=add_alias

mapfile -t rr_dir_array < <(cat ~/.jb_rerun/data)
(find ~ -name .rr_array -exec dirname {} \; > ~/.jb_rerun/data&)
