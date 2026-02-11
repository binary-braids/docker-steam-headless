#!/bin/bash

print_header "Configure Steam"

# Desktop entry for XFCE/Desktop mode
steam_autostart_desktop="$(
    cat <<EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Steam
Comment=Launch steam on login
Exec=/usr/games/steam %U ${STEAM_ARGS:-}
Icon=steam
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
)"

# Config to enable Steam Play (Proton) for all titles
default_steam_config="$(
    cat <<EOF
"InstallConfigStore"
{
        "Software"
        {
                "Valve"
                {
                        "Steam"
                        {
                                "CompatToolMapping"
                                {
                                        "0"
                                        {
                                                "name"          "proton_hotfix"
                                                "config"                ""
                                                "priority"              "75"
                                        }
                                }
                        }
                }
        }
}
EOF
)"

# libraryfolders.vdf updated for the .deb data path
default_steam_library_config="$(
    cat <<EOF
"libraryfolders"
{
        "0"
        {
                "path"          "/home/default/.local/share/Steam"
                "label"         "Home"
                "totalsize"     "0"
                "update_clean_bytes_tally" "0"
                "time_last_update_verified" "0"
                "apps"
                {
                }
        }
        "1"
        {
                "path"          "/mnt/games/GameLibrary/Steam"
                "label"         "Games"
                "contentid"     "4532270033051814356"
                "totalsize"     "0"
                "update_clean_bytes_tally" "0"
                "time_last_update_verified" "0"
                "apps"
                {
                }
        }
}
EOF
)"

games_steam_library_config="$(
    cat <<EOF
"libraryfolder"
{
        "contentid"     "4532270033051814356"
        "label"         "Games"
}
EOF
)"

if [ "${ENABLE_STEAM:-}" = "true" ]; then
    print_step_header "Ensuring Official Steam Path Structure"
    
    # 1. Create the real data directory (XDG Standard for .deb version)
    mkdir -p "${USER_HOME:?}/.local/share/Steam"
    mkdir -p "${USER_HOME:?}/.steam"

    # 2. Fix the Symlink Structure (Prevents "Could not setup steam data")
    # Steam .deb MUST have ~/.steam/steam as a link to .local/share/Steam
    if [ -d "${USER_HOME}/.steam/steam" ] && [ ! -L "${USER_HOME}/.steam/steam" ]; then
        echo "Moving existing data and converting ~/.steam/steam to symlink..."
        cp -r "${USER_HOME}/.steam/steam/"* "${USER_HOME}/.local/share/Steam/" 2>/dev/null
        rm -rf "${USER_HOME}/.steam/steam"
    fi

    if [ ! -L "${USER_HOME}/.steam/steam" ]; then
        ln -sf "${USER_HOME}/.local/share/Steam" "${USER_HOME}/.steam/steam"
    fi

    # 3. Ensure 'root' link exists as well
    if [ ! -L "${USER_HOME}/.steam/root" ]; then
        ln -sf "${USER_HOME}/.local/share/Steam" "${USER_HOME}/.steam/root"
    fi

    # Determine startup mode
    if [ "${MODE}" == "s" ] || [ "${MODE}" == "secondary" ]; then
        print_step_header "Enable Steam supervisor.d service"
        sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/steam.ini
    else
        print_step_header "Enable Steam auto-start script"
        mkdir -p "${USER_HOME}/.config/autostart"
        echo "${steam_autostart_desktop:?}" >"${USER_HOME}/.config/autostart/Steam.desktop"
        sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
    fi

    # 4. Initialize Steam Config (Proton support)
    CONFIG_VDF="${USER_HOME}/.steam/steam/config/config.vdf"
    if [ ! -f "${CONFIG_VDF}" ]; then
        print_step_header "Initializing Steam config"
        mkdir -p "$(dirname "${CONFIG_VDF}")"
        echo "${default_steam_config}" >"${CONFIG_VDF}"
    fi

    # 5. Initialize Steam Library folder
    LIBRARY_VDF="${USER_HOME}/.steam/steam/steamapps/libraryfolders.vdf"
    if [ ! -f "${LIBRARY_VDF}" ]; then
        print_step_header "Initializing Steam library"
        mkdir -p "$(dirname "${LIBRARY_VDF}")"
        echo "${default_steam_library_config}" >"${LIBRARY_VDF}"
        
        # Setup external /mnt/games if available
        if [ -d "/mnt/games" ]; then
            mkdir -p "/mnt/games/GameLibrary/Steam/steamapps"
            echo "${games_steam_library_config}" >"/mnt/games/GameLibrary/Steam/libraryfolder.vdf"
        fi
    fi

    # 6. Apply permissions to all paths
    print_step_header "Setting permissions for Steam paths"
    chown -R "${USER:?}:${USER:?}" \
        "${USER_HOME}/.steam" \
        "${USER_HOME}/.local/share/Steam" \
        2>/dev/null

    if [ -d "/mnt/games/GameLibrary" ]; then
        chown -R "${USER:?}:${USER:?}" "/mnt/games/GameLibrary"
    fi

else
    print_step_header "Disable Steam service"
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
fi

echo -e "\e[34mDONE\e[0m"