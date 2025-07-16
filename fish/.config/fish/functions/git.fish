function git --wraps=git --description 'sets a special behaviour for git wta'
    if test "$argv[1]" = wta
        ~/bin/git-wa.sh $argv[2..-1]
        and cd $argv[2]
    else
        command git $argv
    end
end
