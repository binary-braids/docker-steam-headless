print_header "Configure Steam"

# --- CHANGE 1: Update Exec path to /usr/bin/steam (standard for .deb) ---
steam_autostart_desktop="$(
    cat <<EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Steam
Comment=Launch steam on login
Exec=/usr/bin/steam %U ${STEAM_ARGS:-}
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

# --- CHANGE 2: Update internal path to .local/share/Steam ---
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
    if [ "${MODE}" == "s" ] || [ "${MODE}" == "secondary" ]; then
        print_step_header "Enable Steam supervisor.d service"
        sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/steam.ini
    else
        print_step_header "Enable Steam auto-start script"
        mkdir -p "${USER_HOME:?}/.config/autostart"
        echo "${steam_autostart_desktop:?}" >"${USER_HOME:?}/.config/autostart/Steam.desktop"
        sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
    fi

    # --- CHANGE 3: Update all CONFIG_VDF and LIBRARY_VDF paths ---
    # We point to .local/share/Steam but also create symlinks for legacy support
    
    STEAM_ROOT="${USER_HOME:?}/.local/share/Steam"
    mkdir -p "${STEAM_ROOT}"
    
    # Symlink legacy .steam paths to the new location so SteamVR doesn't break
    mkdir -p "${USER_HOME:?}/.steam"
    ln -sfn "${STEAM_ROOT}" "${USER_HOME:?}/.steam/steam"
    ln -sfn "${STEAM_ROOT}" "${USER_HOME:?}/.steam/root"

    CONFIG_VDF="${STEAM_ROOT}/config/config.vdf"
    
    if [ ! -f "${CONFIG_VDF}" ]; then
        print_step_header "Initializing Steam config"
        mkdir -p "$(dirname "${CONFIG_VDF}")"
        echo "${default_steam_config}" >"${CONFIG_VDF}"
        # Change 4: Ensure PUID/PGID ownership of the .local folder
        chown -R "${PUID:-99}:${PGID:-100}" "${USER_HOME:?}/.local"
        chown -R "${PUID:-99}:${PGID:-100}" "${USER_HOME:?}/.steam"
    else
        print_step_header "Steam config already exists, skipping initialization"
    fi

    LIBRARY_VDF="${STEAM_ROOT}/steamapps/libraryfolders.vdf"
    if [ ! -f "${LIBRARY_VDF}" ]; then
        print_step_header "Initializing Steam library"
        mkdir -p "$(dirname "${LIBRARY_VDF}")"
        echo "${default_steam_library_config}" >"${LIBRARY_VDF}"
        
        if [ -d "/mnt/games" ]; then
            mkdir -p "/mnt/games/GameLibrary/Steam/steamapps"
            chown -R "${PUID:-99}:${PGID:-100}" "/mnt/games/GameLibrary"
            echo "${games_steam_library_config}" >"/mnt/games/GameLibrary/Steam/libraryfolder.vdf"
        fi
        
        chown -R "${PUID:-99}:${PGID:-100}" "${USER_HOME:?}/.local"
    else
        print_step_header "Steam library config already exists, skipping initialization"
    fi
else
    print_step_header "Disable Steam service"
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor.d/steam.ini
fi

# Final recursive permission fix to prevent Disk Write Error
chown -R "${PUID:-99}:${PGID:-100}" "${USER_HOME:?}/.local"

echo -e "\e[34mDONE\e[0m"
