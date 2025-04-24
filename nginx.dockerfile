FROM node:22.12.0-slim AS intermediate

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY ./ ./
# RUN files/prebuild/write-version.sh

cat << 'EOF' > /tmp/version.txt
versions:
e4221ebeb41cd6ccb0cedad0461e5b603c207339 (v2024.3.2-1-ge4221eb)
8b1de6512faa7a60c05764312caec01f5c138c42 client (master)
7574030f7ea8750f3837950001a5efcdeba45b92 server (develop)
EOF

ARG SKIP_FRONTEND_BUILD
# RUN files/prebuild/build-frontend.sh



# when upgrading, look for upstream changes to redirector.conf
# also, confirm setup-odk.sh strips out HTTP-01 ACME challenge location
FROM jonasal/nginx-certbot:5.4.0

EXPOSE 80
EXPOSE 443

# Persist Diffie-Hellman parameters and/or selfsign key
VOLUME [ "/etc/dh", "/etc/selfsign" ]

RUN apt-get update && apt-get install -y netcat-openbsd

RUN mkdir -p /usr/share/odk/nginx/

COPY files/nginx/setup-odk.sh /scripts/
RUN chmod +x /scripts/setup-odk.sh

COPY files/nginx/redirector.conf /usr/share/odk/nginx/
COPY files/nginx/common-headers.conf /usr/share/odk/nginx/

COPY --from=intermediate client/dist/ /usr/share/nginx/html
COPY --from=intermediate /tmp/version.txt /usr/share/nginx/html

ENTRYPOINT [ "/scripts/setup-odk.sh" ]
