civ5_docker_server
==================

Scripts and Dockerfiles to install and run a dedicated Civilization 5 server on a headless, GPU-less Linux machine.

## Major Fork Changes

1. This fork runs on the fedora:latest container.
2. All AWS-specific statements have been removed in favor of (optional) nfty and/or Discord notifications (see https://docs.ntfy.sh/) that are fired off when a player disconnects and on a weekly basis.  The latter uses a different database based on players that have clicked "Next Turn" ergo it is more accurate.  However, because it's trivial to spam notifications this way, it is only fired off weekly.
3. x11vnc has been removed in favor of x0vncserver because remotely connecting to the former in the fedora:latest container was not working for me.
4. Wine (or winetricks) is "sandboxing" by default, so the "My Games" directory is now in the specific wine prefix as opposed to /root.
5. Wine and winetricks are installed from repos as opposed to being compiled.
6. WINEARCH=win32 has been removed, it is deprecated in the latest wine and works fine as-is w/WoW64.
7. Steam installed with winetricks.
8. Steam running with a lot of CEF (chromium) features disabled to it can run properly.
9. Applied a patch to fix libstrangle compilation on latest gcc.
10. Added ability to defined custom dnf repos.
11. Added the "gpu-support" branch which allows hardware acceleration of the launched game when a GPU is available.

## How does it work? (briefly)

Civ 5 Server is a Windows-only GUI application that needs to render frames with ~~OpenGL~~ Direct3D (translated to OpenGL with wine).  This Docker setup creates a virtual X11 framebuffer for Civ to render to, provides a VNC server so you can remote in, installs Mesa such that the CPU can render frames (so no GPU needed), and libstrangle to limit Civ to only 2 FPS preventing rendering from consuming too many CPU cycles (though it still takes an enormous amount of CPU).

## When was this last tested

This fork was last tested and working 2025/10/02 with Fedora 42 (fedora:latest) running the latest wine at that time (wine 10.15).

## Known Issues / TODO:

1. Remove overlay_patch.path once https://gitlab.com/torkel104/libstrangle/-/merge_requests/29 is merged.
2. Create a docker compose for this.

## How do you use it?

**1.** Clone this repository on your Linux server `git clone https://github.com/bnerickson/civ5_server_docker` and enter the cloned directory with `cd civ5_server_docker`

**2:** Install Civilization V and the Civilization V SDK (`CivilizationV_Server.exe`) into the `civ5game` directory.  You can copy those files over yourself or use the provided install_civ.sh script as follows (note that sometimes steam_cmd can SEGFAULT for no apparent reason, but re-running the install_civ.sh script over and over until the installs complete is a valid, if annoying, workaround): `./install_civ.sh <steam_username> <steam_password>`

**3:** Build the container prerequisites with the following command: `./build.sh`

**4a:** (Optional) If you wish to setup a simple notification to notify players when it is their turn using nfty, setup a nfty notification topic (see https://docs.ntfy.sh/ for details on how this is done).  The name of the subscription you create will be used in the next step when building the container. All players should subscribe to the nfty topic to receive notifications.

**4b:** (Optional) If you wish to setup a simple notification to notify players when it is their turn using Discord, setup a webook in the channel of your choice.  The webhook ID and webhook TOKEN will be used in the next step when building the container.

**4c:** (Optional) If you wish to use a custom `fedora.repo`, `fedora-cisco-openh264.repo`, or `fedora-updates.repo` file, create and/or paste them into the `server/` directory.  Otherwise, the Docker build process will use the public Fedora repositories. I have a local Fedora mirror available, so this helps speed up container image build times by around 50%.

**5:** Build the container with the command `docker build -t civ5server "./server" --build-arg NTFY_TOPIC=""` replacing the empty value in quotes after `NTFY_TOPIC=` with your ntfy subscription name if you choose to use it (Ex: `NTFY_TOPIC="sample_subscription_name"`).  It will not be used if the value is empty.

**6:** Launch the container with the following command: `./run.sh`

**7:** After the container starts running, you should be able to remote in with VNC. The `run.sh` script is setup to only allow connections from localhost, so you'll want to open up an SSH tunnel if you are remoting in from a different machine (Ex: `ssh -NL 5900:127.0.0.1:5900 ${USERNAME}@${SERVER_IP}`).

Then, you should be able to point your VNC client at `localhost` and see Civilization V running. Steam will also be running - it needs to stay running the background for Civilization V to not crash, though you don't need to log in to it.

**8:** Setup the game through the VNC connection, and hope that it works and people can connect.

# Ports you might need to open/let through a firewall

`27016 UDP` is the only port you need to allow incoming traffic through. If you're just using plain `iptables` as a firewall, bringing up the docker container should open that port for you.

## Thanks

A big thanks goes out to:

1. https://gitlab.com/Cerothen
2. https://github.com/Andrew-Dickinson
3. https://gitlab.com/CraftedCart
4. https://gitlab.com/Hexarmored

Without their work/forks this would not work at all.
