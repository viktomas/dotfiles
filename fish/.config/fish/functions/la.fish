function la --wraps=ls --wraps='eza -laF' --description 'alias la eza -laF --type-style iso'
  eza -laF --time-style iso $argv; 
end
