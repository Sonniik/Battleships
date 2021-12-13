
#!/bin/bash

tput smcup #saves and yeets the terminal
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P ) #get script directory
pushd "$parent_path" > /dev/null #continue in script directory (noecho)

trap cleanexit INT
cleanexit() {
	popd > /dev/null #leave script directory (noecho)
	tput rmcup #yeets battleships and restores terminal
	exit
}

#=====	Battlefield		=====
# asign field positions to asciiart positions
# letters -> 3+4*position in alphabet (starting at 0)
# numbers -> 3+2*(number-1)
# 0 - no ship; 1 - ship; hit - hit ship; water - missed hit; deat - sunk ship

declare -A battlefield
for gridcolumn in {1..9}; do
	for gridrow in {1..9}; do
		battlefield[$gridcolumn,$gridrow]=0
	done
done

#=====	Ship generation	=====
declare -A shipsize
shipsize[1]=0
shipsize[2]=0
shipsize[3]=0
shipsize[4]=0
shipsize[5]=0
shipsize[total]=0

declare -A ships

fieldshift=(-1 1)
shipindex=0
aliveships=()
for x in {1..20}; do
	size=0
	column=$(($(($RANDOM % 9))+1))
	row=$(($(($RANDOM % 9))+1))
	if [[ "${battlefield[$column,$row]}" = 0 ]] && [[ "${battlefield[$(($column+1)),$row]}" != 1 ]] && [[ "${battlefield[$column,$(($row+1))]}" != 1 ]] && [[ "${battlefield[$(($column-1)),$row]}" != 1 ]] && [[ "${battlefield[$column,$(($row-1))]}" != 1 ]]; then #get an empty field with nothing around
		shipindex=$(($shipindex+1))
		aliveships+=( $shipindex )
		ships[$shipindex]=$column,$row
		battlefield[$column,$row]=1
		size=1
		for shift in "${fieldshift[@]}"; do
			if [[ "${battlefield[$(($column+$shift)),$row]}" = 0 ]] && [[ "${battlefield[$(($column+$shift+$shift)),$row]}" != 1 ]] && [[ "${battlefield[$(($column+$shift)),$(($row+1))]}" != 1 ]] && [[ "${battlefield[$(($column+$shift)),$(($row-1))]}" != 1 ]]; then #find if the ship can expand verticaly
				battlefield[$(($column+$shift)),$row]=$(($RANDOM % 2))
					if [[ "${battlefield[$(($column+$shift)),$row]}" = 1 ]]; then
						ships[$shipindex]="${ships[$shipindex]} $(($column+$shift)),$row"
						size=$(($size+1))
					fi
			fi
			if [[ "${battlefield[$column,$(($row+$shift))]}" = 0 ]] && [[ "${battlefield[$column,$(($row+$shift+$shift))]}" != 1 ]] && [[ "${battlefield[$(($column+1)),$(($row+$shift))]}" != 1 ]] && [[ "${battlefield[$(($column-1)),$(($row+$shift))]}" != 1 ]]; then #find if the ship can expand horizontaly
				battlefield[$column,$(($row+$shift))]=$(($RANDOM % 2))
					if [[ "${battlefield[$column,$(($row+$shift))]}" = 1 ]]; then
						ships[$shipindex]="${ships[$shipindex]} $column,$(($row+$shift))"
						size=$(($size+1))
					fi
			fi
		done
	fi
	shipsize[$size]=$((${shipsize[$size]}+1))
	shipsize[total]=$((${shipsize[total]}+$size))
done

#=====	Variables		=====

columns=('A' 'B' 'C' 'D' 'E' 'F' 'G' 'H' 'I')
attemptsleft=$((${shipsize[total]}*2))
victory=false
score=0
maxscore=$((${shipsize[total]}))

#=====	Functions		=====

getindex () { #getindex listname expression
	list=$1'[@]'
	index=1
	for i in ${!list}; do
		if [[ "$i" = "$2" ]]; then
			echo "$index";
		fi
		index=$(($index+1))
	done
}

carriageup () {
	printf "\33[%d;%dH%s" "0" "0"
}

shotcolumn=''
shotrow=''
getshotcoords () {
	correctvalue=false
	while [ "$correctvalue" = false ]; do
		printf "\33[%d;%dH%s" "21" "11"
		read usershotcoords
		shotcoords=${usershotcoords^}
		if [[ "${#shotcoords}" = 2 ]]; then
			for item in ${columns[@]}; do
				if [[ ${shotcoords:0:1} = "$item" ]]; then
					shotcolumn=$(getindex columns ${shotcoords:0:1})
					for number in {0..9}; do
						if [[ ${shotcoords:1:1} = "$number" ]]; then
							shotrow=${shotcoords:1:1}
							[[ ${battlefield[$shotcolumn,$shotrow]} = 0 || ${battlefield[$shotcolumn,$shotrow]} = 1 ]] && correctvalue=true
						fi
					done
				fi
			done
		fi
		if [[ "$correctvalue" = false ]]; then
			printf "\33[%d;%dH%s" "21" "0" "Shoot at: Invalid Remaining attempts: $attemptsleft   "
			sleep 1
			printf "\33[%d;%dH%s" "21" "0" "Shoot at:        "
			printf "\33[%d;%dH%s" "21" "11"
		fi
	done
	attemptsleft=$(($attemptsleft-1))
	[[ ${#attemptsleft} = 1 ]] && attemptsleft=" $attemptsleft"
	printf "\33[%d;%dH%s" "21" "10" "        Remaining attempts: $attemptsleft   "
}

printscore () {
	percentageshot=$(echo "scale=3; $score / $maxscore * 100" | bc) && decimal=${percentageshot#*.} && percentageshot=${percentageshot%.*}.${decimal::1} && [[ ${#percentageshot} = 4 ]] && printf "\33[%d;%dH%s" "16" "53" "$percentageshot %" || printf "\33[%d;%dH%s" "16" "54" "$percentageshot %"
}

shoot () {
	[[ ${battlefield[$shotcolumn,$shotrow]} = 0 ]] && battlefield[$shotcolumn,$shotrow]='water' && printf "\33[%d;%dH%s" "$((3+2*($shotrow-1)))" "$((3+4*($shotcolumn-1)))" "~"
	[[ ${battlefield[$shotcolumn,$shotrow]} = 1 ]] && battlefield[$shotcolumn,$shotrow]='hit' && printf "\33[%d;%dH%s" "$((3+2*($shotrow-1)))" "$((3+4*($shotcolumn-1)))" "¤" && score=$(($score+1)) && printscore
}

deadcheck () {
	for aliveship in ${aliveships[@]}; do
		isdead=true
		for coords in ${ships[$aliveship]};do
			[[ ${battlefield[$coords]} = 1 ]] && isdead=false && break
		done
		if [[ $isdead = true ]]; then
			for deadcoords in ${ships[$aliveship]}; do
				battlefield[$deadcoords]='dead'
				printf "\33[%d;%dH%s" "$((3+2*(${deadcoords:2:1}-1)))" "$((3+4*(${deadcoords:0:1}-1)))" "†"
			done
			aliveships=( "${aliveships[@]/$aliveship}" )
			break
		fi
	done
}
#=====	Game			=====

carriageup
sed -n -e 1,21p battleships.txt && printf "\33[%d;%dH%s" "21" "38" "$attemptsleft"
for theshipsize in {1..5}; do
	printf "\33[%d;%dH%s" "$((5+2*($theshipsize-1)))" "58" "${shipsize[$theshipsize]}"
done
#the field is print, now the game loop
while [ $attemptsleft -ne 0 ]; do
	getshotcoords
	shoot
	deadcheck
	foundalive=0
	for anyfield in ${battlefield[@]}; do
		[[ $anyfield = 1 ]] && foundalive=1
	done
	[[ $foundalive = 0 ]] && victory=true && attemptsleft=0
done

if [[ $victory = true ]]; then
	carriageup
	sed -n -e 22,43p battleships.txt
	read -p "[ press enter to exit ]"
else
	for aliveship in ${aliveships[@]}; do
		for coords in ${ships[$aliveship]};do
			printf "\33[%d;%dH%s" "$((3+2*(${coords:2:1}-1)))" "$((3+4*(${coords:0:1}-1)))" "■"
		done
	done
	printf "\33[%d;%dH%s" "22" "0"
	read -p "[ press enter to exit ]"
fi

popd > /dev/null #leave script directory (noecho)
tput rmcup #yeets battleships and restores terminal
