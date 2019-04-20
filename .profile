
export PATH="$PATH:$HOME/workspace/bin" # Add workspace bin to the path

export GOPATH="$HOME/workspace/go"

export PATH="$PATH:$GOPATH/bin"

export GO111MODULE=on

export HISTSIZE=1000000
export HISTFILE=~/.histfile
export SAVEHIST=10000

export EDITOR=nvim

alias dc=docker-compose

xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Profile Enabled' 0, 1
xinput --set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' 1
