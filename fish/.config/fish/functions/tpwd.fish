function tpwd --wraps='task set cwd (pwd)' --description 'alias tpwd=task set cwd (pwd)'
    task set cwd (pwd) $argv
end
