function ll --wraps=ls --wraps='eza -lF' --description 'alias ll eza -lF'
  eza -lF $argv; 
end
