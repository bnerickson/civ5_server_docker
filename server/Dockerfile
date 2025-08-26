FROM fedora:latest

# Update all packages
RUN dnf -y update

# gcc-c++ - Required to compile libstrangle
# glibc-devel - Required to compile libstrangle
# libstdc++-devel - Required to compile libstrangle
# mesa-libGL - OpenGL software renderer
# mesa-libOSMesa - Mesa offscreen rendering libraries (hosting a game crashes without this)
# openbox - Super-lightweight window manager
# pulseaudio, pulseaudio-libs.i686 - Civ 5 needs somewhere to output audio
# pipewire-alsa - Wine complains about lib alsa missing, so included just in case
# supervisor - Run and monitor processes
# wine - Wine native rpm
# winetricks - Allows us to install windows steam "natively"
# tigervnc-server - VNC server to connect to the virtual display
# xorg-x11-server-Xvfb - In-memory display server
RUN dnf -y install \
    gcc-c++ \
    glibc-devel \
    glibc-devel.i686 \
    libstdc++-devel \
    libstdc++-devel.i686 \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libOSMesa.i686 \
    mesa-libOSMesa \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    mesa-libGL-devel \
    openbox \
    pulseaudio \
    pulseaudio-libs.i686 \
    pipewire-alsa \
    pipewire-alsa.i686 \
    supervisor \
    tigervnc-server \
    wine \
    winetricks \
    xorg-x11-server-Xvfb

# Needed to compile libstrangle
RUN dnf -y group install development-tools

# Force software rendering, and also set $DISPLAY while we're here
ENV LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe DISPLAY=:99 CIV_DATA_ROOT="/root/.wine/drive_c/users/root/Documents/My Games/Sid Meier's Civilization 5" NFTY_TOPIC=""

WORKDIR /

# Install Steam for Windows via Winetricks
# You don't even need to be logged in to Steam, it just needs to be there for the game to not crash when hosting a game
RUN winetricks --force -q win10 steam

# Run steam so that it auto-updates at build time instead of on every container run
RUN /usr/bin/Xvfb :99 -screen 0 1920x1080x24 -dpi 96 & \
sleep 6 && timeout 500 wineconsole "/root/.wine/drive_c/Program Files (x86)/Steam/Steam.exe" -tcp -no-cef-sandbox -cef-disable-gpu -cef-disable-breakpad -nocrashmonitor || true

# Install libstrangle to limit the framerate
COPY ./overlay_patch.patch /root/overlay_patch.patch
RUN git clone https://gitlab.com/torkel104/libstrangle.git
RUN chmod a+rw /libstrangle
RUN patch /libstrangle/src/vulkan/overlay.cpp < /root/overlay_patch.patch && cd /libstrangle && make && make install
RUN rm -rf /libstrangle

# Install telemetry system to notify players who haven't taken their turn using nfty.sh
RUN dnf install -y inotify-tools sqlite crontabs
RUN mkdir -p /usr/lib/tx_player_turns/
COPY ./tx_player_turns.bash /usr/lib/tx_player_turns/
COPY ./scheduled_turn_notifications.bash /etc/cron.weekly/
RUN chmod +x /etc/cron.weekly/scheduled_turn_notifications.bash

# Add our list-of-stuff-to-execute
COPY ./supervisord.conf /etc/supervisord.conf

# For testing software rendering
# RUN dnf -y install glx-utils

# Start the supervisor service to manage processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
