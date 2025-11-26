#!/bin/sh

# If SERVER_NAME is set, process the SSL template
if [ -n "$SERVER_NAME" ]; then
    echo "Processing SSL template for SERVER_NAME=$SERVER_NAME"
    envsubst '${SERVER_NAME}' < /etc/nginx/templates/default.ssl.conf.template > /etc/nginx/conf.d/default.conf
fi

# Execute the CMD
exec "$@"
