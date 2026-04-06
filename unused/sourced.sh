#! /usr/bin/bash

# Created by Jube

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

ucc () {
	cc -lbsd $* -Wall -Wextra -Werror && ./a.out && rm ./a.out & pid=$!;
	# Timeout for infinite loops
	for i in {1..55}; do
		read -n 1 -p "" -t 0.1 should_kill;
		if [[ $should_kill == "q" ]]; then
			print_line "uit process. \nTrace: terminated by the terminator";
			kill $pid;
		fi
		out=$( ps -p "$pid" --format=%p );
		if [[ ! $out == *"$pid"* ]]; then
			return;
		fi
	done
	out=$( ps -p "$pid" --format=%p );
	if [[ $out == *"$pid"* ]]; then
		print_line "Exit by timeout";
		kill $pid;
	fi
}
rr_options="cu"; 
rr_is_clearing=1;

run_and_print_command () {
    if [ $rr_is_clearing -eq 1 ]; then
				clear;
    fi
    print_header "Command"
    print_line "$1"
    print_header "Output"
    eval "$1"
}

print_commands () {
  for i in "${!rerun_items[@]}"; do
    display_index=$((i+1))
		if [[ "$#" -eq 1 && $i -eq $1 ]]; then
		  print_line "	${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rerun_items[$i]}${NO_COLOR}";
		else
		  print_line "${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rerun_items[$i]}${NO_COLOR}";
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
			copy_elem="${rerun_items[$second_index]}"
			rerun_items[$second_index]="${rerun_items[$first_index]}"
			rerun_items[$first_index]="${copy_elem}"
			swap_commands
		fi
	fi
	clear
}

recursive_run () {
    # mapfile -t rerun_commands < <(cat ~/.rr_commands | grep --invert-match --max-count 9 ^rr)
    # for i in "${!rerun_commands[@]}"; do
    #     display_index=$((i+1))
    #     print_line "${OPT_LEFT_COLOR}$display_index) ${OPT_COLOR}${rerun_commands[$i]}${NO_COLOR}";
    # done
    print_header "Commands"
		print_commands
    tput civis
	  # trap sigint tput cvvis -> quit
	  read -n 1 -p "" user_input;
	  tput cvvis
    print_line ""
    print_line ""

    case $user_input in
		q)
        print_line "${GREEN}Terminated successfully${NO_COLOR}"
  			return
  			;;
		w)
  			clear
  			;;
		e)
        print_line "${GREEN}Adding command${NO_COLOR}"
				read -e -p ">" command_to_execute;
				if [[ -n $command_to_execute ]]; then
						run_and_print_command "${command_to_execute}"
					  history -s "${command_to_execute}"
						rerun_items=("${command_to_execute}" "${rerun_items[@]:0:8}")
				else
						clear
				fi
				;;
		r)
				swap_commands
				;;
		*)
        selected_index=$((user_input-1))
				run_and_print_command "${rerun_items[$selected_index]}"
        ;;
	esac
  recursive_run
}

er () {
    # Program options
    while getopts $rr_options option;
    do
        case $option in
            c) # Don't clear | c stands for unclear or useless considering I'll never use it :] 
                is_clearing=0;;
            u)
								mapfile -t rerun_items < <(history 50 | tac - | cut -c 8- | uniq -u - | grep --invert-match --max-count 9 ^rr)
        esac
    done
		if [[ -z $rerun_items ]]; then
				mapfile -t rerun_items < <(history 50 | tac - | cut -c 8- | uniq -u - | grep --invert-match --max-count 9 ^rr)
		fi
    recursive_run
}

add_42 () {
	for var in $(find . -name "*.c";)
	do
		var=$(basename $var)
		if ! grep -q "jbleijen <jbleijen@student.42.fr>" $var;
		then
			head -c 248 ~/.header_file > /tmp/tmp_header_file
			echo -n "$var" >> /tmp/tmp_header_file
			tail -c $((644 - ${#var})) ~/.header_file >> /tmp/tmp_header_file
				cat $var >> /tmp/tmp_header_file
				cp /tmp/tmp_header_file $var
		fi
	done
}
