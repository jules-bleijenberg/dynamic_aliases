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
aging_reg_pattern="^([0-9]+)\ ([0-9]+)\ ([0-9]+)\ (.+)$"
aging_value_reg_pattern="^[0-9]+\ [0-9]+\ [0-9]+\ (.+)$"

get_item_index() {
	name=$1[@]
	needle=$2
	hay=("${!name}")
	for ((i = 0; i < ${#hay[@]}; i++));
	do
	 	if [[ "${option_keys[i]}" = "$needle" ]];
	 	then
			echo $i
			return
	 	fi
	done
	echo -1
}

swap_aliases () {
	if [[ $# -lt 2 ]]; then
		echo "Swap aliases requires 2 aliases as arguments"
		return
	fi
	first_element=$1
	second_element=$2
	first_element_index=$(get_item_index alias_keys $first_element)
	second_element_index=$(get_item_index alias_keys $second_element)
	if [ $first_element_index -lt 0 -o $first_element_index -ge $max_len -o $second_element_index -lt 0 -o $second_element_index -ge $max_len -o $first_element_index -eq $second_element_index ]; then
		echo "Invalid alias parameter"
		return
	fi
	copy_elem="${rr_array[$second_element_index]}"
	rr_array[$second_element_index]="${rr_array[$first_element_index]}"
	rr_array[$first_element_index]="${copy_elem}"
	set_aliases
	save_workspace
}

sort_rr_dir_array() {
	IFS=$'\n'
	# todo? sort on last used time too
	rr_dir_array=($(sort -rgt' ' -k1 -k2 <<<"${rr_dir_array[*]}"));
	unset IFS
	# set complete words
	word_list=''
	for i in "${!rr_dir_array[@]}"; do
		if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
			word_list="$word_list $(echo ${BASH_REMATCH[4]} | tr \/ \ )"
		fi
	done
	complete -W "$word_list" r
}

save_rr_dir_array()
{
	if [[ ${#rr_dir_array[@]} -gt 0 ]];
	then
		printf "%s\n" "${rr_dir_array[@]}" > ~/.jb_rerun/data
	else
		print_line "${RED}No data to be saved${NO_COLOR}"
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
}

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
		print_line "${GREEN}Created workspace${NO_COLOR}"
		rr_array=("${last_executed_command}")
		# add dir to rr_dir_array
		score=1
		# check if dir already exists
		dir_already_exists=0
		for i in "${!rr_dir_array[@]}"; do
			if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]] && [[ ${BASH_REMATCH[4]} == $(pwd) ]]; then
				dir_already_exists=1
				break
			fi
		done
		if [[ ${dir_already_exists} -le 0 ]]; then
			rr_dir_array=("${rr_dir_array[@]}" "$score $score $(date +%s) $(pwd)")
		fi
	fi
	#	rr_array=("${last_executed_command}" "${rr_array[@]:0:8}")
	# reload aliases
	set_aliases
	save_workspace
}

remove_alias()
{
	# if param is valid array index remove it
	if [[ $1 -ge $max_len && $1 -lt 0 ]]; then
		return
	fi
	for i in "${!rr_array[@]}"; do
		if [[ $1 -ne $i ]]; then
			new_rr_array+=( "${rr_array[i]}" )
		fi
	done
	# remove rr_dir_item if no aliases left?
	# if [[ ${#rr_array[@]} -le ${#alias_keys[@]} ]]; then
	# fi
	rr_array=("${new_rr_array[@]}")
	unset new_rr_array
	set_aliases
	save_workspace
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
		print_line "${RED}Removed workspace${NO_COLOR}"
	fi
}

change_workspace()
{
	if [[ $# -gt 0 ]]; then
		for i in "${!rr_dir_array[@]}"; do
			# if rr_dir_item contains parameter
			if [[ ${rr_dir_array[$i]} == *"$1"* ]]; then
				if [[ "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
					dir=${BASH_REMATCH[4]}
					# update score
					score=$(( ${BASH_REMATCH[2]} + 1 ))
					# score as old_date + (now - old_date) / 2
					rr_dir_array[i]="$score $score $(date +%s) ${BASH_REMATCH[4]}"
					sort_rr_dir_array
					save_rr_dir_array
					# cd  to & load workspace
					print_line "$dir"
					cd $dir
					load_aliases
					return
				fi
			fi
		done
		print_line "${NO_COLOR}$1 not found${NO_COLOR}"
	else
		# log all workspaces
		for i in "${!rr_dir_array[@]}"; do
			if [[ "${rr_dir_array[i]}" =~ $aging_value_reg_pattern ]]; then
				echo ${BASH_REMATCH[1]}
			fi
		done
	fi
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

last_run_data_path=~/.jb_rerun/last_run_data

calculate_score() {
	score_index=1
	seconds=$(( ($(date +%s) - ${BASH_REMATCH[3]}) )) 
	compare_number=3600
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
	mapfile -t rr_dir_array < <(cat ~/.jb_rerun/data)
	# (find ~ -name .rr_array -exec dirname {} \; > ~/.jb_rerun/data&)
	if [[ ! -s $last_run_data_path ]]
	then
		# create new rr_array
		print_line "${GREEN}no data${NO_COLOR}"
		return
	fi
	# grep number only
	last_run_timestamp=$(grep -E "[0-9]" -m 1 $last_run_data_path)
	# check empty string and positive difference
	afk_seconds=$(( $(date +%s) - $last_run_timestamp ))
	echo $(date +%s)  $afk_seconds
	# loop over items
	for ((i = 0; i < ${#rr_dir_array[@]}; i++));
	do
		# string="80 1776016361 /home/jube/.jb_rerun"
		if [[ ! "${rr_dir_array[i]}" =~ $aging_reg_pattern ]]; then
			echo ${rr_dir_array[i]}
			continue
		fi
		printf 'Got %s, %s and %s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
		# time_not_ran=$(( ($(date +%s) - ${BASH_REMATCH[3]}) / 3600 )) 
		# # score=$(( ${BASH_REMATCH[1]} * 10 / ( 15 - 14 / (1 + $time_not_ran)) ))
		# score=$(( ${BASH_REMATCH[2]} / (1 + $time_not_ran) ))
		# score=$(calculate_score)
		score=$(calculate_score)
		rr_dir_array[i]="$score ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]}"
	done
	sort_rr_dir_array
	# echo ${rr_dir_array[*]}
}

alias r=change_workspace
alias ra=add_alias
alias rs=swap_aliases

on_start
