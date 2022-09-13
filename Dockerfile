# First we get and update last Ubuntu image
FROM    ubuntu:jammy
LABEL   maintainer="cyd@9bis.com"

ARG     PROXY_CERT 
RUN     test -z "${PROXY_CERT}" || { echo "${PROXY_CERT}" | base64 -d | tee /usr/local/share/ca-certificates/ca-local.crt > /dev/null && update-ca-certificates ; }

# We prepare environment
ARG     TZ=${TZ:-Etc/UTC}
ARG     DEBIAN_FRONTEND=noninteractive
RUN     \
        echo "Timezone and locale" >&2                     \
        && apt-get update                                  \
        && apt-get install -y                              \
          apt-utils                                        \
          software-properties-common                       \
          tzdata                                           \
        && apt-get clean                                   \
        && apt-get autoremove -y                           \
        && rm -rf /tmp/* /var/tmp/*                        \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*    \
        && echo "Timezone and locale OK" >&2

# Second we install VNC, noVNC and websockify
RUN     \
        echo "install VNC, noVNC and websockify" >&2       \
        && apt-get update                                  \
        && apt-get install -y --no-install-recommends      \
          libpulse0                                        \
          x11vnc                                           \
          xvfb                                             \
          novnc                                            \
          websockify                                       \
        && apt-get clean                                   \
        && apt-get autoremove -y                           \
        && rm -rf /tmp/* /var/tmp/*                        \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*    \
        && echo "install VNC, noVNC and websockify OK" >&2

# And finally xfce4 and ratpoison desktop environments
RUN     \
        echo "Install xfce4 and ratpoison" >&2             \
        && apt-get update                                  \
        && apt-get install -y --no-install-recommends      \
          dbus-x11                                         \
        && apt-get install -y                              \
          ratpoison                                        \
          xfce4 xfce4-terminal xfce4-eyes-plugin           \
          xfce4-systemload-plugin xfce4-weather-plugin     \
          xfce4-whiskermenu-plugin xfce4-clipman-plugin    \
          xserver-xorg-video-dummy                         \
        && apt-get clean                                   \
        && apt-get autoremove -y                           \
        && rm -rf /tmp/* /var/tmp/*                        \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*    \
        && echo "Install xfce4 and ratpoison OK" >&2

# We add some tools
RUN     \
        echo "Install some tools" >&2                      \
        && apt-get update                                  \
        && apt-get install -y --no-install-recommends      \
          curl                                             \
          dumb-init                                        \
          figlet                                           \
          jq                                               \
          libnss3-tools                                    \
          mlocate                                          \
          net-tools                                        \
          sudo                                             \
          vim                                              \
          vlc                                              \
          xz-utils                                         \
          zip wget psmisc                                             \
        && apt-get install -y thunar-archive-plugin        \
        && apt-get clean                                   \
        && apt-get autoremove -y                           \
        && rm -rf /tmp/* /var/tmp/*                        \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*    \
        && echo "Install some tools OK" >&2

# We install firefox, directly from Mozilla (not from snap)
RUN     \
        echo "Install Firefox from Mozilla" >&2               \
        && apt-get update                                     \
        && add-apt-repository ppa:mozillateam/ppa             \
        && printf '\nPackage: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' > /etc/apt/preferences.d/mozilla-firefox                     \
        && printf 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' > /etc/apt/apt.conf.d/51unattended-upgrades-firefox \
        && apt-get update                                     \
        && apt-get install -y firefox --no-install-recommends \
        && apt-get clean                                      \
        && apt-get autoremove -y                              \
        && rm -rf /tmp/* /var/tmp/*                           \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*       \
        && echo "Install Firefox from Mozilla OK" >&2

# Install Wine

# RUN dpkg --add-architecture i386
# RUN wget -nc -O /usr/share/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
# RUN wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
# RUN apt-get update && \
#     apt-get install -y --install-recommends wine32 wine64 cabextract msitools xvfb xdotool jwm procps


# We can add additional GUI programs
# RUN     \
#         echo "Install additional GUI programs" >&2         \
#         && apt-get update                                  \
#         && apt-get install -y --no-install-recommends      \
#           notepadqq                                       \
#         && apt-get clean                                   \
#         && apt-get autoremove -y                           \
#         && rm -rf /tmp/* /var/tmp/*                        \
#         && rm -rf /var/lib/apt/lists/* /var/cache/apt/*    \
#         && echo "Install additional GUI programs OK" >&2

# We add sound
# RUN     printf 'default-server = unix:/run/user/1000/pulse/native\nautospawn = no\ndaemon-binary = /bin/true\nenable-shm = false' > /etc/pulse/client.conf

# We add a simple user with sudo rights
ENV     USR=user
ARG     USR_UID=${USER_UID:-1000}
ARG     USR_GID=${USER_GID:-1000}

RUN     \
        echo "Add simple user" >&2                                                      \
        && groupadd --gid ${USR_GID} ${USR}                                             \
        && useradd --uid ${USR_UID} --create-home --gid ${USR} --shell /bin/bash ${USR} \
        && echo "${USR}:${USR}01" | chpasswd                                            \
        && echo ${USR}'     ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers                     \
	&& echo "Add simple user OK" >&2

# Two ports are availables: 5900 for VNC client, and 6080 for browser access via websockify
EXPOSE  5900 6080

# We set localtime
RUN      if [ "X${TZ}" != "X" ] ; then if [ -f /usr/share/zoneinfo/${TZ} ] ; then rm -f /etc/localtime ; ln -s /usr/share/zoneinfo/${TZ} /etc/localtime ; fi ; fi

# And here is the statup script, everything else is in there
COPY    entrypoint.sh /entrypoint.sh
RUN     chmod 755 /entrypoint.sh

# We do some specials
RUN     \
        updatedb ;                                       \
        apt-get clean                                    \
        && apt-get autoremove -y                         \
        && rm -rf /tmp/* /var/tmp/*                      \
        && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# We change user
USER    ${USR}
WORKDIR /home/${USR}
COPY    functions.sh /home/${USR}/.functions.sh
COPY    bgimage.jpg /usr/share/backgrounds/xfce/bgimage.jpg
RUN     \
        printf 'if [[ $- = *i* ]] ; then test -f ~/.functions.sh && . ~/.functions.sh ; fi' >> /home/${USR}/.bashrc

# Install CODESYS
# ADD install2.sh /home/${USR}/
# RUN ./install2.sh --silent
# # RUN test -f /home/${USR}/.wine.cds/drive_c/CODESYS/CODESYS/Common/CODESYS.exe

# ADD codesys.sh /usr/local/bin/codesys
# ADD codesyscontrol.sh /usr/local/bin/codesyscontrol
# ADD scripts /usr/local/share/codesys

# RUN codesys install https://store.codesys.com/ftp_download/3S/LinuxSL/2302000005/3.5.16.0/CODESYS%20Control%20for%20Linux%20SL%203.5.16.0.package

#ENTRYPOINT [ "/usr/bin/dumb-init", "--", "/entrypoint.sh" ]
ENTRYPOINT [ "/entrypoint.sh" ]
# ENTRYPOINT [ "sleep", "infinity"]
