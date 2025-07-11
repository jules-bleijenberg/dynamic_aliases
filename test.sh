#! /usr/bin/bash

# Workspace oriented (one file per folder)
#		A workspace is usefull in a directory in which the same commands are often used
#		A workspace directory contains a .rr_array file with the commands

save_rerun()
{
	# Assumes current directory is workspace
	printf "%s\n" "${rr_array[@]}" > .rr_array
}

option_keys=("a" "s" "d" "f" "g" "h" "j" "k" "l")
selected_option="INVALID"

handle_options()
{
	for ((i = 0; i < ${#option_keys[@]} && i < $#; i++));
	do
		j=$((i+1))
		echo "${option_keys[i]}) ${!j}"
	done
	# get user input
	read -n 1 -p ")" user_input
	# handle user input
	selected_option="INVALID"
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

rerun()
{
	echo "Running"
	mapfile -t rr_array < <(find ~ -name .easyrun -exec dirname {} \;)
	handle_options "${rr_array[@]}"
	if [[ ! "${selected_option}" = "INVALID" ]];
	then
		cd ${selected_option}
		echo "Changed directory to ${selected_option}"
	fi
}

rerun

# End by Jules
