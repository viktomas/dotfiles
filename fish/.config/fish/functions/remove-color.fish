# https://stackoverflow.com/questions/17998978/removing-colors-from-output
function remove-color --wraps=gsed\ -r\ \"s/\\x1B\\\[\(\[0-9\]\{1,3\}\(\;\[0-9\]\{1,3\}\)\*\)\?\[mGK\]//g\" --description alias\ remove-color\ gsed\ -r\ \"s/\\x1B\\\[\(\[0-9\]\{1,3\}\(\;\[0-9\]\{1,3\}\)\*\)\?\[mGK\]//g\"
  gsed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" $argv
        
end
