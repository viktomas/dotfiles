function cal --wraps='/opt/homebrew/opt/util-linux/bin/cal' --description 'cal with Monday as first day by default'
  /opt/homebrew/opt/util-linux/bin/cal -m $argv
end
