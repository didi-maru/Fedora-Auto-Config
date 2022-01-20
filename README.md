# Fedora Auto Configuration Tool

A BASH script for automatically configuring a fresh Fedora installation.

**Everything is highly custom**, if you find this repo and want to give it a try **I highly suggest to read the script before using it**.

## Usage

On a fresh installation of Fedora, open a terminal and enter the following commands: 
```
git clone https://github.com/didi-maru/Fedora-Auto-Config.git
cd Fedora-Auto-Config
./Fedora-auto-config.sh --all
```
You will be prompted for to accept or skip each actions.
You can however use `Fedora-Auto-Config/Fedora-auto-config.sh --all --yes` to automatically accept all actions.

## Help

```console
./Fedora-auto-config.sh OPTION_1 [OPTION_2 ...]
```
| Option                 | Effect |
|------------------------|--------|
| -a, --all              | do all actions |
| -p, --post-install     | do actions recommended after a Fedora install |
| -t, --theme            | install gnome theme, icon theme, GRUB theme and tweak some cosmetical Gnome-shell parameters |
| -e, --gnome-extensions | install gnome extensions and set them up |
| -c, --coding           | install VScode, fish shell and other terminal utilities |
| -d, --dot-files        | install chezmoi and retrieve dotfiles |
| -y, --yes              | automatically answer yes to recommended prompts, and add -y flag to dnf commands |
| -h, --help             | display this help page |


Use `Fedora-auto-config.sh --help` to display this help page:
