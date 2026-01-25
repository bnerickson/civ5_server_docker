FROM fedora:43

# Copy custom repo files IF THEY EXIST
# Otherwise, the default behavior is copy
# nothing over and use the default repo files
COPY fedora.repo* /etc/yum.repos.d/fedora.repo
COPY fedora-updates.repo* /etc/yum.repos.d/fedora-updates.repo
COPY fedora-cisco-openh264.repo* /etc/yum.repos.d/fedora-cisco-openh264.repo

# Define build args
ARG CIV_DATA_ROOT
ARG CONTAINER_GID
ARG CONTAINER_UID
ARG CONTAINER_USERNAME
ARG DISPLAY
ARG GPU_BUSID
ARG STEAM_DLLS
ARG STEAM_INSTALL_SLEEP_TIMER
# This is hard-coded because the attempt_restart.bash
# script relies on exact x,y coordinates to start the
# server.
ARG DESKTOP_RESOLUTION=1600x900x24

# Set environment variables that are originally
# args used in the image build
ENV CIV_DATA_ROOT=${CIV_DATA_ROOT}
ENV CONTAINER_USERNAME=${CONTAINER_USERNAME}
ENV DISPLAY=${DISPLAY}
ENV GPU_BUSID=${GPU_BUSID}
ENV STEAM_DLLS=${STEAM_DLLS}
ENV DESKTOP_RESOLUTION=${DESKTOP_RESOLUTION}

# Install the terra repo for umu-launcher
RUN dnf --assumeyes install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

# Update all packages
RUN dnf --assumeyes update

# cronie - Weekly notifications of player turn status
# inotify-tools - Track changes to sqlite dbs for turn status notifications
# jq - Required for proton_ge_downloader.bash script
# mesa-libGL - OpenGL software renderer
# mesa-libEGL - Mesa offscreen rendering (replacing libOSMesa)
# mesa-vulkan-drivers - Mesa vulkan drivers
# openbox - Super-lightweight window manager
# procps-ng - Required for server_down_notifier.bash script
# pulseaudio - Civ 5 needs somewhere to output audio
# sqlite - Query sqlite dbs for player turn status
# supervisor - Run and monitor processes
# tigervnc-server - VNC server to connect to the virtual display
# umu-launcher - Launch windows games with proton without steam
# winetricks - Install windows steam
# xdotool - Required for automatic civ5 server start
# xorg-x11-server-Xorg - Display server
# xorg-x11-drv-dummy - Ouput to a dummy screen during steam install
RUN dnf -y install \
    cronie \
    inotify-tools \
    jq \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libEGL \
    mesa-libEGL.i686 \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    openbox \
    procps-ng \
    pulseaudio \
    sqlite \
    supervisor \
    tigervnc-server \
    umu-launcher \
    winetricks \
    xdotool \
    xorg-x11-server-Xorg \
    xorg-x11-drv-dummy

RUN dnf clean all --assumeyes

WORKDIR /

# Create container non-root user primary group
RUN groupadd --gid ${CONTAINER_GID} ${CONTAINER_USERNAME}

# Create container non-root user
RUN useradd --shell /bin/bash --create-home --uid ${CONTAINER_UID} --gid ${CONTAINER_GID} ${CONTAINER_USERNAME}

# Install Steam base install for Windows via Winetricks
# nocrashdialog to force civ5 to exit when crashing instead of
# leaving a dialog box up.
RUN sudo --user=${CONTAINER_USERNAME} winetricks --force --unattended nocrashdialog steam

# Copy our xorg dummy config over.
COPY ./xorg.conf.dummy /etc/X11/xorg.conf.d/

# Copy our xorg card config over.
COPY ./xorg.conf.card.templ /etc/X11/xorg.conf.d/

# Replace the desktop resolution, bit depth, and gpu card bus id in the xorg card conf
RUN (export DESKTOP_RESOLUTION=${DESKTOP_RESOLUTION} WINDOWRES=$(echo ${DESKTOP_RESOLUTION} | cut --delimiter "x" --fields 1-2) BIT_DEPTH=$(echo ${DESKTOP_RESOLUTION} | cut --delimiter "x" --fields 3) GPU_BUSID=${GPU_BUSID} && sed --expression="s|@DESKTOP_RESOLUTION@|${WINDOWRES}|" --expression="s|@BIT_DEPTH@|${BIT_DEPTH}|" --expression="s|@GPU_BUSID@|${GPU_BUSID}|" < "/etc/X11/xorg.conf.d/xorg.conf.card.templ" > "/etc/X11/xorg.conf.d/xorg.conf.card")
RUN rm --force /etc/X11/xorg.conf.d/xorg.conf.card.templ

# Run steam full install and update
RUN /usr/bin/Xorg -dpms -novtswitch -nolisten tcp -noreset -ac +extension RANDR +extension RENDER +extension GLX +extension XVideo +extension DOUBLE-BUFFER +extension SECURITY +extension DAMAGE +extension X-Resource +extension XINERAMA -xinerama +extension COMPOSITE -logfile /var/log/xorg.log -config /etc/X11/xorg.conf.d/xorg.conf.dummy vt7 ${DISPLAY} & \
sleep 10 && (sudo --user=${CONTAINER_USERNAME} DISPLAY=${DISPLAY} timeout 500 wineconsole "/home/${CONTAINER_USERNAME}/.wine/drive_c/Program Files (x86)/Steam/Steam.exe" -tcp -no-cef-sandbox -cef-disable-gpu -cef-disable-breakpad -nocrashmonitor || true) && \
sleep ${STEAM_INSTALL_SLEEP_TIMER}

# Remove X11 lock file
RUN DISPLAY_NUMBER=$(echo ${DISPLAY} | cut --delimiter ':' --fields 2) && rm --force /tmp/.X${DISPLAY_NUMBER}-lock

# Fail if we failed to install steam
# If this step fails, you may need to
# increase the value of STEAM_INSTALL_SLEEP_TIMER
# particularly if your Internet connection
# is slow or the server itself is slow
RUN STEAM_DLLS_ARRAY=(${STEAM_DLLS}) && for dll in "${STEAM_DLLS_ARRAY[@]}"; do if [ ! -f "/home/${CONTAINER_USERNAME}/.wine/drive_c/Program Files (x86)/Steam/${dll}" ]; then echo "failed to find dll ${dll}" && exit 1; fi; done

# Install GE-Proton
# Source: https://github.com/jerluc/proton-ge-downloader/blob/main/proton-ge-downloader
COPY ./proton_ge_downloader.bash /home/${CONTAINER_USERNAME}/
RUN sudo --user=${CONTAINER_USERNAME} mkdir -p /home/${CONTAINER_USERNAME}/proton
RUN chmod +x /home/${CONTAINER_USERNAME}/proton_ge_downloader.bash
RUN sudo --user=${CONTAINER_USERNAME} /home/${CONTAINER_USERNAME}/proton_ge_downloader.bash
RUN rm /home/${CONTAINER_USERNAME}/proton_ge_downloader.bash

# Setup GE-Proton symlink
RUN PROTON_LATEST_PATH=$(find /home/${CONTAINER_USERNAME}/proton/GE-Proton* -maxdepth 0 -type d | sort --reverse --ignore-case --version-sort --ignore-leading-blanks | grep --extended --max-count 1 "GE-Proton.*") && ln --symbolic --force ${PROTON_LATEST_PATH} /home/${CONTAINER_USERNAME}/proton/GE-Proton && chown --no-dereference ${CONTAINER_USERNAME}:${CONTAINER_USERNAME} /home/${CONTAINER_USERNAME}/proton/GE-Proton

# Setup umu wine prefix
# The umu-run command should fail because the
# image build does not have privleges to create
# containers, but prerequisites are downloaded
# and nocrashdialog is set which is what we want
RUN cd /home/${CONTAINER_USERNAME} && (sudo --user=${CONTAINER_USERNAME} -E WINEDEBUG=+seh,+warn,+loaddll,+timestamp WINEDLLOVERRIDES="lsteamclient=d;" PROTONPATH="/home/${CONTAINER_USERNAME}/proton/GE-Proton" umu-run winetricks nocrashdialog || true)

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

# Create civ data root
RUN sudo --user=${CONTAINER_USERNAME} mkdir -p "${CIV_DATA_ROOT}"

# Start the supervisor service to manage processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
