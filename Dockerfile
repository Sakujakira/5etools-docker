FROM httpd:2-alpine

ARG PUID=1000
ARG PGID=1000

ENV PUID=$PUID \
    PGID=$PGID

# Copy init.sh and set permissions
COPY --chmod=755 init.sh /init.sh

# Install deps + cleanup (reduced CVEs/Bloat)
RUN apk add --no-cache git jq su-exec npm && \
    rm -rf /var/cache/apk/*

RUN printf '<Location /server-status>\n\
    SetHandler server-status\n\
    Order deny,allow\n\
    Allow from all\n\
</Location>\n' \
>> /usr/local/apache2/conf/httpd.conf

# htdocs clean + chown
WORKDIR /usr/local/apache2/htdocs/
RUN rm -rf * .[!.]* ..?*

# Labels for registry
LABEL org.opencontainers.image.source="https://github.com/Sakujakira/5etools-docker" \
      org.opencontainers.image.description="5eTools Docker Container"

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

CMD ["/init.sh"]