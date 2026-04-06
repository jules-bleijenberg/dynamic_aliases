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
selected_option="INVALID"
selected_option_key=" "

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
	printf "%s\n" "${rr_array[@]}" > .rr_array
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
	load_workspace
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

rr () {
	if [[ -s $PWD/.rr_array ]]
	then
    load_workspace
	else
		change_workspace
	fi
}

mapfile -t rr_dir_array < <(cat ~/.jb_rerun/data)
(find ~ -name .rr_array -exec dirname {} \; > ~/.jb_rerun/data&)
