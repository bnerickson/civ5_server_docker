FROM fedora:latest

# Update all packages
RUN dnf -y update

# mesa-libGL - OpenGL software renderer
# mesa-libOSMesa - Fixes crashes when starting a hosted game
# pulseaudio, pulseaudio-libs.i686 - Civ 5 needs somewhere to output audio
# supervisor - Lets up run and monitor a bunch of processes
# tigervnc-server - Let us connect to the virtual display over VNC.  x11vnc
#                   + Xvfb w/Fedora wasn't working well, but tigervnc works.
# openbox - Super-lightweight window manager
# glibc-devel,gcc-c++,libstdc++-devel required for libstrangle
RUN dnf -y install \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libOSMesa.i686 \
    mesa-libOSMesa \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    mesa-libGL-devel \
    pulseaudio \
    pulseaudio-libs.i686 \
    pipewire-alsa \
    pipewire-alsa.i686 \
    supervisor \
    tigervnc-server \
    openbox \
    wine \
    winetricks \
    glibc-devel \
    glibc-devel.i686 \
    gcc-c++ \
    libstdc++-devel \
    libstdc++-devel.i686
RUN dnf -y group install development-tools

# Force software rendering, and also set $DISPLAY while we're here
ENV LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe GALLIUM_DRIVER=llvmpipe DISPLAY=:99 NFTY_TOPIC=""

WORKDIR /

# Install Steam for Windows via Winetricks
# You don't even need to be logged in to Steam, it just needs to be there for the game to not crash when hosting a game
RUN winetricks --force -q win10 steam

# Run steam so that it auto-updates at build time instead of on every container run
RUN dnf -y install xorg-x11-server-Xvfb
RUN /usr/bin/Xvfb :99 -screen 0 1920x1080x24 -dpi 96 & \
sleep 6 && timeout 500 wineconsole "/root/.wine/drive_c/Program Files (x86)/Steam/Steam.exe" -tcp -no-cef-sandbox -cef-disable-gpu -cef-disable-breakpad -nocrashmonitor || true

# Install libstrangle to limit the framerate
COPY ./overlay_patch.patch /root/overlay_patch.patch
RUN git clone https://gitlab.com/torkel104/libstrangle.git
RUN chmod a+rw /libstrangle
RUN patch /libstrangle/src/vulkan/overlay.cpp < /root/overlay_patch.patch && cd /libstrangle && make && make install
RUN rm -rf /libstrangle

# Install telemetry system to transmit players who haven't taken their turn
# using nfty.sh
RUN dnf install -y inotify-tools sqlite
RUN mkdir -p /usr/lib/tx_player_turns/
COPY ./tx_player_turns.bash /usr/lib/tx_player_turns/

# Add our list-of-stuff-to-execute
COPY ./supervisord.conf /etc/supervisord.conf

# For testing software rendering
# RUN dnf -y install glx-utils

# Start the supervisor service to manage processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
