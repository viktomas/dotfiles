# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/): each top-level
directory is a package that mirrors the home directory. Running `stow <package>`
from the repo root symlinks its files into `~`.

Examples:
- `fish/.config/fish/config.fish` → `~/.config/fish/config.fish`
- `ghostty/.config/ghostty/config.ghostty` → `~/.config/ghostty/config.ghostty`
- `pi/.pi/agent/settings.json` → `~/.pi/agent/settings.json`

To add a package: create a directory named after the tool, mirror the file's
path relative to `~` inside it, then add `stow <name>` to `install.sh`.

## Install (Ubuntu)

1. `sudo apt install git`
1. `git clone https://github.com/viktomas/dotfiles.git ~/.dotfiles`
1. `cd ~/.dotfiles`
1. `./ubuntu-install-basic.sh`
1. `./install.sh`

## Per-tool docs

Each tool's setup and notes live in its own package README:

| Tool | Doc |
|---|---|
| Keyboard mapping (kanata: HRM, symbol layer, tab chords) | `kanata/README.md` |
| Karabiner DriverKit driver (kanata's HID dependency) | `karabiner/README.md` |
| Neovim (plugins via `vim.pack`, Fennel LSP) | `nvim/README.md` |
| Ghostty terminal + tab switching | `ghostty/README.md` |
| Fish shell | `fish/README.md` |
| pi & qmd (global npm tools via mise) | `pi/README.md` |

Repo-wide conventions are in `AGENTS.md`.

## Bin

It's a good idea to start all the scripts with a comma, so I can easily
autocomplete only my personal commands —
https://rhodesmill.org/brandon/2009/commands-with-comma/ .

## Crontab

Edit crontab by running `./bin/edit-crontab.sh`.

## Git

- Configured to use a different `.gitconfig` for work and private repos based on
  [How to use different git emails](https://blog.hao.dev/how-to-use-different-git-emails-for-personal-and-work-repositories-on-the-same-machine).

## Mac-specific setup

### Resize screenshots and add them to clipboard

Run the following script step by step to set up automatic screenshot resizing:

```sh
# Install imagemagick
brew install imagemagick

# Resize to 50%
# Source https://legacy.imagemagick.org/Usage/resize/
convert original.png -resize 50% resized.png

# install color quantifier
brew install pngquant

# Quantize 32-bit RGBA PNG to 8-bit (or smaller) RGBA-palette
# pngquant [number of colors] [options] input.png
#   --skip-if-larger  only save converted file if they're smaller than original
#   --strip           remove optional metadata
#   --ext=.png        set output filename to be same as input filename
#   --force           overwrite existing output files
pngquant 256 --skip-if-larger --strip --ext=.png --force example.png


# Install zopfli using Homebrew, which includes zopflipng
brew install zopfli

# Optimize PNG compression
# zopflipng [options] input.png output.png
#   -y  do not ask about overwriting files
zopflipng -y example.png example.png

# Create a Screenshots directory in the current users Home directory
mkdir -p "$HOME/Screenshots"

# Configure macOS to capture screenshots to this location
# If you want to revert this change, and save screenshots to your desktop,
# instead use "$HOME/Desktop"
defaults write com.apple.screencapture location "$HOME/Screenshots"

# Create new folder action in Mac automator, set it to Screenshots folder and add
# "Run Shell Script block"
# set it to /bin/zsh shell
# select "pass input" as arguments
# and add

for f in "$@"
do
  /usr/local/bin/convert "$f" -resize 50% "$f"
  /usr/local/bin/pngquant 64 --skip-if-larger --strip --ext=.png --force "$f"
  /usr/local/bin/zopflipng -y "$f" "$f"
  osascript -e "set the clipboard to (read (POSIX file \"$(readlink -f "$f")\") as {«class PNGf»})"
done
```

Inspired by [One simple trick to make your screenshots 80% smaller | GitLab](https://about.gitlab.com/blog/2020/01/30/simple-trick-for-smaller-screenshots/)

- Now you can run <kbd>CMD</kbd> + <kbd>Shift</kbd> + <kbd>4</kbd> and use <kbd>spacebar</kbd> to switch between crosshair and whole app snapshot
- You can also remove app window shadow by holding <kbd>option</kbd>
