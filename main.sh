# #! /usr/bin/bash

# Global colors
RR_RESET='\e[0m'
RR_GREEN='\033[0;92m'
RR_BLUE='\033[0;34m'
# Global veriables
RR_WORKSPACE_DIR="$HOME/.dynamic_aliases"
RR_WORKSPACE_FILE=.workspace_commands
RR_PATTERN_FILE=patterns.json
ALIAS_REG_PATTERN="^([A-Za-z0-9_]+)\ (.+)$"
# Dynamic veriables
rr_alias_keys=()
rr_alias_commands=()
rr_pattern_alias_keys=()
rr_pattern_alias_commands=()
rr_alias_folder=""
rr_set_alias_keys=( )

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
rr_get_smallest_number() {
	if [ $1 -le $2 ]; then
		echo $1
	else
		echo $2
	fi
}

rr_swap_aliases() {
	if [[ $# -lt 2 ]]; then
		echo "swap aliases requires 2 aliases as arguments"
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
	# swap two alias commands
	copy_elem="${rr_alias_commands[$second_element_index]}"
	rr_alias_commands[$second_element_index]="${rr_alias_commands[$first_element_index]}"
	rr_alias_commands[$first_element_index]="${copy_elem}"
	rr_set_print_aliases
	rr_save_workspace
}

rr_edit_rr_file() {
	$EDITOR $RR_WORKSPACE_FILE
	if [ -e $RR_WORKSPACE_FILE -a ! -s $RR_WORKSPACE_FILE ]; then
		# remove file if exists and empty
		rm $RR_WORKSPACE_FILE
	fi
	rr_load_aliases_pwd
}

rr_add_alias() {
	if [ $# -lt 1 ]; then
		return
	fi
	rr_handle_directory_conflict
	if [ $? -gt 0 ]; then
		return
	fi
	if [[ "$@" =~ $ALIAS_REG_PATTERN ]]; then
		alias_index=$(rr_get_item_index "rr_alias_keys" "${BASH_REMATCH[1]}")
		if [ $alias_index -lt 0 ]; then
			rr_alias_keys+=("${BASH_REMATCH[1]}")
			rr_alias_commands+=("${BASH_REMATCH[2]}")
		else
			rr_alias_commands[alias_index]="${BASH_REMATCH[2]}"
		fi
	else
		printf "failed to parse %s\n" "$@"
		return
	fi
	rr_set_print_aliases
	rr_save_workspace
}

rr_unset_aliases() {
	for (( i=0; i<${#rr_set_alias_keys[@]}; i++ )); do
		unalias "${rr_set_alias_keys[i]}"
	done
	rr_alias_keys=()
	rr_alias_commands=()
	rr_pattern_alias_keys=()
	rr_pattern_alias_commands=()
}

rr_set_print_aliases() {
	rr_set_alias_keys=( )
	for (( i=0; i<${#rr_alias_keys[@]}; i++ )); do
		alias_index=$(rr_get_item_index "rr_set_alias_keys" "${rr_alias_keys[i]}")
		if [ $alias_index -lt 0 ]; then
			alias "${rr_alias_keys[i]}=${rr_alias_commands[i]}"
			printf "$RR_GREEN%s) $RR_RESET%s\n" "${rr_alias_keys[i]}" "${rr_alias_commands[i]}"
			rr_set_alias_keys+=("${rr_alias_keys[i]}")
		fi
	done
	for (( i=0; i<${#rr_pattern_alias_keys[@]}; i++ )); do
		alias_index=$(rr_get_item_index "rr_set_alias_keys" "${rr_pattern_alias_keys[i]}")
		if [ $alias_index -lt 0 ]; then
			alias "${rr_pattern_alias_keys[i]}=${rr_pattern_alias_commands[i]}"
			printf "$RR_BLUE%s) $RR_RESET%s\n" "${rr_pattern_alias_keys[i]}" "${rr_pattern_alias_commands[i]}"
			rr_set_alias_keys+=("${rr_pattern_alias_keys[i]}")
		fi
	done
}

rr_load_aliases_from_file() {
	if [ ! -s $2 ]; then
		return
	fi
	aliases_name="$1_keys"
	local -n aliases="$1_keys"
	local -n commands="$1_commands"
	while IFS= read -r line; do
		if [[ "$line " =~ $ALIAS_REG_PATTERN ]]; then
			aliases+=("${BASH_REMATCH[1]}")
			commands+=("${BASH_REMATCH[2]}")
		else
			printf "failed to parse %s\n" "$line"
		fi
	done < "$2"
}

rr_load_aliases_from_pattern() {
	if [ ! -s "$RR_WORKSPACE_DIR/$RR_PATTERN_FILE" ]; then
		return
	fi
	i=0
	while true; do
		file_pattern=$(jq -er ".[$i].pattern" "$RR_WORKSPACE_DIR/$RR_PATTERN_FILE")
		# if file_pattern not found
		if [ $? -ge 1 ]; then
			break
		fi
		# file_pattern=$(echo "$file_pattern" | sed "s/\$HOME/$HOME/")
		file_pattern="${file_pattern/\$HOME/$HOME}"
		if [[ $PWD == $file_pattern ]]; then
			file=$(jq -er ".[$i].file" "$RR_WORKSPACE_DIR/$RR_PATTERN_FILE")
			rr_load_aliases_from_file rr_pattern_alias "$RR_WORKSPACE_DIR/workspaces/$file"
		fi
		i=$((i+1))
	done
}

rr_load_aliases_pwd() {
	# check if there are commands stored in pwd dir
	rr_unset_aliases
	# load commands from file
	rr_load_aliases_from_file rr_alias "$PWD/$RR_WORKSPACE_FILE"
	rr_alias_folder=$PWD
	# load commands from pattern files
	rr_load_aliases_from_pattern
	# mapfile -t rr_array < <(cat $PWD/$RR_WORKSPACE_FILE)
	rr_set_print_aliases
}

rr_handle_directory_conflict() {
	if [ "$rr_alias_folder" == "$PWD" ]; then
		return 0
	fi
	printf "PWD is not equal to the folder were aliases were loaded. Please choose how to resolve this conflict\n"
	printf "y) Apply changes to $rr_alias_folder/$RR_WORKSPACE_FILE\n"
	printf "l) Load aliases from and apply changes to $PWD/$RR_WORKSPACE_FILE\n"
	printf "o) Apply changes and overwrite $PWD/$RR_WORKSPACE_FILE\n"
	read -e -N 1 -p '>' user_input
	# parse input for valid alias
	if [ $? -gt 0 ]; then
		return 1
	fi
	case $user_input in
		"y")
			;;
		"l")
			# works because it sets rr_alias_folder to pwd
			rr_load_aliases_pwd
			;;
		"o")
			rr_alias_folder=$PWD
			;;
		*)
			printf "Failed to resolve conflict\n"
			return 1
			;;
	esac
	return 0
}

rr_remove_alias() {
	if [ $# -lt 1 ]; then
		return
	fi
	rr_handle_directory_conflict
	if [ $? -gt 0 ]; then
		return
	fi
	new_rr_alias_keys=( )
	new_rr_alias_commands=( )
	for (( i = 0; i < ${#rr_alias_keys[@]}; i++ )); do
		rr_should_add=0
		for (( j = 1; j < $(($# + 1)); j++ )); do
			if [[ "${rr_alias_keys[i]}" == "${!j}" ]]; then
				rr_should_add=1
				break
			fi
		done
		if [ $rr_should_add -eq 0 ]; then
			new_rr_alias_keys+=( "${rr_alias_keys[i]}" )
			new_rr_alias_commands+=( "${rr_alias_commands[i]}" )
		fi
	done
	rr_alias_keys=("${new_rr_alias_keys[@]}")
	rr_alias_commands=("${new_rr_alias_commands[@]}")
	unset new_rr_alias_keys
	unset new_rr_alias_commands
	rr_set_print_aliases
	rr_save_workspace
}

rr_save_workspace() {
	if [ -s $rr_alias_folder/$RR_WORKSPACE_FILE ]; then
		rm $rr_alias_folder/$RR_WORKSPACE_FILE
	fi
	for (( i = 0; i < ${#rr_alias_keys[@]}; i++ )); do
    printf "%s %s\n" "${rr_alias_keys[i]}" "${rr_alias_commands[i]}" >> $rr_alias_folder/$RR_WORKSPACE_FILE
	done
}

rr_print_help() {
	cat <<EOF
usage: rr_workspace_main [option] [argument ...]
  -h Print help
  -e Edit workspace file and reload aliases
  -l List aliases
  -a Add alias
  -r Remove alias
  -s Swap two commands using their aliases
EOF
}

rr_workspace_main() {
	if [ $# -eq 0 ]; then
		rr_load_aliases_pwd
		return
	fi
	case $1 in
		"-e")
			rr_edit_rr_file
			;;
		"-l")
			rr_set_print_aliases
			;;
		"-s")
			rr_swap_aliases ${@:2}
			;;
		"-a")
			rr_add_alias "${@:2}"
			;;
		"-r")
			rr_remove_alias "${@:2}"
			;;
		"-h" | "--help")
			rr_print_help
			;;
		*)
			printf "invalid usage: rr_workspace_main [option] [argument ...]\n"
			;;
	esac
}
