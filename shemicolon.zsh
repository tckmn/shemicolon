#!/bin/zsh

set -e

data="${XDG_DATA_HOME:-"$HOME/.local/share"}/shemicolon"
mkdir -p "$data"

mode=

typeset -gA git_data=(
    a   add
    b   branch
    bi  bisect
    bl  blame
    c   commit
    cp  cherry-pick
    cl  clean
    cn  clone
    d   diff
    dt  difftool
    f   fetch
    i   init
    k   checkout
    l   log
    m   merge
    r   rm
    rb  rebase
    rs  reset
    rv  revert
    rm  remote
    s   status
    st  stash
    p   push
    pu  pull
    pl  pull
)

# Set the ZLE buffer to a string and place the cursor at the end of the line.
bufset() {
    BUFFER="$1"
    CURSOR=$#BUFFER
}

# Append a string to the ZLE buffer and place the cursor at the end of the line.
bufapp() {
    BUFFER="$BUFFER$1"
    CURSOR=$#BUFFER
}

# This function is called for every key pressed in the shell, with the
# exception of tab.
#
# It should return success if the key was not processed and failure if the key
# is to be ignored (due to having been handled here).
process_key() {

    # Semicolon at the start of the line should immediately put us in "waiting
    # for command" mode.
    if [[ "$KEYS" == ';' && -z "$BUFFER" ]]
    then
        mode=waiting
        return 1
    fi

    # We want to abort everything if ^C or ^J is pressed. Unfortunately, ^C is
    # too aborty and doesn't ever reach this function. So we do it the ugly
    # hack way: if the buffer is empty, we must have started a new buffer.
    if [[ -z "$BUFFER" && $mode != waiting ]]
    then
        mode=
        return 0
    fi

    # We will handle keys differently depending on what mode we're currently in.
    case $mode in

        waiting)
            case $KEYS in
                g)
                    mode=git-
                    bufset 'git '
                    return 1
                    ;;
                m)
                    mode=
                    bufset "mkdir $(date +%F)_"
                    return 1
                    ;;
                j)
                    mode=jump-
                    bufset 'cd '
                    return 1
                    ;;
                c)
                    mode=
                    bufset "$(grep "^$(pwd) " $data/compile | tail -1 | cut -d' ' -f2-)"
                    zle accept-line
                    return 1
                    ;;
                x)
                    mode=compile-wait
                    bufset ">>$data/compile printf '$PWD %s\n' "
                    return 1
                    ;;
            esac
            ;;

        git-*)
            case $KEYS in
                [a-z])
                    mode=$mode$KEYS
                    bufset "git ${git_data[${mode#git-}]}"
                    return 1
                    ;;
                -)
                    mode=
                    bufapp ' -'
                    zle expand-or-complete
                    return 1
                    ;;
            esac
            ;;

        jump-*)
            case $KEYS in
                [a-zA-Z])
                    mode=$mode$KEYS
                    result="$(grep "^${mode#jump-} " $data/jumplist | tail -1 | cut -d' ' -f2-)"
                    if [ -n "$result" ]
                    then
                        bufset "cd $(printf '%q' "$result")"
                        zle accept-line
                        return 1
                    fi
                    return 0
                    ;;
                +)
                    mode=
                    bufset ">>$data/jumplist printf '%s $PWD\n' "
                    return 1
                    ;;
                \*)
                    mode=
                    bufset "${EDITOR:-vi} $data/jumplist"
                    zle accept-line
                    return 1
                    ;;
            esac
            ;;

        compile-wait)
            case $KEYS in
                \*)
                    mode=
                    bufset "${EDITOR:-vi} $data/compile"
                    zle accept-line
                    return 1
                    ;;
            esac

    esac

    mode=
    return 0

}

# Feed everything through the process_key function except for tab completion
# and the weird thing zsh does for manpages.
for binding in $(bindkey | awk '{print $NF}' | sort -u \
    | grep -v 'complete\|run-help\|which-command')
do
    eval "$binding"'() {
        process_key && zle .'"$binding"'
    }'
    zle -N $binding
done

set +e
