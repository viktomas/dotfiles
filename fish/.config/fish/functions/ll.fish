function ll --wraps=ls --wraps='exa -lF' --description 'alias ll exa -lF'
  exa -lF $argv; 
end
