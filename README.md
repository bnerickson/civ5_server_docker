civ5_docker_server
==================

Scripts and Dockerfiles to install and run a dedicated Civilization 5 server on a headless, GPU-less Linux machine.

## Major Fork Changes

1. This fork runs on the fedora:latest container.
2. All AWS-specific statements have been removed in favor of simple email notifications (to be tested).
3. x11vnc running in Xvfb has been removed in favor of tigervnc because connecting to the latter in the fedora:latest container was not working for me.
4. wine (or winetricks) is "sandboxing" by default, so the "My Games" directory is now in the specific wine prefix as opposed to /root.
5. wine and winetricks are installed from repos as opposed to being compiled.
6. WINEARCH=win32 has been removed, it is deprecated in the latest wine and works fine as-is.
7. steam installed with winetricks.
8. Steam running with a lot of CEF (chromium) features disabled to it can run properly.
9. Applied a patch to fix libstrangle compilation on latest gcc.
10. Updated smtp_server.py to use aiosmtpd instead of the SMTPServer lib as the latter is deprecated+removed (to be tested).

## How does it work? (briefly)

So Civ 5 Server is a Windows-only GUI application, that needs to render frames with ~~OpenGL~~ Direct3D (translated to OpenGL with wine)... This Docker setup creates a virtual X11 framebuffer for Civ to render to, provides a VNC server so you can remote in, installs Mesa such that the CPU can render frames (so no GPU needed), and libstrangle so that Civ only runs at 2 FPS, so rendering doesn't consume the CPU so much (though it still takes an enormous amount of CPU time).

## When was this last tested

This fork was last tested and working 2025/08/25 with Fedora 42 (fedora:latest) running the latest wine at that time (wine 10.13).

## Known Issues / TODO:

1. Email has not been tested.
2. Remove overlay_patch.path once https://gitlab.com/torkel104/libstrangle/-/merge_requests/29 is merged.
3. Convert MPList.lua to a patch.

## How do you use it?

**1:** First, Civilization 5 needs to be installed into the `civ5game` directory, as well as the `CivilizationV_Server.exe` file from the Civ 5 SDK.  You can copy those files over yourself, or use provided script as `./install_civ.sh <steam_username> <steam_password>`.

**2:** Now you can build the container with `./build.sh`.

**3:** Now you can launch the container with `./run.sh`.

**4:** After the container starts running, you should be able to remote in with VNC. The `run.sh` script is set up to only allow connections from localhost, so you'll want to open up an SSH tunnel if remoting in from a different machine first (`ssh -NL 5901:127.0.0.1:5901 ${USERNAME}@${SERVER_IP}`).

Then, you should be able to point your VNC client at `localhost` and see Civ 5 running. Steam will also be running - it needs to stay running the background for Civ to not crash, though you don't need to log in to it.

**5:** Setup the game through the VNC connection, and hope that it works and people can connect.

# Ports you might need to open/let through a firewall

`27016 UDP` is the only port you need to allow incoming traffic through. If you're just using plain `iptables` as a firewall, bringing up the docker container should open that port for you.

## Thanks

A big thank you to https://gitlab.com/Cerothen, https://github.com/Andrew-Dickinson, https://gitlab.com/CraftedCart, and https://gitlab.com/Hexarmored
without whom this fork would not work at all.
