FROM fedora:42

# Copy custom repo files IF THEY EXIST
# Otherwise, the default behavior is copy
# nothing over and use the default repo files
COPY fedora.repo* /etc/yum.repos.d/fedora.repo
COPY fedora-updates.repo* /etc/yum.repos.d/fedora-updates.repo
COPY fedora-cisco-openh264.repo* /etc/yum.repos.d/fedora-cisco-openh264.repo

# Time to wait for Steam to autoupdate loaded from
# the docker compose.
ARG STEAM_INSTALL_SLEEP_TIMER

# Update all packages
RUN dnf -y update

# cronie - Weekly notifications of player turn status
# gcc-c++ - Required to compile libstrangle
# glibc-devel - Required to compile libstrangle
# inotify-tools - Track changes to sqlite dbs for turn status notifications
# libstdc++-devel - Required to compile libstrangle
# mesa-libGL - OpenGL software renderer
# mesa-libEGL - Mesa offscreen rendering (replacing libOSMesa)
# openbox - Super-lightweight window manager
# procps-ng - Required for server_down_notifier.bash script
# pulseaudio, pulseaudio-libs.i686 - Civ 5 needs somewhere to output audio
# pipewire-alsa - Wine complains about lib alsa missing, so included just in case
# sqlite - Query sqlite dbs for player turn status
# supervisor - Run and monitor processes
# wine - Wine native rpm
# winetricks - Allows us to install windows steam "natively"
# tigervnc-server - VNC server to connect to the virtual display
# xorg-x11-server-Xvfb - In-memory display server
RUN dnf -y install \
    cronie \
    gcc-c++ \
    glibc-devel \
    glibc-devel.i686 \
    inotify-tools \
    libstdc++-devel \
    libstdc++-devel.i686 \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libEGL \
    mesa-libEGL.i686 \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    mesa-libGL-devel \
    openbox \
    procps-ng \
    pulseaudio \
    pulseaudio-libs.i686 \
    pipewire-alsa \
    pipewire-alsa.i686 \
    sqlite \
    supervisor \
    tigervnc-server \
    wine \
    winetricks \
    xorg-x11-server-Xvfb

# Needed to compile libstrangle
RUN dnf -y group install development-tools

# For testing software rendering
# RUN dnf -y install glx-utils

RUN dnf clean all -y

WORKDIR /

# Install Steam for Windows via Winetricks
# You don't even need to be logged in to Steam, it just needs to be there for the game to not crash when hosting a game
RUN winetricks --force --unattended dxvk steam

# Add our env file so it can be referenced by cron jobs
# and within this build
COPY ./civ5.env /root/civ5.env

# Run steam so that it auto-updates at build time instead of on every container run
RUN /usr/bin/Xvfb :99 -screen 0 1920x1080x24 -dpi 96 & \
sleep 10 && set -o allexport && source /root/civ5.env && set +o allexport && (timeout 500 wineconsole "/root/.wine/drive_c/Program Files (x86)/Steam/Steam.exe" -tcp -no-cef-sandbox -cef-disable-gpu -cef-disable-breakpad -nocrashmonitor || true) && sleep $STEAM_INSTALL_SLEEP_TIMER

# Install libstrangle to limit the framerate
RUN git clone https://gitlab.com/torkel104/libstrangle.git
RUN chmod a+rw /libstrangle
COPY ./overlay_patch.patch /libstrangle/overlay_patch.patch
RUN patch /libstrangle/src/vulkan/overlay.cpp < /libstrangle/overlay_patch.patch && cd /libstrangle && make && make install
RUN rm -rf /libstrangle

# Install telemetry system to notify players who haven't taken their turn using nfty.sh
COPY ./tx_player_turns.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/tx_player_turns.bash
COPY ./json_file_helper.py /usr/local/bin/
RUN chmod +x /usr/local/bin/json_file_helper.py

# Add weekly notification script
COPY ./scheduled_turn_notifications.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/scheduled_turn_notifications.bash

# Add server down notification script
COPY ./server_down_notifier.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/server_down_notifier.bash

# Add civ5 cron jobs
COPY ./civ5_cron_jobs /etc/cron.d/civ5_cron_jobs
RUN chmod 0644 /etc/cron.d/civ5_cron_jobs
RUN crontab /etc/cron.d/civ5_cron_jobs

# Add our list-of-stuff-to-execute
COPY ./supervisord.conf /etc/supervisord.conf

# Deploy a debug script to query the dbs
COPY ./debug_script.bash /usr/local/bin/
RUN chmod +x /usr/local/bin/debug_script.bash

# Start the supervisor service to manage processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
