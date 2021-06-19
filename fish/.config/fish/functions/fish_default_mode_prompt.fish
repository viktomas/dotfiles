function fish_default_mode_prompt
  switch $fish_bind_mode
    case default
      set_color --bold green
      echo -n '❮'
      set_color --bold yellow
      echo -n '❮'
      set_color --bold red
      echo -n '❮'
    case insert
      set_color --bold red
      echo -n '❯'
      set_color --bold yellow
      echo -n '❯'
      set_color --bold green
      echo -n '❯'
    case replace_one
      set_color --bold green
      echo -n '❮'
      set_color --bold yellow
      echo -n 'R'
      set_color --bold red
      echo -n '❮'
    case visual
      set_color --bold green
      echo -n '❮'
      set_color --bold yellow
      echo -n 'V'
      set_color --bold red
      echo -n '❮'
      set_color --bold green
    case '*'
      set_color --bold red
      echo '?'
  end
  set_color normal
end
