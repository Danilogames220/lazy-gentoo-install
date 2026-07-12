function multi_pipe() {
	while read -r a; do
		printf "%s" "$a" | $1
	done 
}

#aaa=$(cat <<END | mp2  iwctl
#three
#three
#END
#)

#cat <<END | mp2 iwctl
#three
#three
#END

printf "a
b
c
" | multi_pipe iwctl
#multi_pipe iwctl "$aaa"


