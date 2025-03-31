function vim --wraps=nvim --description 'alias vim=nvim'
  # this will get the group id of last suspended job
  set -f existing_nvim_group_id (jobs | grep 'nvim' | awk '{print $2}' | head --lines 1)
  if test -n "$existing_nvim_group_id"
    if test -n "$argv"
      echo 'There is a supspended nvim instance, I will start that and ignore your params. Press [Enter] to continue.'
      read # wait for user confirmation
    end
    fg $existing_nvim_group_id
  else
    nvim $argv;
  end
end
