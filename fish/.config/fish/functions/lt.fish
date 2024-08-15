function lt --wraps='ls -lhtmodified' --wraps='eza --long --sort=modified --reverse' --description 'alias lt=eza --long --sort=modified --reverse'
  eza --long --sort=modified --reverse $argv; 
end
