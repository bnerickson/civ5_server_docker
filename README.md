civ5_docker_server
==================

Scripts and Dockerfiles to install and run a dedicated Civilization 5 server on a headless, GPU-less Linux machine.

## Major Fork Changes

1. This fork runs on the fedora:latest container.
2. All AWS-specific statements have been removed in favor of (optional) nfty notifications (see https://docs.ntfy.sh/)
3. x11vnc has been removed in favor of x0vncserver because remotely connecting to the former in the fedora:latest container was not working for me.
4. Wine (or winetricks) is "sandboxing" by default, so the "My Games" directory is now in the specific wine prefix as opposed to /root.
5. Wine and winetricks are installed from repos as opposed to being compiled.
6. WINEARCH=win32 has been removed, it is deprecated in the latest wine and works fine as-is w/WoW64.
7. Steam installed with winetricks.
8. Steam running with a lot of CEF (chromium) features disabled to it can run properly.
9. Applied a patch to fix libstrangle compilation on latest gcc.

## How does it work? (briefly)

So Civ 5 Server is a Windows-only GUI application, that needs to render frames with ~~OpenGL~~ Direct3D (translated to OpenGL with wine)... This Docker setup creates a virtual X11 framebuffer for Civ to render to, provides a VNC server so you can remote in, installs Mesa such that the CPU can render frames (so no GPU needed), and libstrangle so that Civ only runs at 2 FPS, so rendering doesn't consume the CPU so much (though it still takes an enormous amount of CPU time).

## When was this last tested

This fork was last tested and working 2025/09/23 with Fedora 42 (fedora:latest) running the latest wine at that time (wine 10.13).

## Known Issues / TODO:

1. Remove overlay_patch.path once https://gitlab.com/torkel104/libstrangle/-/merge_requests/29 is merged.
2. Create a docker compose for this.
3. Move the NTFY variable to a separate, non-git tracked config file that is created by build.sh.

## How do you use it?

**1:** First, Civilization 5 needs to be installed into the `civ5game` directory, as well as the `CivilizationV_Server.exe` file from the Civ 5 SDK.  You can copy those files over yourself, or use provided script as `./install_civ.sh <steam_username> <steam_password>`.  Note that sometimes steam_cmd can SEGFAULT for no apparent reason, but re-running the install_civ.sh script over and over until the installs complete "works".

**2:** (Optional) If you wish to setup a simple notification to notify players when it is their turn using nfty, setup a nfty notification topic (see https://docs.ntfy.sh/ for more details), then update `NFTY_TOPIC=""` in `./server/Dockerfile` with the topic name that was created between the quotes.  All players should subscribe to the nfty topic to receive notifications.

**3:** Now you can build the container with `./build.sh`.

**4:** Now you can launch the container with `./run.sh`.

**5:** After the container starts running, you should be able to remote in with VNC. The `run.sh` script is set up to only allow connections from localhost, so you'll want to open up an SSH tunnel if remoting in from a different machine first (`ssh -NL 5900:127.0.0.1:5900 ${USERNAME}@${SERVER_IP}`).

Then, you should be able to point your VNC client at `localhost` and see Civ 5 running. Steam will also be running - it needs to stay running the background for Civ to not crash, though you don't need to log in to it.

**6:** Setup the game through the VNC connection, and hope that it works and people can connect.

# Ports you might need to open/let through a firewall

`27016 UDP` is the only port you need to allow incoming traffic through. If you're just using plain `iptables` as a firewall, bringing up the docker container should open that port for you.

## Thanks

A big thanks goes out to:

1. https://gitlab.com/Cerothen
2. https://github.com/Andrew-Dickinson
3. https://gitlab.com/CraftedCart
4. https://gitlab.com/Hexarmored

Without their work/forks this would not work at all.
