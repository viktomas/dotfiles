function lt --wraps='ls -lhtmodified' --wraps='exa --long --sort=modified --reverse' --description 'alias lt=exa --long --sort=modified --reverse'
  exa --long --sort=modified --reverse $argv; 
end
