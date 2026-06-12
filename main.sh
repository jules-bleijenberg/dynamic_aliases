#! /usr/bin/bash

# Global colors
RR_GOOD='\033[0;92m';
RR_BAD='\033[0;91m';
RR_PRIMARY='\033[0;97m';

# Global veriables
RR_FZF_COMMAND='fzf --layout reverse --border'
RR_OPTION_KEYS=("a" "s" "d" "f" "g" "h" "j" "k" "l")
RR_NEXT_PAGE_KEY="u"
RR_PREV_PAGE_KEY="i"
RR_WORKSPACE_DIR=$HOME/.rerun_workspace
RR_WORKSPACE_FILE=.workspace_commands

# Global dynamic variables
rr_selected_option="INVALID"
rr_selected_option_index=0

# Workspace oriented (one file per folder)
#		A workspace is usefull in a directory in which the same commands are often used
#		A workspace directory contains a .workspace_commands file with the commands

alias_keys=("${RR_OPTION_KEYS[@]}")
rr_max_len=0
rr_dir_array=()
rr_dir_item_id=0
selected_option="INVALID"
selected_option_key=" "
aging_reg_pattern="^([0-9]+)\ ([0-9]+)\ ([0-9]+)\ (.+)$"
aging_value_reg_pattern="^[0-9]+\ [0-9]+\ [0-9]+\ (.+)$"

# Print header
rr_print_header () {	
	printf "${RR_GOOD}--- %s ---${RR_PRIMARY}\n" "$1";
}

# Get index of item in array
rr_get_item_index() {
	local -n hay=$1 
	needle=$2
	for ((i = 0; i < ${#hay[@]}; i++));
	do
	 	if [[ "${RR_OPTION_KEYS[i]}" = "$needle" ]];
	 	then
			echo $i
			return
	 	fi
	done
	echo -1
}

# Get smallest number :)
rr_get_smallest_number()
{
	if [ $1 -le $2 ]; then
		echo $1
	else
		echo $2
	fi
}

# Pick an item interactively from array
rr_select_array_item()
{
	if [ $# -eq 0 ]; then
		return
	fi
	local -n _array=$1 
	# check assignment and array size
	if [[ $? -ne 0 || ${#_array[@]} -eq 0 ]]; then
		return
	fi
	loop_size=$(rr_get_smallest_number ${#RR_OPTION_KEYS[@]} ${#_array[@]})
	tput sc
	header="Options"
	if [ $# -ge 2 ]; then
		header="$2"
	fi
	rr_print_header "$header"
	# print options
	for ((i = 0; i < $loop_size; i++));
	do
		printf "${GREEN}%s) ${NO_COLOR}%s\n" "${RR_OPTION_KEYS[i]}" "${_array[i]}";
	done
	printf ">"
	rr_selected_option="INVALID"
	while true; do
		# get user input
		read -rs -n 1 user_input
		# quit interactive prompt
		if [[ "${user_input}" = "q" ]]; then
			tput rc ed
			# printf "${GREEN}Exited by user${NO_COLOR}\n"
			rr_selected_option="EXIT"
			return
		fi
		# check user input
		rr_selected_option_index=$(rr_get_item_index RR_OPTION_KEYS $user_input)
		if [ $rr_selected_option_index -ge 0 -a $rr_selected_option_index -lt $loop_size ]; then
				rr_selected_option=${_array[rr_selected_option_index]}
				tput rc ed
				return
		fi
		tput bel
	done
}

swap_aliases () {
	if [[ $# -lt 2 ]]; then
		echo "Swap aliases requires 2 aliases as arguments"
		return
	fi
	first_element=$1
	second_element=$2
	first_element_index=$(rr_get_item_index alias_keys $first_element)
	second_element_index=$(rr_get_item_index alias_keys $second_element)
	if [ $first_element_index -lt 0 -o $first_element_index -ge $rr_max_len -o $second_element_index -lt 0 -o $second_element_index -ge $rr_max_len -o $first_element_index -eq $second_element_index ]; then
		echo "Invalid alias parameter"
		return
	fi
	copy_elem="${rr_array[$second_element_index]}"
	rr_array[$second_element_index]="${rr_array[$first_element_index]}"
	rr_array[$first_element_index]="${copy_elem}"
	set_print_aliases
	save_workspace
}

edit_rr_file() {
	vim $RR_WORKSPACE_FILE
	load_aliases
}

sort_rr_dir_array() {
	IFS=$'\n'
	rr_dir_array=($(sort -rgt' ' -k1 -k2 <<<"${rr_dir_array[*]}"));
	unset IFS
}

save_rr_dir_array()
{
	if [[ ${#rr_dir_array[@]} -gt 0 ]];
	then
		printf "%s\n" "${rr_dir_array[@]}" > $RR_WORKSPACE_DIR/data
	fi
}

add_alias_from_last_commands()
{
	# get last commands (excludine r commands)
	grep_selection=$'^\t [r'
	for i in "${!alias_keys[@]}"; do
		grep_selection="$grep_selection${alias_keys[i]}"
	done
	grep_selection="${grep_selection}]"
	last_executed_commands_string=$(fc -rln -50 | grep -ve "$grep_selection .*\|$grep_selection$")
	#last_executed_commands_string=$(fc -rln -30 | grep -ve $'^\t r ')
	# last_executed_commands_string=$(fc -rln -11 | tail -10)
	IFS=$'\n'
	read -r -d '' -a last_executed_commands <<< "$last_executed_commands_string"
	unset IFS
	for ((i = 0; i < ${#last_executed_commands[@]}; i++));
	do
		# remove padding
		last_executed_commands[i]=$(echo "${last_executed_commands[i]}" | cut -d " " -f 2-)
	done
	rr_array_modified=false
	while [ true ]; do
		rr_select_array_item last_executed_commands "History Commands"
		if [[ $rr_selected_option == "EXIT" ]]; then
			break
		fi
		selected_command=$rr_selected_option
		tmp_rr_array=("${rr_array[@]}" "<empty>")
		rr_select_array_item tmp_rr_array "Overwrite Alias"
		if [[ $rr_selected_option == "EXIT" ]]; then
			break
		fi
		rr_array[$rr_selected_option_index]=$selected_command
		rr_array_modified=true
    printf "$RR_GOOD%s) $RR_PRIMARY%s\n" "${alias_keys[rr_selected_option_index]}" "$selected_command"
	done
	if [ "$rr_array_modified" = false ]; then
		return
	fi
	set_print_aliases
	save_workspace
}

set_aliases()
{
	# remove aliases of deleted elements
  for (( i = 0; i < rr_max_len; i++ )); do
		alias_key=${alias_keys[$i]}
		remove_alias_key=${alias_keys[$i]}_r
		unalias "$alias_key"
		unalias "$remove_alias_key"
  done
	# get max alias size
	if [[ ${#rr_array[@]} -le ${#alias_keys[@]} ]]; then
		rr_max_len=${#rr_array[@]}
	else
		rr_max_len=${#alias_keys[@]}
	fi
	# set aliases and print them
  for (( i = 0; i < rr_max_len; i++ )); do
		alias_key=${alias_keys[$i]}
		remove_alias_key=${alias_keys[$i]}_r
		alias "$alias_key=${rr_array[$i]}"
		alias "$remove_alias_key=remove_alias $i"
  done
}

print_aliases() {
	if [[ -s $PWD/$RR_WORKSPACE_FILE ]]; then
		printf "%s\n" "$PWD"
	else
		printf "%s (no $RR_WORKSPACE_FILE file found)\n" "$PWD"
	fi
  for (( i = 0; i < rr_max_len; i++ )); do
		alias_key=${alias_keys[$i]}
    printf "$RR_GOOD%s) $RR_PRIMARY%s\n" "$alias_key" "${rr_array[$i]}"
  done
}

set_print_aliases()
{
	set_aliases
	print_aliases
}

load_aliases()
{
	# check if there are commands stored in pwd dir
	if [[ ! -s $PWD/$RR_WORKSPACE_FILE ]]
	then
		printf "workspace file not found\n";
		return
	fi
	# load commands into array
  mapfile -t rr_array < <(cat $PWD/$RR_WORKSPACE_FILE)
	set_print_aliases
}

add_rr_dir_item()
{
	rr_dir_array=("${rr_dir_array[@]}" "1 1 $(date +%s) $1");
	sort_rr_dir_array
	save_rr_dir_array
}

add_alias()
{
	# get last executed command
	last_executed_command=$(fc -ln -2 | head -1 | cut -d " " -f 2-)
	# check if .workspace_commands file exists in pwd dir
	if [[ -s $PWD/$RR_WORKSPACE_FILE ]]
	then
		# append last executed command
		local -n _rr_array="rr_array"
		rr_array=("${rr_array[@]}" "${last_executed_command}")
	else
		# create new rr_array
		printf "${RR_GOOD}Created workspace${RR_PRIMARY}\n"
		rr_array=("${last_executed_command}")
		# check if dir already exists
		dir_already_exists=0
		for i in "${!rr_dir_array[@]}"; do
			if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]] && [[ ${BASH_REMATCH[4]} == $(pwd) ]]; then
				dir_already_exists=1
				break
			fi
		done
		if [[ ${dir_already_exists} -le 0 ]]; then
			add_rr_dir_item "$pwd"
		fi
	fi
	#	rr_array=("${last_executed_command}" "${rr_array[@]:0:8}")
	# reload aliases
	set_print_aliases
	save_workspace
}

remove_alias()
{
	# if param is valid array index remove it
	if [[ $1 -ge $rr_max_len && $1 -lt 0 ]]; then
		return
	fi
	new_rr_array=( )
	for i in "${!rr_array[@]}"; do
		if [[ $1 -ne $i ]]; then
			new_rr_array+=( "${rr_array[i]}" )
		fi
	done
	rr_array=("${new_rr_array[@]}")
	unset new_rr_array
	set_print_aliases
	save_workspace
}

save_workspace()
{
	# Assumes current directory is workspace
	if [[ ${#rr_array[@]} -gt 0 ]];
	then
		printf "%s\n" "${rr_array[@]}" > $RR_WORKSPACE_FILE
	else
		rm $RR_WORKSPACE_FILE
		printf "${RR_BAD}Removed workspace${RR_PRIMARY}\n"
	fi
}

print_workspaces()
{
	for i in "${!rr_dir_array[@]}"; do
		if [[ "${rr_dir_array[i]}" =~ $aging_value_reg_pattern ]]; then
			echo ${BASH_REMATCH[1]}
		fi
	done
}

get_workspace_directory_id()
{
	if [ ! -d $1 ]; then
		return 20
	fi
	directory=$(realpath $1)
	# check if dir already exists
	for i in "${!rr_dir_array[@]}"; do
		if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
			saved_directory=${BASH_REMATCH[4]}
			if [[ "$directory" == "$saved_directory" ]]; then
				rr_dir_item_id=$i
				return 0
			fi
		fi
	done
	return 2
}

remove_workspace()
{
	if [ $# -eq 0 ]; then
		new_rr_dir_array=( )
		for i in "${!rr_dir_array[@]}"; do
			if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
				saved_directory=${BASH_REMATCH[4]}
				if [[ -d "$saved_directory" ]]; then
					new_rr_dir_array+=( "${rr_dir_array[i]}" )
				fi
			fi
		done
		unset new_rr_dir_array
		return
	fi
	if [ ! -d $1 ]; then
		printf "Received invalid directory\n"
		return
	fi
	directory=$(realpath $1)
	get_workspace_directory_id "$directory"
	if [[ $? -gt 0 ]]; then
		printf "%s is not a workspace directory\n" "$directory"
		return
	fi
	new_rr_dir_array=( )
	for i in "${!rr_dir_array[@]}"; do
		if [[ $rr_dir_item_id -ne $i ]]; then
			new_rr_dir_array+=( "${rr_dir_array[i]}" )
		fi
	done
	rr_dir_array=("${new_rr_dir_array[@]}")
	unset new_rr_dir_array
	save_rr_dir_array
}

move_workspace()
{
	if [[ $# -ne 2 ]]; then
		printf "Moving a directory requires 2 directories\n"
		return
	fi
	if [ ! -d $1 -o ! -d $2 ]; then
		printf "Received invalid directory\n"
		return
	fi
	start_directory=$(realpath $1)
	end_directory=$(realpath $2)
	# start with end directory so no double loop for BASH_REMATCH values
	get_workspace_directory_id "$end_directory"
	if [ $? -eq 0 ]; then
		echo $end_directory
		echo $end_directory_id
		printf "%s is already a workspace directory\n" "$end_directory"
		return
	fi
	end_directory_id=$rr_dir_item_id
	get_workspace_directory_id "$start_directory"
	start_directory_id=$rr_dir_item_id
	if [ $? -gt 0 ]; then
		printf "%s is not a workspace directory\n" "$start_directory"
		return
	fi
	# overwrite saved path
	rr_dir_array[start_directory_id]="${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} $end_directory"
	printf "moved path from %s to %s\n" "$start_directory" "$end_directory"
	save_rr_dir_array
}

change_workspace()
{
	# check if user is trying to go nowhere
	if [[ $# -eq 0 ]]; then
		# if he is, respond by doing nothing
		return
	fi
	if [ ! -d $1 ]; then
		printf "%s is not a valid directory\n" "$1"
		return
	fi
	directory=$(realpath $1)
	directory_id=-1
	# check if dir already exists
	for i in "${!rr_dir_array[@]}"; do
		if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
			saved_directory=${BASH_REMATCH[4]}
			if [[ "$directory" == "$saved_directory" ]]; then
				directory_id=$i
				break
			fi
		fi
	done
	if [ $directory_id -eq -1 ]; then
		# create rr_dir_item
		rr_array=()
		printf "${RR_GOOD}Added directory${RR_PRIMARY}\n"
		add_rr_dir_item "$directory"
	else
		# update score
		BASH_REMATCH[2]=$(( ${BASH_REMATCH[2]} + 1 ))
		score=$(calculate_score)
		rr_dir_array[directory_id]="$score ${BASH_REMATCH[2]} $(date +%s) ${BASH_REMATCH[4]}"
		sort_rr_dir_array
		save_rr_dir_array
	fi
	cd $directory
	load_aliases
}

calculate_score() {
	score_index=1
	seconds=$(( ($(date +%s) - ${BASH_REMATCH[3]}) )) 
	compare_number=3600*6
	multiplier=2
	while [ $score_index -le 10 ]; do
		if [ $seconds -le $(( $compare_number * $multiplier )) ]; then
			break
		fi
		multiplier=$(( $multiplier * 2))
		score_index=$(( $score_index + 1 ))
	done
	echo $(( ${BASH_REMATCH[2]} / ($score_index) ))
}

on_start () {
	# load workspaces if data file exists
	if [ -s $RR_WORKSPACE_DIR/data ]; then
		mapfile -t rr_dir_array < <(cat $RR_WORKSPACE_DIR/data)
	fi
	# loop over stored directories and recalculate score
	for ((i = 0; i < ${#rr_dir_array[@]}; i++));
	do
		if [[ ! "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
			printf "Invalid line in %s: \"%s\"\n" "$RR_WORKSPACE_DIR/data" "${rr_dir_array[i]}"
			continue
		fi
		score=$(calculate_score)
		rr_dir_array[i]="$score ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]}"
	done
	sort_rr_dir_array
}

rr_workspace_main () {
	arguments=( )
	options=""
	# split options and arguments
	for argument in $@
	do
		if [[ $argument == "-"* ]]; then
			options="$options$argument"
		else
			arguments+=( $argument )
		fi
	done
	# handle options
	if [[ $options == *"h"* ]]; then
		cat $RR_WORKSPACE_DIR/help.txt
	elif [[ $options == *"m"* ]]; then
		move_workspace ${arguments[@]}
	elif [[ $options == *"d"* ]]; then
		remove_workspace ${arguments[@]}
	elif [[ $options == *"e"* ]]; then
		edit_rr_file
	elif [[ $options == *"l"* ]]; then
		print_workspaces
	elif [[ $options == *"i"* ]]; then
		print_aliases
	elif [[ $options == *"s"* ]]; then
		swap_aliases ${arguments[@]}
	elif [[ $options == *"a"* ]]; then
		add_alias
	elif [[ $options == *"o"* ]]; then
		add_alias_from_last_commands
	else
		if [ $# -eq 0 ]; then
			arguments+="$(print_workspaces | $RR_FZF_COMMAND)"
			if [ $? -gt 0 ]; then
				return
			fi
		fi
		change_workspace ${arguments[@]}
	fi
}

on_start
