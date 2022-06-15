#!/bin/bash

cron &
supervisord &

if [ ! -z "$BRIGHTPEARL_WEBHOOK_DOMAIN" ] && [ ! -z "$SSH_AUTH_SOCK" ] && [ -f /.ssh/id_rsa ]; then
    autossh -M 0 \
        -o StrictHostKeyChecking=no \
        -R $BRIGHTPEARL_WEBHOOK_DOMAIN:80:localhost:80 \
        -i /.ssh/id_rsa \
        plan@localhost.run &
fi

docker-php-entrypoint "$@"
