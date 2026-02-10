
# Configure dbus
print_header "Configure pipewire"

# Always enable the pipwire service
print_step_header "Enable pipewire services."
sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/pipewire.ini
sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/pipewire-pulse.ini
sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor.d/wireplumber.ini

if [ "${MODE}" == "s" ] | [ "${MODE}" == "secondary" ]; then
    print_step_header "Configure pulseaudio as simple dummy audio"
    sed -i 's|^; autospawn.*$|autospawn = no|' /etc/pulse/client.conf
    sed -i 's|^; daemon-binary.*$|daemon-binary = /bin/true|' /etc/pulse/client.conf

    sed -i 's|^; flat-volumes.*$|flat-volumes = yes|' /etc/pulse/daemon.conf
else
    print_step_header "Configure pulseaudio to pipe audio to a socket"

    # Ensure pulseaudio directories have the correct permissions
    mkdir -p \
        ${PULSE_SOCKET_DIR} \
        ${USER_HOME:?}/.config/pulse
    chmod -R a+rw ${PULSE_SOCKET_DIR}
    chown -R ${PUID}:${PGID} ${USER_HOME:?}/.config/pulse

    # Configure the pulse audio socket
    sed -i "s|^; default-server.*$|default-server = ${PULSE_SERVER}|" /etc/pulse/client.conf
    mkdir -p /etc/pipewire
    cp /usr/share/pipewire/pipewire-pulse.conf /etc/pipewire/pipewire-pulse.conf
    sed -i "s|\"unix:native\".*$|\"unix:${PULSE_SOCKET_DIR}/pulse-socket\"|" /etc/pipewire/pipewire-pulse.conf

    # Disable pulseaudio from respawning (https://unix.stackexchange.com/questions/204522/how-does-pulseaudio-start)
    sed -i 's|^; autospawn.*$|autospawn = no|' /etc/pulse/client.conf
    sed -i 's|^; daemon-binary.*$|daemon-binary = /bin/true|' /etc/pulse/client.conf
fi
chown -R ${USER} /etc/pipewire

echo -e "\e[34mDONE\e[0m"
