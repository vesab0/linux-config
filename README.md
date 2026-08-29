# linux-config

My Hyprland setup on Arch.

Compositor is Hyprland (Lua config), and the bar/launcher/notifications all come
from DankMaterialShell (`dms-shell`) running on quickshell. Login is greetd with
the DMS greeter, terminal is ghostty, editor is neovim (LazyVim), shell is zsh
+ starship. Colours are generated from the wallpaper with matugen and pywal

Plasma is installed but unused; ignore the KDE files.

## Setting it up on a new machine

Check the repo out over `~/.config` in place so existing untracked files survive:

```sh
cd ~/.config
git init
git remote add origin https://github.com/vesab0/linux-config
git fetch origin
git checkout -f -b main origin/main
```

Then run `./install.sh`. It installs paru and the package lists, oh-my-zsh, links
`home/.zshrc` and `home/.bashrc` into `$HOME`, copies the dms-shell overrides into
`/usr/share/quickshell/dms/`, enables the services, and offers to swap sddm for
greetd.
