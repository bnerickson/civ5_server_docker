civ5_docker_server
==================

Scripts and Dockerfiles to install and run a dedicated Civilization 5 server on a headless Linux machine.

## Major Fork Changes

1. This fork runs on a fedora container.
2. All AWS-specific statements have been removed in favor of optional nfty (see https://docs.ntfy.sh/) and/or Discord notifications (see https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) that are fired off when a player disconnects and on a weekly basis.  The latter uses a different database based on players that have clicked "Next Turn" ergo it is more accurate.  However, because it's trivial to spam notifications this way, it is only triggered weekly on the backend.
3. x11vnc has been removed in favor of x0vncserver because remotely connecting to the former in the fedora container was not working for me.
4. WINE/Proton are "sandboxing" by default, so the "My Games" directory is now in the specific wine prefix as opposed to /root.
5. winetricks and umu-launcher are installed from repos as opposed to being compiled.
6. WINEARCH=win32 has been removed.  It is deprecated and its replacement--WoW64--is feature-complete in WINE.
7. Steam installed via winetricks.
8. Eliminate requirement for Steam to run in the background while Civ5 is running.
9. Steam initial execution (to grab required DLLs) now works because CEF (chromium) features are now disabled.
10. Added ability to define custom dnf repos.
11. Added script utilizing xdotool to automatically reload the most recent autosave when the server is started.
12. (Optional) Runs with a dedicated GPU to offload some processing from the CPU.
13. (Optional) Ability to apply CPU limiting to the CivilizationV.exe.

## How does it work? (briefly)

Civ 5 Server is a Windows-only GUI application that needs to render frames with ~~OpenGL~~ Direct3D (translated to OpenGL with wine).  This Docker setup creates a virtual X11 framebuffer for Civ to render to, provides a VNC server so you can remote in, and installs Mesa such that the CPU can render frames.  However, in this branch a GPU is used to offload the graphics processing.

The attempt_autostart.bash script will, using xdotool and precise mouse coordinates based on the fixed 1920x1080 desktop resolution (though 1600x900 is also supported via manual Dockerfile change), select the latest autosave and automatically start the server.  This takes place every time the server is started either when the container starts normally or when Civilization V crashes and restarts.  If there is no autosave present, then the server must be configured manually via the GUI via VNC before it will start.  Therefore, if you wish to start and configure a brand new game, be sure to delete the old autosaves in the `./civ5save/Saves/multi/auto` directory first.

## When was this last tested

This fork was last tested and working 2026/05/18 with fedora:44 running Proton-GE 10.34.  GPU support has _only_ been tested with AMD RX and Intel Iris GPUs (in particular the Radeon RX 550 and Intel Iris Plus Graphics 655).

## Known Issues / TODO:

None

## Instructions

1. Clone this repository on your Linux server `git clone https://github.com/bnerickson/civ5_server_docker` as a non-root user with sudo priviledges and enter the cloned directory with `cd civ5_server_docker`
2. Install Civilization V and the Civilization V SDK (`CivilizationV_Server.exe`) into the `civ5game` directory using the provided install script: `./install_civ.sh <steam_username> <steam_password>`

**Note:** Sometimes `steam_cmd` can SEGFAULT for no apparent reason, but re-running the install script over and over until the installs complete is a valid, if annoying, workaround.  You can also copy the files over manually, but using the install script is recommended.

3. Copy the example config file `build.conf.example` to `build.conf`: `cp build.conf.example build.conf`
4. The following are **REQUIRED** configuration change updates you must make in `build.conf`:
    * `CONTAINER_USERNAME` - Set this to the non-root user on your system that will run the container and game.
    * `CONTAINER_GROUP` - Set this to the non-root group on your system that will run the container and game.
5. The following are **OPTIONAL** customizations you may change in `build.conf`:
    * `CONTAINER_NAME` - Set this to a custom value if you are running multiple containers simulatenously.  The container name, service name, network name, and image name all use this as the suffix in their names. **[Default: "civ5"]**
    * `SCRIPT_TIMEZONE` - Set this to your system's timezone for weekly notifications. **[Default: "America/Los_Angeles"]**
    * `GPU_BUSID` - To use a dedicated GPU, get your GPU's PCI BusNumber:DeviceNumber.FunctionNumber from the output of lspci (e.g. 00:02.0) and uncomment/update the GPU_BUSID variable in `build.conf` **[Default: "ff:ff.ff", this is a special value to use a dummy output]**
    * `CPU_LIMIT` - Set this to restrict CivilizationV to a specified percentage of processing.  This value is measured as a percentage of ALL cores on your system.  For instance, if you have 8-core processor and want to use a maximum of 4-cores of processing power, change the value to "400" **[Default: "100", which uses a single-core's worth of processing power and is usually sufficient]**
    * `VNC_PORT` - Set this to a custom value TCP port value if you are running multiple containers simulatenously **[Default: "5900", which is tcp/5900]**
    * `CIV5_FWD_PORT` - Set this to a custom UDP port value if you are running multiple containers simulatenously; traffic destined to the server on this port will be redirected to udp/27016 in the container.  A client MUST connect to `CIV5_FWD_PORT` port via source NAT if the value is NOT udp/27016.   The mechanism by which a client performs source NAT is out-of-scope of this document (hint: On Windows a good place to start is portproxy ala `netsh interface portproxy add v4tov4 listenport=$listenPort listenaddress=$listenAddress connectaddress=$civIp connectport$connectPort`) **[Default: "27016", which is udp/27016]**
    * `NTFY_TOPIC` - If you wish send notifications to users concerning the turn status via nfty, setup a nfty notification topic (see https://docs.ntfy.sh/ for details on how this is done).  Then, set this variable to the notification topic name.  If left empty, no ntfy notifications will be sent. **[Default: ""]**
    *  If you wish send notifications to users concerning the turn status via a Discord webhook, setup a webook in the channel of your choice (see https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks for instructions on how this is done).  Then update **BOTH** of the following:
        * `DISCORD_WEBHOOK_ID` - Set this to the Discord webhook ID for the webhook you created.  If left empty, no Discord notifications will be sent. **[Default: ""]**
        * `DISCORD_WEBHOOK_TOKEN` - Set this to the Discord token for the webhook you created.  If left empty, no Discord notifications will be sent. **[Default: ""]**
    * `STEAM_INSTALL_SLEEP_TIMER` - Set this to modify the time in seconds spent waiting for Steam to auto-update during the container image build.  This may be necessary if you have a slow Internet connection or slow server in-general.  If Steam does not install successfully, increase this value. **[Default: 120]**
    * `DXVK_FRAME_RATE` - Set this to specify the frame rate that the CivilizationV GUI will render at. **[Default: 2, that is 2fps which is the lowest useable setting].**
    * `GE_PROTON_VERSION` - Set this to a hard-coded version of ProtonGE to download and install.  The format of this option MUST be `GE-Proton<version>` (Ex: GE-Proton10-29) **[Default: latest, which is a special value that downloads the latest version of GE-Proton]**
6. Other **OPTIONAL** customizations:
    * (Optional) If you wish to use a custom `fedora.repo`, `fedora-cisco-openh264.repo`, or `fedora-updates.repo` file, create and/or paste them into the `server/` directory.  If the files do not exist then the Docker build process will use the public Fedora repositories. This can help speed up container image build times dramatically if a local dnf mirror is available.
7. Build the container prerequisites with the following command: `./build.sh`.
8. Build and launch the container with the command `docker compose -f ./server/docker-compose.yml up` (it should take 7-10 minutes to build).

**Note:** If the build crashes when installing/running Steam via winetricks, rebuilding the container again by re-running the command is often enough to fix the issue.

9. After the container starts running, you should be able to remote in with VNC. The container is setup to only allow connections from localhost, so you'll want to open up an SSH tunnel if you are remoting in from a different machine (Ex: `ssh -NL ${VNC_PORT}:127.0.0.1:${VNC_PORT} ${USERNAME}@${SERVER_IP}`).
10. Setup the game through the VNC connection.  The mouse cursor WILL jump around because it is attempting to autostart (ignore it).  Make sure port forwarding is setup (see Port Forwarding section below) and users should be able to connect to your game.

## systemd Integration

The following is an example systemd service defintion I use to manage the container (`/etc/systemd/system/docker.civ5.service`):

```
[Unit]
Description=Docker Civilization V Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=/home/game/containers/civ5_server_docker/server
ExecStart=/usr/bin/docker compose --file docker-compose.yml up
ExecStop=/usr/bin/docker compose --file docker-compose.yml down
TimeoutStartSec=0
Restart=always

[Install]
WantedBy=multi-user.target
```

Replace the `WorkingDirectory=/home/game/containers/civ5_server_docker/server` line in the service definition with the path to your `./server` directory, run the `systemctl daemon-reload` command, then run the `systemctl start docker.civ5.service` command to build/start the container.

## Port Forwarding

`27016 UDP` is the only port you need to allow incoming traffic through. If you're just using plain `iptables` or `nftables` as a firewall, bringing up the docker container should open that port for you.  If you are running multiple instances of the container, then the UDP port configured under CIV5_FWD_PORT must also be opened.

## Credits

A big thanks goes out to:

1. https://gitlab.com/Cerothen
2. https://github.com/Andrew-Dickinson
3. https://gitlab.com/CraftedCart
4. https://gitlab.com/Hexarmored

Without their work/forks this would not work at all.

The Proton-GE script is modified from this repo (thanks, jerluc):

* https://github.com/jerluc/proton-ge-downloader
