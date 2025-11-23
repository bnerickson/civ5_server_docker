FROM fedora:42

# Copy custom repo files IF THEY EXIST
# Otherwise, the default behavior is copy
# nothing over and use the default repo files
COPY fedora.repo* /etc/yum.repos.d/fedora.repo
COPY fedora-updates.repo* /etc/yum.repos.d/fedora-updates.repo
COPY fedora-cisco-openh264.repo* /etc/yum.repos.d/fedora-cisco-openh264.repo

# Define build args
ARG CIV_DATA_ROOT
ARG DISPLAY
ARG STEAM_DLLS
ARG STEAM_INSTALL_SLEEP_TIMER
# This is hard-coded because the attempt_restart.bash
# script relies on exact x,y coordinates to start the
# server.
ARG XVFB_RESOLUTION=1600x900x24

# Set environment variables that are originally
# args used in the image build
ENV CIV_DATA_ROOT=${CIV_DATA_ROOT}
ENV DISPLAY=${DISPLAY}
ENV STEAM_DLLS=${STEAM_DLLS}
ENV XVFB_RESOLUTION=${XVFB_RESOLUTION}

# Update all packages
RUN dnf -y update

# cronie - Weekly notifications of player turn status
# dos2unix - Required to update GraphicsSettingsDX9.ini
# inotify-tools - Track changes to sqlite dbs for turn status notifications
# mesa-libGL - OpenGL software renderer
# mesa-libEGL - Mesa offscreen rendering (replacing libOSMesa)
# openbox - Super-lightweight window manager
# procps-ng - Required for server_down_notifier.bash script
# pulseaudio, pulseaudio-libs.i686 - Civ 5 needs somewhere to output audio
# sqlite - Query sqlite dbs for player turn status
# supervisor - Run and monitor processes
# tigervnc-server - VNC server to connect to the virtual display
# wine - Wine native rpm
# winetricks - Install windows steam and dxvk
# xdotool - Required for automatic civ5 server start
# xorg-x11-server-Xvfb - In-memory display server
RUN dnf -y install \
    cronie \
    dos2unix \
    inotify-tools \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libEGL \
    mesa-libEGL.i686 \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    openbox \
    procps-ng \
    pulseaudio \
    pulseaudio-libs.i686 \
    sqlite \
    supervisor \
    tigervnc-server \
    wine \
    winetricks \
    xdotool \
    xorg-x11-server-Xvfb

RUN dnf clean all -y

WORKDIR /

# Install Steam base install for Windows via Winetricks
RUN winetricks --force --unattended dxvk steam

# Run steam full install and update
RUN /usr/bin/Xvfb ${DISPLAY} -screen 0 ${XVFB_RESOLUTION} -dpi 96 & \
sleep 10 && (timeout 500 wineconsole "/root/.wine/drive_c/Program Files (x86)/Steam/Steam.exe" -tcp -no-cef-sandbox -cef-disable-gpu -cef-disable-breakpad -nocrashmonitor || true) && \
sleep ${STEAM_INSTALL_SLEEP_TIMER}

# Fail if we failed to install steam
# If this step fails, you may need to
# increase the value of STEAM_INSTALL_SLEEP_TIMER
# particularly if your Internet connection
# is slow or the server itself is slow
RUN STEAM_DLLS_ARRAY=(${STEAM_DLLS}) && for dll in "${STEAM_DLLS_ARRAY[@]}"; do if [ ! -f "/root/.wine/drive_c/Program Files (x86)/Steam/${dll}" ]; then echo "failed to find dll ${dll}" && exit 1; fi; done

# Install notification script that notifies players
# using ntfy and/or discord whenever a player disconnects
# whose turn is outstanding unless there is no change
COPY ./tx_player_turns.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/tx_player_turns.bash
COPY ./json_file_helper.py /usr/local/bin/
RUN chmod +x /usr/local/bin/json_file_helper.py

# Install weekly notification script that notifies players
# using ntfy and/or discord whose turn is outstanding
# regardless of current status
# This checks for all players that have not pressed "Next Turn"
# yet
COPY ./scheduled_turn_notifications.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/scheduled_turn_notifications.bash

# Install server down notification script that notifies players
# when the civ5 server has crashed
COPY ./server_down_notifier.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/server_down_notifier.bash

# Install civ5 cron jobs
COPY ./civ5_cron_jobs /etc/cron.d/civ5_cron_jobs
RUN chmod 0644 /etc/cron.d/civ5_cron_jobs
RUN crontab /etc/cron.d/civ5_cron_jobs

# Install supervisor configuration for list of processes
# to execute
COPY ./supervisord.conf /etc/supervisord.conf

# Install a debug script to query the dbs used for
# triggered and weekly notifications
COPY ./debug_script.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/debug_script.bash

# Install autostart script
COPY ./attempt_autostart.bash /usr/local/bin/attempt_autostart.bash
RUN chmod +x /usr/local/bin/attempt_autostart.bash

# Install the run_civ script
COPY ./run_civ.bash /usr/local/bin/run_civ.bash
RUN chmod +x /usr/local/bin/run_civ.bash

# Start the supervisor service to manage processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
