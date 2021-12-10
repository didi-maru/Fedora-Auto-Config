#!/bin/bash
#
# Fedora auto configuration script
#

# Global vars
WIDTH=400

# Parsing arguments
while [ $# -gt 0 ]; do
  key="$1"

  case $key in
    -a|--all)
        POST_INSTALL=true
        THEME=true
        GNOME_EXTENSIONS=true
        CODING=true
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
 
if [ $HELP ]; then
    echo "Usage:"
    echo "  ./Fedora-auto-config.sh OPTION_1 [OPTION_2 ...]"
    echo
    echo "OPTIONS:"
    echo "-a, --all                do all actions, equivalent to -ptec"
    echo "-p, --post-install       do actions recommandedpost Fedora insatallation"
    echo "-t, --theme              install gnome theme, icon theme, GRUB theme and tweak some parameters"
    echo "-e, --gnome-extensions   install gnome extensions and set them up"
    echo "-c, --coding             install vscode and fish shell"
    echo "-d, --dot-files          install chezmoi and retrieve dotfiles"
    echo "-y, --yes                automatically answer yes to recommanded prompts"
    echo "-v, --verbose            display all output in terminal and disable zenity popups"
    echo "-h, --help               display this help"
    exit 0
fi

if ! [ $POST_INSTALL ] && ! [ $THEME ] && ! [ $GNOME_EXTENSIONS ] && ! [ $CODING ] && ! [ $DOT_FILES ]; then
    echo "Nothing to do, try './Fedora-auto-config.sh --help' for help."
    exit 0
fi

# Checking if user is root
# if [ "$EUID" -ne 0 ]; then
#     echo "Erreur : Cette commande doit être exécutée avec les privilèges super-utilisateur."
#     exit 1
# fi

USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6) # Get user's home directory
RUID=$(who | awk 'FNR == 1 {print $1}') # Get the Real Username
RUSER_UID=$(id -u ${RUID}) # Translate Real Username to Real User ID
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

title() {
    padding=$(( ( $(tput cols) - 48 ) / 2 ))
    clear
    echo ""
    for i in $(seq 1 $padding); do echo -n ' '; done
    echo -e "\033[1m―――――――  \033[1;34mFedora Auto Configuration Tool\033[0m\033[1m  ―――――――\033[0m"
    echo ""
}

# request language agnostic for [Y/n]
set -- $(locale LC_MESSAGES)
yes_expr="$1"
no_expr="$2";
yes_char="${3::1}"
no_char="${4::1}"

yn_prompt() {
    # Usage: $ yn_prompt MESSAGE [Y|N]

    if [ "${2^}" = "Y" ]; then
        if [ $YES ]; then
            printf "true"
            return
        fi
        local yes_char=${yes_char^}
        local yes_expr="$yes_expr|^$"
    elif [ "${2^}" = "N" ]; then
        local no_char=${no_char^}
        local no_expr="$no_expr|^$"
    fi

    while true; do
        read -p "$1 [$yes_char/$no_char] : "; 
        if [[ $REPLY =~ $yes_expr ]]; then
            printf "true"; break
        elif [[ $REPLY =~ $no_expr ]]; then
            printf "false";break
        fi
    done
}

my_gsettings() {
    # gsetting as SUDO_USER
    sudo -u ${RUID} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${RUSER_UID}/bus" gsettings "${@}"
}

function setconf {
    # Update/create an option in a given configuration file
    # Usage: 
    # - Update a configuration file without sections: $ setconf CONFIG_FILE SETTING_NAME SETTING_VALUE
    # - Update a configuration file with sections:    $ setconf CONFIG_FILE SECTION_NAME SETTING_NAME SETTING_VALUE
    if [ $# = 3 ]; then
        file=$1; key=$2; val=$3
        [ ! -f $file ] && echo "$file not found." && return 1
        if grep -q "^$key *= *" $file; then
            sed -ci "s/\(^$key *= *\).*/\1$val/" $file
        else
        	sed -ci "s/^$/$key=$val\n/" $file
        fi
    elif [ $# = 4 ]; then
        file=$1; sec=$2; key=$3; val=$4
        sed -n "/^\[$2\]$/,/^$/p" $1 | grep -q "$3 *= *"
        grep_status=$?
        if [ $grep_status = 0 ]; then
            sed -ci "/^\[$sec\]$/,/^$/ s/\(^$key *= *\).*/\1$val/" $file
        else
        	sed -ci "s/\(^\[$sec\]$\)/\1\n$key=$val/" $file
    	fi
    else
        echo "Illegal number of arguments."; return 2
    fi
    return 0
}

# Creating log file
LOG_FILE="${SCRIPT_DIR}/log.txt"
sudo -u ${SUDO_USER} printf "" > ${LOG_FILE}

# Verbose function
if [ $VERBOSE ]; then
    verb() {
        echo "    $1"
        printf "[%s]: %s\n" "$(date -u)" "$1" | tee -a ${LOG_FILE} > /dev/null
        tee -a ${LOG_FILE}
        printf "\n\n" | tee -a ${LOG_FILE} > /dev/null
    }
else 
    verb() {
        echo "    $1"
        printf "[%s]: %s\n" "$(date -u)" "$1" | tee -a ${LOG_FILE} > /dev/null
        tee -a ${LOG_FILE} | \
            zenity --progress --pulsate --no-cancel --auto-close \
                   --width=$WIDTH --title="$1" --text "Please wait..."
        printf "\n\n" | tee -a ${LOG_FILE} > /dev/null
    }
fi

# Creating a work directory 
cd /tmp
WORK_DIR=$(sudo -u ${SUDO_USER} mktemp -d)


########################################


add_rpmfusion() {
    dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    dnf update
}
RPM_FUSION=

install_gnome_deps() {
    dnf install -y gnome-tweaks gnome-extensions-app
}
GNOME_DEPS=

install_gnome_extensions_deps() {
    dnf install -y gnome-tweaks gnome-extensions-app
    cd $work_dir
    wget -O gnome-shell-extension-installer "https://github.com/brunelli/gnome-shell-extension-installer/raw/master/gnome-shell-extension-installer"
    chmod +x gnome-shell-extension-installer
    mv -v gnome-shell-extension-installer /usr/bin/
}
GNOME_EXT_DEPS=


# Post install actions
if [ $POST_INSTALL ]; then

    title; echo "Post Installations actions for Fedora:"

    # Detect disk type
    [ $( cat /sys/block/sda/queue/rotational ) = 1 ] && disk_type="HDD" || disk_type="SSD"
    echo "  $disk_type hard drive detected."

    # Detect Nvidia GPU
    if lspci | grep -E "VGA|3D" | grep -qi nvidia; then
        has_nvidia_gpu=true
        echo "  Nvidia GPU détected."
    fi

    # Tweak dnf congiguration
    if $(yn_prompt "  Tweak dnf congiguration ?" Y); then
        setconf /etc/dnf/dnf.conf fastestmirror True
        setconf /etc/dnf/dnf.conf max_parallel_downloads 10
    fi

    # Update the system
    if $(yn_prompt "  Update the system ?" Y); then
        dnf upgrade --refresh -y 2>&1 | verb "Updating the system"
    fi

    # Install RPM Fusion repositories
    if $(yn_prompt "  Install RPM Fusion repositories ?" Y); then
        add_rpmfusion 2>&1 | verb "Installing RPM Fusion repositories"

    fi
    
    # Install Nvidia drivers
    if [ $has_nvidia_gpu ]; then
        msg="Install Nvidia drivers"
        ! [ $RPM_FUSION ] && msg="$msg (will install RPM Fusion repositories)"
        if $(yn_prompt "  $msg ?" Y); then
            ! [ $RPM_FUSION ] && add_rpmfusion 2>&1 | verb "Installing RPM Fusion repositories" && RPM_FUSION=true
            (
                dnf install dnf-plugins-core -y
                dnf install akmod-nvidia -y
                dnf install xorg-x11-drv-nvidia-cuda -y
            ) 2>&1 | verb "Installation des drivers"

            if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist.conf; then
                echo "    Mise en blacklist de \"nouveau\""
                echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
            fi

            if grep -E "GRUB_CMDLINE_LINUX *= *\".*rd.driver.blacklist=nouveau.*\"" /etc/default/grub; then
                echo "    Ajout de l'option \"rd.driver.blacklist=nouveau\" à \"GRUB_CMDLINE_LINUX\" dans /etc/default/grub"
                sed -c -i "s/\(GRUB_CMDLINE_LINUX *= *\".*\)\"/\1 rd.driver.blacklist=nouveau\"/" /etc/default/grub
            fi

            UPDATE_GRUB=true
        fi
    fi

    # Install media codecs and VLC
    msg="Install media codecs and VLC"
    ! [ $RPM_FUSION ] && msg="$msg (will install RPM Fusion repositories)"
    if $(yn_prompt "  $msg ?" Y); then
        ! [ $RPM_FUSION ] && add_rpmfusion 2>&1 | verb "Installing RPM Fusion repositories" && RPM_FUSION=true
        (
            dnf install -y  gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel
            dnf install lame\* --exclude=lame-devel -y
            dnf group upgrade --with-optional Multimedia -y
        ) 2>&1 | verb "Installing media codecs"
        dnf install vlc -y 2>&1 | verb "Installing VLC"
    fi

    # Install archive manipulation applications 
    if $(yn_prompt " Install archive manipulation applications ?" Y); then
        (
            dnf install unzip unrar p7zip file-roller-nautilus -y
        ) 2>&1 | verb "Installing archive manipulation applications"
    fi

    # Install preload
    [ "$disk_type" = "HDD" ] && default=Y || default=N
    if $(yn_prompt " Install preload ?" $default); then
        (
            dnf copr enable elxreno/preload -y
            dnf install preload -y
        ) 2>&1 | verb "Installing preload"
    fi

fi # Post install actions

# Themes
if [ $THEME ]; then

    title; echo "Themes installation:"

    # Install Orchis theme
    if $(yn_prompt " Install Orchis theme ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps 2>&1 | verb "Installing dependencies" && GNOME_DEPS=true
        dnf install gnome-shell-extension-user-theme 2>&1 | verb "Installing User Theme GNOME extension"
        (
            if [ ! -d "/usr/share/themes/Orchis" ]; then
                cd $WORK_DIR
                git clone https://github.com/vinceliuice/Orchis-theme.git
                cd Orchis-theme
                ./install.sh
            fi
            my_gsettings set org.gnome.desktop.interface gtk-theme 'Orchis-light'
            my_gsettings set org.gnome.desktop.wm.preferences theme 'Orchis-light'
            my_gsettings set org.gnome.shell.extensions.user-theme name 'Orchis-light'
        ) 2>&1 | verb "Installing Orchis theme"
    fi

    # Install Numix icons theme
    if $(yn_prompt " Install Numix icons theme ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps 2>&1 | verb "Installing dependencies" && GNOME_DEPS=true
        (
            dnf install numix-icon-theme -y
            my_gsettings set org.gnome.desktop.interface icon-theme 'Numix'
        ) 2>&1 | verb "Installing Numix icons theme"
    fi

    # Install sleek Grub bootloader theme
    if $(yn_prompt " Install sleek Grub bootloader theme ?" Y); then
        (
            cd $WORK_DIR
            git clone https://github.com/sandesh236/sleek--themes.git
            cd "sleek--themes/Sleek theme-dark"

            THEME_DIR="/boot/grub2/themes"
            THEME_NAME="sleek"

            [ -d ${THEME_DIR}/${THEME_NAME} ] && rm -rf ${THEME_DIR}/${THEME_NAME}
            mkdir -p ${THEME_DIR}/${THEME_NAME}

            cp -a ${THEME_NAME}/* ${THEME_DIR}/${THEME_NAME}
            
            username=${SUDO_USER^}
            sed -ci "s/Grub Bootloader/Salut $username,/g"  $THEME_DIR/$THEME_NAME/theme.txt
            sed -ci "s/select your preferred os/choisi un OS pour démarrer/g"  $THEME_DIR/$THEME_NAME/theme.txt

            sed -ci "s/\(^GRUB_TERMINAL_OUTPUT *= *\"console\"\)/# \1/" /etc/default/grub
            setconf /etc/default/grub GRUB_THEME "${THEME_DIR}/${THEME_NAME}/theme.txt"

            UPDATE_GRUB=true
        ) 2>&1 | verb "Installing sleek Grub bootloader theme"
    fi

    # Do some additional tweaks
    if $(yn_prompt " Do some additional tweaks ?" Y); then
        ! [ $GNOME_DEPS ] && install_gnome_deps 2>&1 | verb "Installing dependencies" && GNOME_DEPS=true
        # -- Apparency --- #
        my_gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
        my_gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
        my_gsettings set org.gnome.desktop.interface show-battery-percentage true
        my_gsettings set org.gnome.desktop.interface clock-show-weekday true

        # -- Apps --- #
        my_gsettings set org.gnome.shell favorite-apps "['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']"
        my_gsettings set org.gnome.desktop.search-providers sort-order "['org.gnome.Contacts.desktop', 'org.gnome.Documents.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Calculator.desktop', 'firefox.desktop', 'org.gnome.clocks.desktop', 'org.gnome.Software.desktop', 'org.gnome.Boxes.desktop', 'org.gnome.Weather.desktop', 'org.gnome.Photos.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Characters.desktop']"
        
        # --- Key-binding --- #
        # launchers
        my_gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>f']"
        my_gsettings set org.gnome.settings-daemon.plugins.media-keys calculator "['<Super>c']"
        my_gsettings set org.gnome.settings-daemon.plugins.media-keys www "['<Super>b']"
        my_gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "['<Super>i']"
        # Navigation
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-right "['<Shift><Super>Right']"
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-left "['<Shift><Super>Left']"
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-up "['<Primary><Alt>Up']"
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-right "['<Primary><Alt>Right']"
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-left "['<Primary><Alt>Left']"
        my_gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-down "['<Primary><Alt>Down']"
        my_gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Primary><Super>Left']"
        my_gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Primary><Super>Right']"
        my_gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']"
        # System
        my_gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>v']"
        my_gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "[]"
    fi

fi # Themes


# Gnome extensions
if [ $GNOME_EXTENSIONS ]; then
    
    title; echo "GNOME extensions installation and configuration:"

    # Install Blur my Shell GNOME extension
    if $(yn_prompt " Install Blur my Shell GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps 2>&1 | verb "Installing dependencies" && GNOME_EXT_DEPS=true
        sudo -u ${SUDO_USER} gnome-shell-extension-installer 3193 --update --yes 2>&1 | verb "Installing Blur my Shell GNOME extension"
        SETUP_BLUR_MY_SHELL=true
    fi

    # Install UI Tune GNOME extension
    if $(yn_prompt " Install UI Tune GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps 2>&1 | verb "Installing dependencies" && GNOME_EXT_DEPS=true
        sudo -u ${SUDO_USER} gnome-shell-extension-installer 4158 --update --yes 2>&1 | verb "Installing UI Tune GNOME extension"
        SETUP_UI_TUNE=true
    fi

    # Install Tiling Assistant GNOME extension
    if $(yn_prompt " Install Tiling Assistant GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps 2>&1 | verb "Installing dependencies" && GNOME_EXT_DEPS=true
        sudo -u ${SUDO_USER} gnome-shell-extension-installer 3733 --update --yes 2>&1 | verb "Installing Tiling Assistant GNOME extension"
        SETUP_TILING_ASSISTANT=true
    fi

    # Install Vitals GNOME extension
    if $(yn_prompt " Install Vitals GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps 2>&1 | verb "Installing dependencies" && GNOME_EXT_DEPS=true
        sudo -u ${SUDO_USER} gnome-shell-extension-installer 1460 --update --yes 2>&1 | verb "Installing Vitals GNOME extension"
        SETUP_VITALS=true
    fi

    # Install ddterm GNOME extension
    if $(yn_prompt " Install ddterm GNOME extension ?" Y); then
        ! [ $GNOME_EXT_DEPS ] && install_gnome_extensions_deps 2>&1 | verb "Installing dependencies" && GNOME_EXT_DEPS=true
        sudo -u ${SUDO_USER} gnome-shell-extension-installer 3780 --update --yes 2>&1 | verb "Installing ddterm GNOME extension"
        SETUP_DDTERM=true
    fi

    # Restart GNOME
    if [ $SETUP_BLUR_MY_SHELL ] || [ $SETUP_UI_TUNE ] || [ $SETUP_TILING_ASSISTANT ] || [ $SETUP_VITALS ] || [ $SETUP_DDTERM ]; then
        if [ $VERBOSE ]; then
            echo -e "  \033[1mPlease restart GNOME to continue\033[0m"
            echo -e "    Press \033[1malt + f2\033[0m, type '\033[1mr\033[0m' then press \033[1mEnter\033[0m."
            read -p "    Once GNOME is restarted, press Enter "
        else
            zenity --info --title "Please restart GNOME to continue" \
                   --text "Press <b>alt + f2</b>, type '<b>r</b>' then press <b>Enter</b>.\nOnce GNOME is restarted, click on \"<b>Continue</b>\"." \
                   --width=$WIDTH --ok-label="Continue"
        fi 
    fi

    USER_EXTENSIONS_DIR="${USER_HOME}/.local/share/gnome-shell/extensions/"
    
    # Setup Blur my Shell GNOME extension
    if [ $SETUP_BLUR_MY_SHELL ]; then
        uuid="blur-my-shell@aunetx"
        sudo -u ${SUDO_USER} gnome-extensions enable ${uuid}
    fi

    # Setup ddterm GNOME extension
    if [ $SETUP_DDTERM ]; then
        uuid="ddterm@amezin.github.com"
        sudo -u ${SUDO_USER} gnome-extensions enable ${uuid}
    fi

    # Setup UI Tune GNOME extension
    if [ $SETUP_UI_TUNE ]; then
        uuid="gnome-ui-tune@itstime.tech"
        sudo -u ${SUDO_USER} gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.gnome-ui-tune"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} hide-search false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} increase-thumbnails-size true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} restore-thumbnails-background true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} always-show-thumbnails false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} overview-firefox-pip true
    fi

    # Setup Tiling Assistant GNOME extension
    if [ $SETUP_TILING_ASSISTANT ]; then
        uuid="tiling-assistant@leleat-on-github"
        sudo -u ${SUDO_USER} gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.tiling-assistant"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"

        # --- Settings --- #
        my_gsettings --schemadir ${schema_dir} set ${schema_name} enable-tiling-popup true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} enable-raise-tile-group false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} enable-hold-maximize-inverse-portrait false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} enable-hold-maximize-inverse-landscape false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tiling-popup-all-workspace false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} screen-gap 8
        my_gsettings --schemadir ${schema_dir} set ${schema_name} window-gap 8
        # SETTING maximize-with-gap CURRENTLY BUGGED
        my_gsettings --schemadir ${schema_dir} set ${schema_name} maximize-with-gap false #true 
        my_gsettings --schemadir ${schema_dir} set ${schema_name} dynamic-keybinding-behaviour "'Window Focus'"

        # --- Key-binding --- #
        # Unassign built-in key-bindings
        my_gsettings set org.gnome.desktop.wm.keybindings maximize "[]"
        my_gsettings set org.gnome.desktop.wm.keybindings unmaximize "[]"
        my_gsettings set org.gnome.mutter.keybindings toggle-tiled-left "[]"
        my_gsettings set org.gnome.desktop.wm.keybindings toggle-tiled-right "[]"
        # Assign Tiling Assistant key-binding
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tile-maximize "['<Super>m']"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tile-right-half "['<Super>Right']"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tile-left-half "['<Super>Left']"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tile-top-half "['<Super>Up']"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} tile-bottom-half "['<Super>Down']"
    fi

    # Setup Vitals GNOME extension
    if [ $SETUP_VITALS ]; then
        uuid="Vitals@CoreCoding.com"
        sudo -u ${SUDO_USER} gnome-extensions enable ${uuid}

        schema_name="org.gnome.shell.extensions.vitals"
        schema_dir="${USER_EXTENSIONS_DIR}/${uuid}/schemas"
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-temperature true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-voltage false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-fan true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-memory true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-processor true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-storage false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} use-higher-precision false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} hide-zeros false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} include-public-ip false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} show-battery true
        my_gsettings --schemadir ${schema_dir} set ${schema_name} fixed-widths false
        my_gsettings --schemadir ${schema_dir} set ${schema_name} hide-icons false
    fi

fi # Gnome extensions


# Coding
if [ $CODING ]; then

    title; echo "Coding related installation and configuration:"
    
    # Install VSCodium
    if $(yn_prompt " Install VSCodium ?" Y); then
        (
            rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg 
            printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg" | tee -a /etc/yum.repos.d/vscodium.repo
            dnf install codium
        ) 2>&1 | verb "Installing VSCodium"
    fi

    # Install micro
    if $(yn_prompt " Install micro ?" Y); then
        dnf install micro xclip 2>&1 | verb "Installing micro"
    fi

    # Install Fish Shell
    if $(yn_prompt " Install Fish Shell ?" Y); then
        (
            dnf insatll exa
            dnf install fish
            sudo -u ${SUDO_USER} chsh -s /usr/bin/fish
        ) 2>&1 | verb "Installing Fish Shell"

        (
            sudo -u ${SUDO_USER} fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
            sudo -u ${SUDO_USER} fish -c "fisher install IlanCosman/tide@v5"
            sudo -u ${SUDO_USER} fish -c "fisher install jorgebucaran/replay.fish"
            sudo -u ${SUDO_USER} fish -c "fisher install jorgebucaran/autopair.fish"
            sudo -u ${SUDO_USER} fish -c "gazorby/fish-abbreviation-tips"
            sudo -u ${SUDO_USER} fish -c "fisher install gazorby/fish-exa"
        ) 2>&1 | verb "Configuring Fish Shell"

        FISH_INSTALLED=true
    fi

    # Install Meslo font
    if $(yn_prompt " Install Meslo font ?" Y); then
        (
            cd $WORK_DIR
            sudo -u ${SUDO_USER} curl -fLo Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip
            mkdir -pv /usr/share/fonts/Meslo
            unzip Meslo.zip -d /usr/share/fonts/Meslo/
            sudo -u ${SUDO_USER} fc-cache -f -v
        ) 2>&1 | verb "Installing Meslo font"
    fi

fi # Coding


# dot files
if [ $DOT_FILES ]; then

    title; echo "dot files retrieval:"

    # Install chezmoi and retrieve dot files
    if $(yn_prompt " Install chezmoi and retrieve dot files ?" Y); then
        (
            sudo -u ${SUDO_USER} mkdir -p "${USER_HOME}/.local/bin"
            sudo -u ${SUDO_USER} BINDIR="${USER_HOME}/.local/bin" sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply "didi-maru"
            
            if [ $FISH_INSTALLED ]; then
                fish -c "import_tide_config"
            fi

            # Get default profile ID
            profile="$(gsettings get org.gnome.Terminal.ProfilesList default)"
            profile="${profile:1:-1}" # remove leading and trailing single quotes
            dconf load "/org/gnome/terminal/legacy/profiles:/:$profile/" < "${USER_HOME}/gnome-terminal-profile.dconf"

        ) 2>&1 | verb "Installing chezmoi and retrieve dot files"
    fi 

fi # dot files


# Update grub if necessary
if [ $UPDATE_GRUB ]; then
    (
        if [ -d "/sys/firmware/efi" ]; then
            grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
        else
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
    ) 2>&1 | verb "Updating grub2 configuration"
fi # Update grub


########################################

title; echo "Configuration finished"

echo "  Removing work directory ${WORK_DIR}"
rm -rf ${WORK_DIR}
echo "  See ${LOG_FILE} fo log informations."

exit 0
