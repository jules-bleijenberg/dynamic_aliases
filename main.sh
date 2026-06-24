#! /usr/bin/bash

# Global colors
RR_GOOD='\033[0;92m';
RR_BAD='\033[0;91m';
RR_PRIMARY='\033[0;97m';
RR_BLUE='\033[0;96m';
# Global veriables
RR_WORKSPACE_DIR=$HOME/.rerun_workspace
RR_WORKSPACE_FILE=.workspace_commands
RR_PATTERN_FILE=patterns.json
ALIAS_REG_PATTERN="^([A-Za-z]+)\ (.+)$"
# Dynamic veriables
rr_alias_keys=()
rr_alias_commands=()
rr_local_alias_len=0

# Get index of item in array
rr_get_item_index() {
	local -n hay=$1 
	needle=$2
	for ((i = 0; i < ${#hay[@]}; i++));
	do
	 	if [[ "${hay[i]}" = "$needle" ]];
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

# swap two alias commands
rr_swap_array_items()
{
	local -n array=$1 
	first_index=$2
	second_index=$3
	copy_elem="${array[$second_index]}"
	array[$second_index]="${array[$first_index]}"
	array[$first_index]="${copy_elem}"
}

swap_aliases () {
	if [[ $# -lt 2 ]]; then
		echo "Swap aliases requires 2 aliases as arguments"
		return
	fi
	first_element=$1
	second_element=$2
	first_element_index=$(rr_get_item_index rr_alias_keys $first_element)
	second_element_index=$(rr_get_item_index rr_alias_keys $second_element)
	if [ $first_element_index -lt 0 -o $first_element_index -ge ${#rr_alias_keys[@]} -o $second_element_index -lt 0 -o $second_element_index -ge ${#rr_alias_keys[@]} ]; then
		echo "Invalid alias parameter"
		return
	fi
	if [ $first_element_index -eq $second_element_index ]; then
		return
	fi
	rr_swap_array_items rr_alias_commands first_element_index second_element_index
	# copy_elem="${rr_array[$second_element_index]}"
	#	rr_array[$second_element_index]="${rr_array[$first_element_index]}"
	#	rr_array[$first_element_index]="${copy_elem}"
	set_print_aliases
	save_workspace
}

edit_rr_file() {
	$EDITOR $RR_WORKSPACE_FILE
	if [ -e $RR_WORKSPACE_FILE -a ! -s $RR_WORKSPACE_FILE ]; then
		# remove file if exists and empty
		rm $RR_WORKSPACE_FILE
	fi
	load_aliases
}

add_alias()
{
	last_executed_command=$(fc -rln -50 | cut -d " " -f 2- | fzf)
	if [ $? -gt 0 ]; then
		return
	fi
	printf "%s\n" "$last_executed_command"
	read -e -p 'alias>' user_input
	# parse input for valid alias
	if [ $? -gt 0 ]; then
		return
	fi
	rr_alias_keys+=("$user_input")
	rr_alias_commands+=("$last_executed_command")
	set_print_aliases
	save_workspace
}

unset_aliases()
{
	for (( i=0; i<${#rr_alias_keys[@]}; i++ )); do
		unalias "${rr_alias_keys[i]}"
	done
	rr_alias_keys=()
	rr_alias_commands=()
}

set_print_aliases() {
	for (( i=0; i<${#rr_alias_keys[@]}; i++ )); do
		alias "${rr_alias_keys[i]}=${rr_alias_commands[i]}"
		if [ $i -lt $rr_local_alias_len ]; then
			printf "$RR_GOOD%s) $RR_PRIMARY%s\n" "${rr_alias_keys[i]}" "${rr_alias_commands[i]}"
		else
			printf "$RR_BLUE%s) $RR_PRIMARY%s\n" "${rr_alias_keys[i]}" "${rr_alias_commands[i]}"
		fi
	done
}

load_aliases_from_file()
{
	if [ ! -s $1 ]; then
		return
	fi
	while IFS= read -r line; do
		# ADD: Duplicate overwriting
		if [[ "$line " =~ $ALIAS_REG_PATTERN ]]; then
			# echo "${BASH_REMATCH[1]}: ${BASH_REMATCH[2]} "
			alias_index=$(rr_get_item_index rr_alias_keys "${BASH_REMATCH[1]}")
			if [ $alias_index -lt 0 ]; then
				rr_alias_keys+=("${BASH_REMATCH[1]}")
				rr_alias_commands+=("${BASH_REMATCH[2]}")
			# else
			# 	rr_alias_commands[alias_index]="${BASH_REMATCH[2]}"
			fi
		else
			printf "${RR_BAD}Failed to parse %s\n" "$line"
		fi
	done < "$1"
}

load_aliases_from_pattern()
{
	i=0
	while true; do
		file_pattern=$(jq -er ".[$i].pattern" "$RR_WORKSPACE_DIR/$RR_PATTERN_FILE")
		# if file_pattern not found
		if [ $? -ge 1 ]; then
			break
		fi
		if [[ "$PWD" == $file_pattern ]]; then
			file=$(jq -er ".[$i].file" "$RR_WORKSPACE_DIR/$RR_PATTERN_FILE")
			load_aliases_from_file "$RR_WORKSPACE_DIR/pattern_files/$file"
		fi
		i=$((i+1))
	done
}

load_aliases()
{
	# check if there are commands stored in pwd dir
	unset_aliases
	# load commands from file
	load_aliases_from_file "$PWD/$RR_WORKSPACE_FILE"
	rr_local_alias_len=${#rr_alias_keys[@]}
	# load commands from pattern files
	load_aliases_from_pattern
	# mapfile -t rr_array < <(cat $PWD/$RR_WORKSPACE_FILE)
	set_print_aliases
}

remove_alias()
{
	# if param is valid array index remove it
	if [[ $1 -lt 0 ]]; then
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
	if [ -s $PWD/$RR_WORKSPACE_FILE ]; then
		rm $PWD/$RR_WORKSPACE_FILE
	fi
	for (( i=0; i<${#rr_alias_keys[@]}; i++ )); do
    printf "%s %s\n" "${rr_alias_keys[i]}" "${rr_alias_commands[i]}" >> $PWD/$RR_WORKSPACE_FILE
	done
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
	elif [[ $options == *"e"* ]]; then
		edit_rr_file
	elif [[ $options == *"l"* ]]; then
		set_print_aliases
	elif [[ $options == *"s"* ]]; then
		swap_aliases ${arguments[@]}
	elif [[ $options == *"a"* ]]; then
		add_alias
	fi
}
