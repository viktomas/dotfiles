function git --wraps=git --description 'sets a special behaviour for git wta'
    if test "$argv[1]" = wta
        if test "$argv[2]" = -n
            set -l name $argv[3]
            set -l date_prefix (date +%Y-%m)
            set -l branch "tv/$date_prefix/$name"
            command git fetch origin main
            and ~/bin/git-wa.sh $name -b $branch --no-track origin/main
            and cd $name
        else
            ~/bin/git-wa.sh $argv[2..-1]
            and cd $argv[2]
        end
    else
        command git $argv
    end
end
