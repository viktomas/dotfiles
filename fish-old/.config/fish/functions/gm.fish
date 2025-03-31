function gm --wraps='godu -print0 | xargs -0 -I _ mv _ ' --description 'alias gm godu -print0 | xargs -0 -I _ mv _ '
  godu -print0 | xargs -0 -I _ mv _  $argv
        
end
