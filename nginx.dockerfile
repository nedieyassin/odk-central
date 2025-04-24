# Stage 1: Build frontend assets
FROM node:22.12.0-slim AS intermediate
# ... (rest of intermediate stage remains the same)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*
COPY ./ ./
ARG SKIP_FRONTEND_BUILD
RUN files/prebuild/build-frontend.sh

# Stage 2: Final Nginx image (configured for use behind an external proxy with templating)
FROM nginx:alpine

EXPOSE 80 # Traefik will forward to this internal port

# Install netcat for the healthcheck
RUN apk update && apk add --no-cache netcat-openbsd

# Create directory if needed by your Nginx config includes (optional if using templates dir)
# RUN mkdir -p /usr/share/odk/nginx/ # This might not be needed anymore

# Removed COPY and ENTRYPOINT for setup-odk.sh

# Copy Nginx configuration TEMPLATE files
# Copy to /etc/nginx/templates and add .template extension
# Ensure environment variable DOMAIN is passed to the container (e.g., in docker-compose.yml)
COPY files/nginx/redirector.conf /etc/nginx/templates/redirector.conf.template
COPY files/nginx/common-headers.conf /etc/nginx/templates/common-headers.conf.template
# Note: If you have other Nginx config files, copy them here too if they need templating.

# Copy built frontend assets from the intermediate stage to the Nginx webroot
COPY --from=intermediate client/dist/ /usr/share/nginx/html/

# Create the version file in the final image
RUN printf 'versions:\n%s (%s)\n%s client (%s)\n%s server (%s)\n' \
    "e4221ebeb41cd6ccb0cedad0461e5b603c207339" "v2024.3.2-1-ge4221eb" \
    "8b1de6512faa7a60c05764312caec01f5c138c42" "master" \
    "7574030f7ea8750f3837950001a5efcdeba45b92" "develop" \
    > /tmp/version.txt

# Rely on the default Nginx image ENTRYPOINT/CMD.
# The default entrypoint script handles envsubst for files in /etc/nginx/templates/
# and then runs 'nginx -g daemon off;'.
# Make sure DOMAIN is set as an environment variable for the nginx service in your docker-compose.yml