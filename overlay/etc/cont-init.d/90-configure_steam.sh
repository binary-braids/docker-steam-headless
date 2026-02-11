#!/bin/bash

print_header "Configure Steam"

# The .deb installation uses /usr/games/steam as the primary binary
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

# Updated path "0" to .local/share/Steam which is the .deb default
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
    # --- PATH INITIALIZATION FOR .DEB VERSION ---
    # The official .deb expects this directory for the actual client data
    mkdir -p "${USER_HOME:?}/.local/share/Steam"
    
    if [ "${MODE}" == "s" ] || [ "${MODE}" == "secondary" ]; then
        print_step_header "Enable Steam supervisor.d service"
        sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/steam.ini
    else
        print_step_header "Enable Steam auto-start script"
        mkdir -p "${USER_HOME:?}/.config/autostart"
        echo "${steam_autostart_desktop:?}" >"${USER_HOME:?}/.config/autostart/Steam.desktop"
        sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
    fi

    # Ensuring Steam Play is enabled for all titles
    # For the .deb version, config.vdf is located under the linked .steam/steam path
    CONFIG_VDF="${USER_HOME:?}/.steam/steam/config/config.vdf"
    if [ ! -f "${CONFIG_VDF}" ]; then
        print_step_header "Initializing Steam config"
        mkdir -p "$(dirname "${CONFIG_VDF}")"
        echo "${default_steam_config}" >"${CONFIG_VDF}"
        chown -R "${USER:?}:${USER:?}" "${USER_HOME:?}/.steam"
        chown -R "${USER:?}:${USER:?}" "${USER_HOME:?}/.local/share/Steam"
    else
        print_step_header "Steam config already exists, skipping initialization"
    fi

    # Ensure Steam library folder is set to /mnt/games if not already
    # The .deb client checks this path for library management
    LIBRARY_VDF="${USER_HOME:?}/.steam/steam/steamapps/libraryfolders.vdf"
    if [ ! -f "${LIBRARY_VDF}" ]; then
        print_step_header "Initializing Steam library"
        mkdir -p "$(dirname "${LIBRARY_VDF}")"
        echo "${default_steam_library_config}" >"${LIBRARY_VDF}"
        
        # Ensure correct ownership of the newly created library config
        chown -R "${USER:?}:${USER:?}" "${USER_HOME:?}/.steam"
        chown -R "${USER:?}:${USER:?}" "${USER_HOME:?}/.local/share/Steam"

        # Only if we have mounted a /mnt/games path, then make the default games library for steam
        if [ -d "/mnt/games" ]; then
            mkdir -p "/mnt/games/GameLibrary/Steam/steamapps"
            chown -R "${USER:?}:${USER:?}" "/mnt/games/GameLibrary"
            echo "${games_steam_library_config}" >"/mnt/games/GameLibrary/Steam/libraryfolder.vdf"
        fi
    else
        print_step_header "Steam library config already exists, skipping initialization"
    fi
else
    print_step_header "Disable Steam service"
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
fi

echo -e "\e[34mDONE\e[0m"