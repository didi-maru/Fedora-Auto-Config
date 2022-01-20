#!/bin/bash
#
# Fedora auto configuration script


# Parsing arguments
while [ $# -gt 0 ]; do
  key="$1"

  case $key in
    -a|--all)
        POST_INSTALL=true
        THEME=true
        GNOME_EXTENSIONS=true
        CODING=true
        DOT_FILES=true
        shift;;
    -p|--post-install)
        POST_INSTALL=true
        shift;;
    -t|--theme)
        THEME=true
        shift;;
    -e|--gnome-extensions)
        GNOME_EXTENSIONS=true
        shift;;
    -c|--coding)
        CODING=true
        shift;;
    -d|--dot-files)
        DOT_FILES=true
        shift;;
    -y|--yes)
        YES=true
        shift;;
    -v|--verbose)
        VERBOSE=true
        shift;;
    -h|--help)
        HELP=true
        shift;;
  esac
done

# Display help section
if [ $HELP ]; then
    echo "Usage:"
    echo "  $0 OPTION_1 [OPTION_2 ...]"
    echo
    echo "OPTIONS:"
    echo "-a, --all                do all actions"
    echo "-p, --post-install       do actions recommended after a Fedora install"
    echo "-t, --theme              install gnome theme, icon theme, GRUB theme and tweak some cosmetical Gnome-shell parameters"
    echo "-e, --gnome-extensions   install gnome extensions and set them up"
    echo "-c, --coding             install vscode, fish shell and other terminal utilities"
    echo "-d, --dot-files          install chezmoi and retrieve dotfiles"
    echo "-y, --yes                automatically answer yes to recommended prompts, and add -y flag to dnf commands"
    # echo "-v, --verbose            increase verbose level"
    echo "-h, --help               display this help page"
    exit 0
fi

if ! [ $POST_INSTALL ] &&
   ! [ $THEME ] &&
   ! [ $GNOME_EXTENSIONS ] &&
   ! [ $CODING ] &&
   ! [ $DOT_FILES ]; then
    echo "Nothing to do, use './Fedora-auto-config.sh --help' for help."
    exit 1
fi


# Prepare for execution

# Get the absolute path where this script locate
DIR="$(cd $(dirname $0); pwd)"

# Loading utility functions
. ${DIR}/utils.sh

# Checking if user is root
if [ "$(whoami)" = "root" ]; then
    echo "$(red '[error] This script is not expected to be runned as root, exiting now.')"
    exit 1
fi

# Creating log file
LOG_FILE="${DIR}/log.txt"
printf "" > ${LOG_FILE}

# Creating a work directory 
cd /tmp
WORK_DIR=$(mktemp -d)

[ $YES ] && DNF_YES="-y"

exit 0

########################################


add_rpmfusion() {
    run sudo dnf install "$DNF_YES" https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    run sudo dnf install "$DNF_YES" https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
}

install_gnome_deps() {
    run sudo dnf install "$DNF_YES" gnome-tweaks
}

install_gnome_extensions_deps() {
    run sudo dnf install "$DNF_YES" gnome-tweaks gnome-extensions-app
    cd $work_dir
    run wget -O gnome-shell-extension-installer "https://github.com/brunelli/gnome-shell-extension-installer/raw/master/gnome-shell-extension-installer"
    run chmod +x gnome-shell-extension-installer
    run mv -v gnome-shell-extension-installer "${HOME}/.local/bin"
}


# Post install actions
if [ $POST_INSTALL ]; then

    title; echo "Post installation actions for Fedora:"

    # Detect Nvidia GPU
    if lspci | grep -E "VGA|3D" | grep -qi nvidia; then
        has_nvidia_gpu=true
        echo "Nvidia GPU détected."
    fi

    # Tweak dnf congiguration
    if $(yn_prompt "Tweak dnf configuration ?" Y); then
        run sudo setconf /etc/dnf/dnf.conf fastestmirror True
        run sudo setconf /etc/dnf/dnf.conf max_parallel_downloads 10
    fi

    # Update the system
    if $(yn_prompt "Update the system ?" Y); then
        run sudo dnf upgrade --refresh "$DNF_YES"
    fi

    # Install RPM Fusion repositories
    if $(yn_prompt "Install RPM Fusion repositories ?" Y); then
        add_rpmfusion && RPM_FUSION=true
    fi
    
    # Install Nvidia drivers
    if [ $has_nvidia_gpu ]; then

        msg="Install Nvidia drivers"
        ! [ $RPM_FUSION ] && msg="$msg (will install RPM Fusion repositories)"

        if $(yn_prompt "$msg ?" Y); then
            ! [ $RPM_FUSION ] && add_rpmfusion && RPM_FUSION=true

            run sudo dnf install "$DNF_YES" dnf-plugins-core akmod-nvidia xorg-x11-drv-nvidia-cuda

            if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist.conf; then
                echo "Mise en blacklist de \"nouveau\""
                run sudo echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
            fi

            if grep -E "GRUB_CMDLINE_LINUX *= *\".*rd.driver.blacklist=nouveau.*\"" /etc/default/grub; then
                echo "Ajout de l'option \"rd.driver.blacklist=nouveau\" à \"GRUB_CMDLINE_LINUX\" dans /etc/default/grub"
                run sudo sed -c -i "s/\(GRUB_CMDLINE_LINUX *= *\".*\)\"/\1 rd.driver.blacklist=nouveau\"/" /etc/default/grub
            fi

            UPDATE_GRUB=true
        fi
    fi

    # Install media codecs and VLC
    msg="Install media codecs and VLC"
    ! [ $RPM_FUSION ] && msg="$msg (will install RPM Fusion repositories)"

    if $(yn_prompt "$msg ?" Y); then
        ! [ $RPM_FUSION ] && add_rpmfusion && RPM_FUSION=true

        run sudo dnf "$DNF_YES" gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel
        run sudo dnf "$DNF_YES" lame\* --exclude=lame-devel
        run sudo dnf group upgrade "$DNF_YES" --with-optional Multimedia
        run sudo dnf "$DNF_YES" vlc
    fi

    # Install archive manipulation applications 
    if $(yn_prompt "  Install archive manipulation applications ?" Y); then
        run sudo dnf install "$DNF_YES" unzip unrar p7zip file-roller-nautilus
    fi

fi # Post install actions


# Themes
if [ $THEME ]; then

    title; echo "Themes installation:"

    . themes.sh

    # Install GTK theme
    if $(yn_prompt "Install Catppuccin GTK theme ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps && GNOME_DEPS=true
        run sudo dnf install "$DNF_YES" gnome-shell-extension-user-theme
        install_catppuccin_theme
    done

    fi

    # Install icons theme
    if $(yn_prompt "Install Fluent icons theme ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps && GNOME_DEPS=true
        install_fluent_icon_theme
    fi

    # Install sleek Grub bootloader theme
    if $(yn_prompt "Install sleek Grub bootloader theme ?" Y); then
        cd $WORK_DIR
        run git clone https://github.com/sandesh236/sleek--themes.git
        run cd "sleek--themes/Sleek theme-dark"

        THEME_DIR="/boot/grub2/themes"
        THEME_NAME="sleek"

        [ -d ${THEME_DIR}/${THEME_NAME} ] && run sudo rm -rf "${THEME_DIR}/${THEME_NAME}"
        run sudo mkdir -p ${THEME_DIR}/${THEME_NAME}

        run sudo cp -a ${THEME_NAME}/* ${THEME_DIR}/${THEME_NAME}
        
        username=${SUDO_USER^}
        run sudo sed -ci "s/Grub Bootloader/Salut $username,/"  $THEME_DIR/$THEME_NAME/theme.txt
        run sudo sed -ci "s/select your preferred os/choisi un OS pour démarrer/"  $THEME_DIR/$THEME_NAME/theme.txt

        run sudo sed -ci "s/\(^GRUB_TERMINAL_OUTPUT *= *\"console\"\)/# \1/" /etc/default/grub
        run sudo setconf /etc/default/grub GRUB_THEME "${THEME_DIR}/${THEME_NAME}/theme.txt"

        UPDATE_GRUB=true
    fi

    # Do some additional tweaks
    if $(yn_prompt "Install Mutter-rounded ? (Compilation can take some time) " Y); then
        run sudo dnf install wayland-protocols-devel
        run cd $work_dir
        run git clone https://github.com/yilozt/mutter-rounded.git
        run cd mutter-rounded/fedora_35
        run ./package.sh

        run cd ~/rpmbuild/RPMS/x86_64/
        PACKAGE_NAME=$( ls | grep -E -m 1 "mutter-[0-9].*.x86_64.rpm" )
        run sudo dnf upgrade mutter
        run sudo rpm --reinstall "$PACKAGE_NAME"

        run gsettings set org.gnome.mutter round-corners-radius 18

        run cd $work_dir
        run git clone https://github.com/yilozt/mutter-rounded-setting.git
        run cd mutter-rounded-setting
        run ./install

        run cd ../
        run mv "mutter-rounded-setting" "$HOME/.local/share/"
    fi

    # Do some additional tweaks
    if $(yn_prompt "Do some additional tweaks ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps 2>&1 | verb "Installing dependencies" && GNOME_DEPS=true
        # -- Apparency --- #
        run gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
        run gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
        run gsettings set org.gnome.desktop.interface show-battery-percentage true
        run gsettings set org.gnome.desktop.interface clock-show-weekday true

        # -- Apps --- #
        run gsettings set org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']"
        run gsettings set org.gnome.desktop.search-providers sort-order "['org.gnome.Contacts.desktop', 'org.gnome.Documents.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Calculator.desktop', 'firefox.desktop', 'org.gnome.clocks.desktop', 'org.gnome.Software.desktop', 'org.gnome.Boxes.desktop', 'org.gnome.Weather.desktop', 'org.gnome.Photos.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Characters.desktop']"
        
        # --- Key-binding --- #
        # launchers
        run gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>f']"
        run gsettings set org.gnome.settings-daemon.plugins.media-keys www "['<Super>b']"
        run gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "['<Super>i']"

        # Navigation
        run gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-down "['<Shift><Super>Down']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "['<Shift><Super>Left']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "['<Shift><Super>Right']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-up "['<Shift><Super>Up']"

        run gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['<Primary><Super>Down']"
        run gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Primary><Super>Left']"
        run gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['<Primary><Super>Up']"
        run gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Primary><Super>Right']"

        run gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-down "['<Alt><Super>Down']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-left "['<Alt><Super>Left']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-right "['<Alt><Super>Right']"
        run gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-up "['<Alt><Super>Up']"

        run gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']"
        run gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>m']"

        # System
        run gsettings set org.gnome.shell.keybindings toggle-message-tray "[]"
        run gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "[]"
    fi

fi # Themes


# Gnome extensions
if [ $GNOME_EXTENSIONS ]; then
    
    title; echo "GNOME extensions installation and configuration:"

    # Install Blur my Shell GNOME extension
    if $(yn_prompt "Install Blur my Shell GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
        run gnome-shell-extension-installer 3193 --update --yes
        SETUP_BLUR_MY_SHELL=true
        RESTART_GNOME_SHELL=true
    fi

    # Install UI Tune GNOME extension
    if $(yn_prompt "Install UI Tune GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
        run gnome-shell-extension-installer 4158 --update --yes
        SETUP_UI_TUNE=true
        RESTART_GNOME_SHELL=true
    fi

    # Install Forge GNOME extension
    if $(yn_prompt "Install Tiling Assistant GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
        run gnome-shell-extension-installer 4481 --update --yes
        SETUP_FORGE=true
        RESTART_GNOME_SHELL=true
    else

        # Install Tiling Assistant GNOME extension
        if $(yn_prompt "Install Tiling Assistant GNOME extension ?" N); then
            ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
            run gnome-shell-extension-installer 3733 --update --yes
            SETUP_TILING_ASSISTANT=true
            RESTART_GNOME_SHELL=true
        fi

    fi

    # Install Vitals GNOME extension
    if $(yn_prompt "Install Vitals GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
        run gnome-shell-extension-installer 1460 --update --yes
        SETUP_VITALS=true
        RESTART_GNOME_SHELL=true
    fi

    # Install ddterm GNOME extension
    if $(yn_prompt "Install ddterm GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps && GNOME_EXT_DEPS=true
        run gnome-shell-extension-installer 3780 --update --yes
        SETUP_DDTERM=true
        RESTART_GNOME_SHELL=true
    fi

    # Restart GNOME Shell
    if [ $RESTART_GNOME_SHELL ]; then
        echo
        echo -e "\033[1mPlease restart GNOME Shell to continue:\033[0m"
        echo -e "Press \033[1malt + f2\033[0m, type '\033[1mr\033[0m' then press \033[1mEnter\033[0m."
        read -p "Once GNOME Shell has restarted, press Enter "
    fi

    USER_EXTENSIONS_DIR="${HOME}/.local/share/gnome-shell/extensions/"
    
    # Setup Blur my Shell GNOME extension
    if [ $SETUP_BLUR_MY_SHELL ]; then
        uuid="blur-my-shell@aunetx"
        run gnome-extensions enable ${uuid}
    fi

    # Setup ddterm GNOME extension
    if [ $SETUP_DDTERM ]; then
        uuid="ddterm@amezin.github.com"
        run gnome-extensions enable ${uuid}
    fi

    # Setup UI Tune GNOME extension
    if [ $SETUP_UI_TUNE ]; then
        uuid="gnome-ui-tune@itstime.tech"
        run gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.gnome-ui-tune"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"
        run gsettings --schemadir ${schema_dir} set ${schema_name} hide-search false
        run gsettings --schemadir ${schema_dir} set ${schema_name} increase-thumbnails-size true
        run gsettings --schemadir ${schema_dir} set ${schema_name} restore-thumbnails-background true
        run gsettings --schemadir ${schema_dir} set ${schema_name} always-show-thumbnails false
        run gsettings --schemadir ${schema_dir} set ${schema_name} overview-firefox-pip true
    fi

    # Setup Tiling Assistant GNOME extension
    if [ $SETUP_TILING_ASSISTANT ]; then
        uuid="tiling-assistant@leleat-on-github"
        run gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.tiling-assistant"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"

        # --- Settings --- #
        run gsettings --schemadir ${schema_dir} set ${schema_name} enable-tiling-popup true
        run gsettings --schemadir ${schema_dir} set ${schema_name} enable-raise-tile-group false
        run gsettings --schemadir ${schema_dir} set ${schema_name} enable-hold-maximize-inverse-portrait false
        run gsettings --schemadir ${schema_dir} set ${schema_name} enable-hold-maximize-inverse-landscape false
        run gsettings --schemadir ${schema_dir} set ${schema_name} tiling-popup-all-workspace false
        run gsettings --schemadir ${schema_dir} set ${schema_name} screen-gap 8
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-gap 8
        # SETTING maximize-with-gap CURRENTLY BUGGED
        run gsettings --schemadir ${schema_dir} set ${schema_name} maximize-with-gap false #true 
        run gsettings --schemadir ${schema_dir} set ${schema_name} dynamic-keybinding-behaviour "'Window Focus'"

        # --- Key-binding --- #
        # Unassign built-in key-bindings
        run gsettings set org.gnome.desktop.wm.keybindings maximize "[]"
        run gsettings set org.gnome.desktop.wm.keybindings unmaximize "[]"
        run gsettings set org.gnome.mutter.keybindings toggle-tiled-left "[]"
        run gsettings set org.gnome.desktop.wm.keybindings toggle-tiled-right "[]"
        # Assign Tiling Assistant key-binding
        run gsettings --schemadir ${schema_dir} set ${schema_name} tile-maximize "['<Super>m']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} tile-right-half "['<Super>Right']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} tile-left-half "['<Super>Left']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} tile-top-half "['<Super>Up']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} tile-bottom-half "['<Super>Down']"
    fi

    # Setup Forge GNOME extension
    if [ $SETUP_FORGE ]; then
        uuid="forge@jmmaranan.com"
        run gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.forge.keybindings"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"

        run gsettings --schemadir ${schema_dir} set ${schema_name} prefs-tiling-toggle "['<Shift><Super>z']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} workspace-active-tile-toggle "['<Super>z']"

        run gsettings --schemadir ${schema_dir} set ${schema_name} con-split-layout-toggle "['<Super>o']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} con-split-horizontal "['<Super>h']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} con-split-vertical "['<Super>v']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-toggle-float "['<Super>c']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} con-tabbed-layout-toggle "['<Shift><Super>t']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} con-stacked-layout-toggle "['<Shift><Super>s']"

        run gsettings --schemadir ${schema_dir} set ${schema_name} window-focus-left "['<Super>Left']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-focus-down "['<Super>Down']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-focus-right "['<Super>Right']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-focus-up "['<Super>Up']"

        run gsettings --schemadir ${schema_dir} set ${schema_name} window-move-left "['<Control><Alt>Left']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-move-down "['<Control><Alt>Down']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-move-right "['<Control><Alt>Right']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-move-up "['<Control><Alt>Up']"

        run gsettings --schemadir ${schema_dir} set ${schema_name} window-swap-left "['<Shift><Control><Alt>Left']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-swap-down "['<Shift><Control><Alt>Down']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-swap-right "['<Shift><Control><Alt>Right']"
        run gsettings --schemadir ${schema_dir} set ${schema_name} window-swap-up "['<Shift><Control><Alt>Up']"
    fi

    # Setup Vitals GNOME extension
    if [ $SETUP_VITALS ]; then
        uuid="Vitals@CoreCoding.com"
        run gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.vitals"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-temperature true
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-voltage false
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-fan true
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-memory true
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-processor true
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-storage false
        run gsettings --schemadir ${schema_dir} set ${schema_name} use-higher-precision false
        run gsettings --schemadir ${schema_dir} set ${schema_name} hide-zeros false
        run gsettings --schemadir ${schema_dir} set ${schema_name} include-public-ip false
        run gsettings --schemadir ${schema_dir} set ${schema_name} show-battery true
        run gsettings --schemadir ${schema_dir} set ${schema_name} fixed-widths false
        run gsettings --schemadir ${schema_dir} set ${schema_name} hide-icons false
    fi

fi # Gnome extensions


# Coding
if [ $CODING ]; then

    title; echo "Coding related installation and configuration:"
    
    # Install VSCodium
    if $(yn_prompt "  Install VSCodium ?" Y); then
        run sudo rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg 
        run sudo printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg" | tee -a /etc/yum.repos.d/vscodium.repo
        run sudo dnf install "$DNF_YES" codium
    fi

    # Install micro
    if $(yn_prompt "  Install micro ?" Y); then
        run dnf install "$DNF_YES" micro xclip 2>&1 | verb "Installing micro"
    fi

    # Install Fish Shell
    if $(yn_prompt "  Install Fish Shell ?" Y); then
        run dnf insatll -y exa
        run dnf install -y fish
        run chsh -s /usr/bin/fish

        run fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
        run fish -c "fisher install catppuccin/fish"
        run fish -c "fisher install IlanCosman/tide@v5"
        run fish -c "fisher install jorgebucaran/replay.fish"
        run fish -c "fisher install jorgebucaran/autopair.fish"
        run fish -c "gazorby/fish-abbreviation-tips"
        run fish -c "fisher install gazorby/fish-exa"

        FISH_INSTALLED=true
    fi

    # Install Meslo font
    if $(yn_prompt "  Install Meslo font ?" Y); then
        cd $WORK_DIR
        run curl -fLo Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip
        run sudo mkdir -pv /usr/share/fonts/Meslo
        run sudo unzip Meslo.zip -d /usr/share/fonts/Meslo/
        run fc-cache -f -v
    fi

fi # Coding


# dot files
if [ $DOT_FILES ]; then

    title; echo "dot files retrieval:"

    # Install chezmoi and retrieve dot files
    if $(yn_prompt "  Install chezmoi and retrieve dot files ?" Y); then
        run mkdir -p "${USER_HOME}/.local/bin"
        run BINDIR="${USER_HOME}/.local/bin" sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply "didi-maru"
        
        if [ $FISH_INSTALLED ]; then
            run fish -c "import_tide_config"
        fi

        # Get default profile ID
        profile="$(my_gsettings get org.gnome.Terminal.ProfilesList default)"
        profile="${profile:1:-1}" # remove leading and trailing single quotes
        run dconf load "/org/gnome/terminal/legacy/profiles:/:$profile/" < "${USER_HOME}/gnome-terminal-profile.dconf"
    fi 

fi # dot files


# Update grub if necessary
if [ $UPDATE_GRUB ]; then
    if [ -d "/sys/firmware/efi" ]; then
        run sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
    else
        run sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
fi # Update grub


########################################

title; echo "Configuration finished"

echo "Removing work directory ${WORK_DIR}"
run rm -rf "${WORK_DIR}"

exit 0
