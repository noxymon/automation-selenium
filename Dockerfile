FROM maven:3.9-amazoncorretto-21-debian-bookworm as builder
LABEL authors="noxymon"

ARG VERSION
ARG TARGETARCH
ARG TARGETVARIANT

#========================
# Miscellaneous packages
# Includes minimal runtime used for executing non GUI Java programs
#========================
RUN apt-get -qqy update \
  && apt-get upgrade -yq \
  && apt-get -qqy --no-install-recommends install \
    acl \
    bzip2 \
    ca-certificates \
    tzdata \
    sudo \
    unzip \
    wget \
    jq \
    curl \
    supervisor \
    gnupg2 \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ENV TZ "Asia/Jakarta"
RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    cat /etc/timezone

#========================================
# Add normal user and group with passwordless sudo
#========================================
RUN groupadd seluser \
         --gid 1201 \
  && useradd seluser \
         --create-home \
         --gid 1201 \
         --shell /bin/bash \
         --uid 1200 \
  && usermod -a -G sudo seluser \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
  && echo 'seluser:secret' | chpasswd
ENV HOME=/home/seluser

#======================================
# Add Grid check script
#======================================
COPY check_grid.sh entrypoint.sh /opt/bin/
#======================================
# Add Supervisor configuration file
#======================================
COPY supervisord.conf /etc

#==========
# Selenium & relaxing permissions for OpenShift and other non-sudo environments
#==========
RUN  mkdir -p /opt/selenium /opt/selenium/assets /var/run/supervisor /var/log/supervisor \
  && touch /opt/selenium/config.toml \
  && chmod -R 777 /opt/selenium /opt/selenium/assets /var/run/supervisor /var/log/supervisor /etc/passwd \
  && wget --no-verbose https://github.com/SeleniumHQ/selenium/releases/download/selenium-${VERSION}/selenium-server-${VERSION}.jar \
    -O /opt/selenium/selenium-server.jar \
  && chgrp -R 0 /opt/selenium ${HOME} /opt/selenium/assets /var/run/supervisor /var/log/supervisor \
  && chmod -R g=u /opt/selenium ${HOME} /opt/selenium/assets /var/run/supervisor /var/log/supervisor \
  && setfacl -Rm u:seluser:rwx /opt /opt/selenium ${HOME} /opt/selenium/assets /var/run/supervisor /var/log/supervisor

#===================================================
# Run the following commands as non-privileged user
#===================================================
USER 1200:1201
# Boolean value, maps "--bind-host"
ENV SE_BIND_HOST false

CMD ["/opt/bin/entrypoint.sh"]

USER root

# Install Chromium
# RUN echo "deb http://http.us.debian.org/debian/ stable non-free contrib main" >> /etc/apt/sources.list \
RUN echo "deb http://deb.debian.org/debian/ bookworm main" >> /etc/apt/sources.list \
  && apt-get update -qqy \
  && apt-get -qqy install chromium \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#=================================
# Chrome Launch Script Wrapper
#=================================
COPY script/wrap_chrome_binary.sh /opt/bin/wrap_chrome_binary
RUN chmod +x /opt/bin/wrap_chrome_binary \
    && ./opt/bin/wrap_chrome_binary

#============================================
# Chromium webdriver
#============================================
RUN apt-get update -qqy \
  && apt-get -qqy install chromium-driver \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN echo "chrome" > /opt/selenium/browser_name
RUN chromium --version | awk '{print $2}' > /opt/selenium/browser_version
RUN echo "\"goog:chromeOptions\": {\"binary\": \"/usr/bin/chromium\"}" > /opt/selenium/browser_binary_location

USER 1200

#====================================
# Scripts to run Selenium Standalone
#====================================
COPY --chown="${SEL_UID}:${SEL_GID}" script/start-selenium.sh /opt/bin/start-selenium-standalone.sh

# Copying configuration script generator
COPY --chown="${SEL_UID}:${SEL_GID}" script/generate_config.sh /opt/bin/generate_config