function god --wraps='godu -print0 | xargs -0 rm -rf' --description 'alias god godu -print0 | xargs -0 rm -rf'
  godu -print0 | xargs -0 rm -rf $argv
        
end
