function la --wraps=ls --wraps='exa -laF' --description 'alias la exa -laF'
  exa -laF $argv; 
end
