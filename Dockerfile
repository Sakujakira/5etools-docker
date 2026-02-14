FROM httpd:2.4.66
ENV PUID=${PUID:-1000} \
    PGID=${PGID:-1000}

# Copy init.sh and set permissions
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Install deps + cleanup (reduced CVEs/Bloat)
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install --no-install-recommends curl git jq && \
    rm -rf /var/lib/apt/lists/*


RUN echo "<Location /server-status>\n"\
    "    SetHandler server-status\n"\
    "    Order deny,allow\n"\
    "    Allow from all\n"\
    "</Location>\n"\
    >> /usr/local/apache2/conf/httpd.conf

WORKDIR /usr/local/apache2/htdocs/
RUN chown -R $PUID:$PGID /usr/local/apache2/htdocs

# Labels for registry
LABEL org.opencontainers.image.source="https://github.com/Sakujakira/5etools-docker" \
      org.opencontainers.image.description="5eTools Docker Container"

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["/bin/bash", "/init.sh"]