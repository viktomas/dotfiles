function httpserver --wraps='python3 -m http.server' --description 'alias httpserver=python3 -m http.server'
  python3 -m http.server $argv; 
end
