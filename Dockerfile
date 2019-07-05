FROM python:3.6.8-alpine3.10 as build

RUN apk --update add git less openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

RUN mkdir /opt/cerbot \
    && git clone --branch v0.35.1 https://github.com/certbot/certbot.git /opt/certbot 


FROM python:3.6.8-alpine3.10 as final
LABEL version="0.1.0"
LABEL maintainer="genzers@gmail.com"

# NOTE #
#
# Most of there lines are copied from the official certbot Dockerfile.
# @see https://hub.docker.com/r/certbot/certbot/dockerfile
ENTRYPOINT [ "certbot" ]
EXPOSE 80 443
VOLUME /etc/letsencrypt /var/lib/letsencrypt
WORKDIR /opt/certbot
COPY --from=build /opt/certbot/CHANGELOG.md /opt/certbot/README.rst /opt/certbot/setup.py src/

# Generate constraints file to pin dependency versions
COPY --from=build /opt/certbot/letsencrypt-auto-source/pieces/dependency-requirements.txt .
COPY --from=build /opt/certbot/tools /opt/certbot/tools
RUN sh -c 'cat dependency-requirements.txt | /opt/certbot/tools/strip_hashes.py > unhashed_requirements.txt'
RUN sh -c 'cat tools/dev_constraints.txt unhashed_requirements.txt | /opt/certbot/tools/merge_requirements.py > docker_constraints.txt'

COPY --from=build /opt/certbot/acme src/acme
COPY --from=build /opt/certbot/certbot src/certbot

RUN apk add --no-cache --virtual .certbot-deps \
        libffi \
        libssl1.1 \
        openssl \
        ca-certificates \
        binutils \
        # NOTE #
        # 
        # These tools are added to support executing the
        # scripts on hooks.
        #
        # - bind-tools contains dig, host which is useful for
        # querying the DNS record if you are doing ACME Challenge.
        bash \
        curl \
        bind-tools

RUN apk add --no-cache --virtual .build-deps \
        gcc \
        linux-headers \
        openssl-dev \
        musl-dev \
        libffi-dev \
    && pip install -r /opt/certbot/dependency-requirements.txt \
    && pip install --no-cache-dir --no-deps \
        --editable /opt/certbot/src/acme \
        --editable /opt/certbot/src \
    && apk del .build-deps
    
