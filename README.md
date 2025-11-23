civ5_docker_server
==================

Scripts and Dockerfiles to install and run a dedicated Civilization 5 server on a headless, GPU-less Linux machine.

## Major Fork Changes

1. This fork runs off of a fedora container.
2. All AWS-specific statements have been removed in favor of optional nfty (see https://docs.ntfy.sh/) and/or Discord notifications (see https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) that are fired off when a player disconnects and on a weekly basis.  The latter uses a different database based on players that have clicked "Next Turn" ergo it is more accurate.  However, because it's trivial to spam notifications this way, it is only triggered weekly on the backend.
3. x11vnc has been removed in favor of x0vncserver because remotely connecting to the former in the fedora container was not working for me.
4. Wine is "sandboxing" by default, so the "My Games" directory is now in the specific wine prefix as opposed to /root.
5. Wine and winetricks are installed from repos as opposed to being compiled.
6. WINEARCH=win32 has been removed, it is deprecated in the latest wine and works fine as-is w/WoW64.
7. Steam and DXVK installed with winetricks.
8. Eliminate requirement for Steam to run in the background while Civ5 is running.
9. Added ability to define custom dnf repos.
10. [unmaintained] Added the "gpu-support" branch which allows hardware acceleration of the launched game when a GPU is available.
11. Added script utilizing xdotool to automatically reload the most recent autosave when the server is started.

## How does it work? (briefly)

Civ 5 Server is a Windows-only GUI application that needs to render frames with ~~OpenGL~~ Direct3D (translated to OpenGL with wine).  This Docker setup creates a virtual X11 framebuffer for Civ to render to, provides a VNC server so you can remote in, and installs Mesa such that the CPU can render frames (so no GPU needed).

The attempt_autostart.bash script will, using xdotool and precise mouse coordinates based on the fixed 1600x900 desktop resolution, select the latest autosave and automatically start the server.  This takes place every time the server is started whether when the container starts or when Civilization V crashes.  If there is no autosave present, then the server must be configured manually via the GUI via VNC before it will start.  Therefore, if you wish to start and configure a brand new game, be sure to delete the old autosaves in the `./civ5save/Saves/multi/auto` directory first.

## When was this last tested

This fork was last tested and working 2025/11/23 with Fedora 42 (fedora:42) running wine 10.15 w/dxvk 2.7.1.

## Known Issues / TODO:

1. Get this working on Fedora 43.  A version using proton and umu-launcher is currently in the works, but will probaby exist on its own branch because it requires elevated privileges on the container itself.

## Instructions

**1.** Clone this repository on your Linux server `git clone https://github.com/bnerickson/civ5_server_docker` and enter the cloned directory with `cd civ5_server_docker`

**2:** Install Civilization V and the Civilization V SDK (`CivilizationV_Server.exe`) into the `civ5game` directory as a user with sudo privileges using the provided install script as follows: `./install_civ.sh <steam_username> <steam_password>`

Note that sometimes steam_cmd can SEGFAULT for no apparent reason, but re-running the install script over and over until the installs complete is a valid, if annoying, workaround.  You can also copy the files over manually, but using the install script is recommended.

**3:** Build the container prerequisites with the following command: `./build.sh`

**4a:** (Optional) If you wish to notify users of turn status via nfty, setup a nfty notification topic (see https://docs.ntfy.sh/ for details on how this is done).  Add the chosen notification topic name to `./server/ntfy_topic.txt` with no empty newlines below it.  If left blank it will not be used.

**4b:** (Optional) If you wish to notify users of turn status via a Discord webhook, setup a webook in the channel of your choice (see https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks for instructions on how this is done).  Add the resultant webhook ID and webhook Token values to the `./server/discord_webhook_id.txt` and `./server/discord_webhook_token.txt` files respectively with no empty newlines below them.  If left blank it will not be used.

**4c:** (Optional) If you wish to use a custom `fedora.repo`, `fedora-cisco-openh264.repo`, or `fedora-updates.repo` file, create and/or paste them into the `server/` directory.  If the files do not exist then the Docker build process will use the public Fedora repositories. This can help speed up container image build times dramatically if a local dnf mirror is available.

**4d:** (Optional) If you wish to edit the time spent waiting for Steam to auto-update during container construction, update the `STEAM_INSTALL_SLEEP_TIMER` argument in `./server/docker-compose.yml`.  This might be necessary if you have a slow Internet connection or slow server in-general.  If Steam does not install successfully, this is the first place to look (default: 120s).

**4e:** (Optional) If you wish to set the default frame rate that the GUI runs at to a custom value, update the `DXVK_FRAME_RATE` variable in `./server/civ5.env` (default: 2, that is 2fps).

**5:** Build and launch the container with the command `docker compose -f ./server/docker-compose.yml up` (it should take 7-10 minutes to build).  If the build crashes when installing/running Steam via winetricks, rebuilding the container again is often enough to fix the issue.

**6:** After the container starts running, you should be able to remote in with VNC. The container is setup to only allow connections from localhost, so you'll want to open up an SSH tunnel if you are remoting in from a different machine (Ex: `ssh -NL 5900:127.0.0.1:5900 ${USERNAME}@${SERVER_IP}`).

**7:** Setup the game through the VNC connection, make sure port forwarding is setup (see Port Forwarding section below) and users should be able to connect to your game.

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

`27016 UDP` is the only port you need to allow incoming traffic through. If you're just using plain `iptables` or `nftables` as a firewall, bringing up the docker container should open that port for you.

## Thanks

A big thanks goes out to:

1. https://gitlab.com/Cerothen
2. https://github.com/Andrew-Dickinson
3. https://gitlab.com/CraftedCart
4. https://gitlab.com/Hexarmored

Without their work/forks this would not work at all.
