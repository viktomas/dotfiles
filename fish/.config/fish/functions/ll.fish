function ll --wraps=ls --wraps='eza -lF' --description 'alias ll eza -lF --time-style iso'
  eza -lF --time-style iso $argv; 
end
