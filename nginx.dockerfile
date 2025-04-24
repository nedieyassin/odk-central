# Stage 1: Build frontend assets
FROM node:22.12.0-slim AS intermediate

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY ./ ./

# You might want to adjust files/prebuild/build-frontend.sh
# if it has any logic tied to the final Nginx environment/variables
ARG SKIP_FRONTEND_BUILD
RUN files/prebuild/build-frontend.sh

# Stage 2: Final Nginx image (configured for use behind an external proxy)
# Changed base image to a standard Nginx image
FROM nginx:alpine

EXPOSE 80
EXPOSE 443

# Removed Certbot/SSL-related volumes as Coolify's Traefik handles SSL persistence
# VOLUME [ "/etc/dh", "/etc/selfsign" ]

# Install netcat for the healthcheck defined in docker-compose.yml
RUN apk update && apk add --no-cache netcat-openbsd

# Create directory if needed by your Nginx config includes
RUN mkdir -p /usr/share/odk/nginx/

# Removed COPY and ENTRYPOINT for setup-odk.sh
# This script likely contained the Certbot/SSL setup logic, which is now external.
# You will need to ensure your Nginx configuration files (copied next) are
# suitable for running without this setup script handling SSL or templating.
# COPY files/nginx/setup-odk.sh /scripts/
# RUN chmod +x /scripts/setup-odk.sh

# Copy Nginx configuration include files
# These files are expected to be included by the main nginx.conf
# Standard Nginx images automatically include .conf files from /etc/nginx/conf.d/
COPY files/nginx/redirector.conf /etc/nginx/conf.d/redirector.conf
COPY files/nginx/common-headers.conf /etc/nginx/conf.d/common-headers.conf
# NOTE: If redirector.conf or common-headers.conf were TEMPLATES
# that were processed by setup-odk.sh using envsubst or similar,
# you might need a simple replacement script in the final stage's entrypoint
# or CMD to perform that templating before starting Nginx.

# Copy built frontend assets from the intermediate stage to the Nginx webroot
COPY --from=intermediate client/dist/ /usr/share/nginx/html/

# Create the version file in the final image
# Keeping /tmp location as it was in the original Dockerfile
RUN printf 'versions:\n%s (%s)\n%s client (%s)\n%s server (%s)\n' \
    "e4221ebeb41cd6ccb0cedad0461e5b603c207339" "v2024.3.2-1-ge4221eb" \
    "8b1de6512faa7a60c05764312caec01f5c138c42" "master" \
    "7574030f7ea8750f3837950001a5efcdeba45b92" "develop" \
    > /tmp/version.txt

# Rely on the default Nginx image ENTRYPOINT/CMD to start Nginx.
# The default CMD for nginx:alpine is 'nginx -g daemon off;' which runs Nginx
# in the foreground, suitable for Docker.