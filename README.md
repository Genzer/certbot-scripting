# `certbot-scripting` Docker Image

This Docker image is customized from the official [`certbot` Docker](https://hub.docker.com/r/certbot/certbot) to provide a scripting capability in order to automate renew Let's Encrypt TLS certificates.

## Changelog

### v0.1.0 - 5.7.2019

- The base image is Python 3.6 Alpine 3.10.
- The following packages are installed to support scripting (hooks) on Manual mode: `bash`, `curl` and `bind-tools` (i.e`dig` for DNS query).

## Usage

I built this Docker image to support my use case: use `certbot` Manual mode to renew our TLS certificates.

> See [Pre and Post Validation Hooks](https://certbot.eff.org/docs/using.html#pre-and-post-validation-hooks) for details.

This is an example of how I used this image:

Suppose I have created a Compose stack:

```bash
my-letsencrypt/
├── docker-compose.yaml
├── letsencrypt
└── scripts
    ├── post_acme_challenge.sh
    ├── pre_acme_challenge.sh
    └── renew-letsencrypt.sh
```

1. Create a Docker Compose file

```yaml
version: 3.0

services:
    certbot-renew:
        image: genzerhawker/certbot-scripting:latest
        # Override the default entrypoint `certbot`
        entrypoint: bash
        command: script/renew-letsencrypt.sh
        volumes:
            # This should be the directory containing
            # your Let's Encrypt certs.
            # Normally, they are located at /etc/letsencrypt.
            - ./letsencrypt:/etc/letsencrypt
            - ./logs:/var/log/letsencrypt
            - .scripts:/opt/certbot/scripts
        env_file:
            # This dotenv file should contains Environment Variables
            # for accessing your DNS provider API (if any).
            - your_dns_provider_credentials.env
```

2. Create Your Script Hook

```bash
#!/usr/bin/env bash

# NOTE #
#
# renew-lestencrypt.sh

set -e

echo "Renew Let's Encrypt certificate using certbot"

echo -e "[debug] - Renew domain *.example.com"
echo -e "▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"

certbot certonly -a manual \
    --non-interactive \
    --preferred-challenge=dns-01 \
    --manual-public-ip-logging-ok  \
    --manual-auth-hook "$(pwd)/scripts/pre_acme_challenge.sh" \
    --manual-cleanup-hook "$(pwd)/scripts/post_acme_challenge.sh" \
    -d "*.example.com" \
    --server "https://acme-v02.api.letsencrypt.org/directory"
```

The `pre_acme_challenge.sh` and `post_acme_challenge.sh` are the two Bash scripts which you should implement to call your Domain Provider (e.g GoDaddy) to add the `_acme-challenge` TXT record.

3. Execute

```bash
docker-compose run --rm certbot-renew
```

