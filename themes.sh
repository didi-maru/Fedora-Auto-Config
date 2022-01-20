#!/bin/bash

function install_orchis_theme() {
    if [ ! -d "/usr/share/themes/Orchis" ]; then
        cd $WORK_DIR
        run git clone https://github.com/vinceliuice/Orchis-theme.git
        cd Orchis-theme
        run sudo ./install.sh
    fi
    set_gtk_theme "Orchis-light"
}

function install_fluent_gtk_theme() {
    if [ ! -d "/usr/share/themes/Fluent-round" ]; then
        cd $WORK_DIR
        run git clone https://github.com/vinceliuice/Fluent-gtk-theme.git
        cd Fluent-gtk-theme
        run sudo ./install.sh --size standard --icon fedora --tweaks round noborder
    fi
    set_gtk_theme "Fluent-round"
}

function install_catppuccin_theme() {
    if [ ! -d "/usr/share/themes/Catppuccin-magenta" ]; then
        cd $WORK_DIR
        run wget -O https://github.com/catppuccin/gtk/releases/download/v.1.0.0/Catppuccin-magenta.tar.gz
        run sudo tar xf Catppuccin-magenta.tar.gz -C /usr/share/themes/
    fi
    set_gtk_theme "Catppuccin-magenta"
}

function set_gtk_theme() {
    run gsettings set org.gnome.desktop.interface gtk-theme "$1"
    run gsettings set org.gnome.desktop.wm.preferences theme "$1"
    run gsettings set org.gnome.shell.extensions.user-theme name "$1"
}

function install_fluent_icon_theme() {
    if [ ! -d "/usr/share/themes/Fluent-purple" ]; then
        cd $WORK_DIR
        run git clone https://github.com/vinceliuice/Fluent-icon-theme.git
        cd Fluent-icon-theme
        run sudo ./install.sh -r
        run gsettings set org.gnome.desktop.interface icon-theme 'Fluent'
    fi
}

function install_fluent_icon_theme() {
    run sudo dnf install "$DNF_YES" numix-icon-theme
    run gsettings set org.gnome.desktop.interface icon-theme 'Numix'
}


