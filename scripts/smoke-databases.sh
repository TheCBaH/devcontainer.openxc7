#!/bin/sh
set -eu
export PATH=/opt/openxc7/bin:$PATH
for settings in /opt/openxc7/share/openxc7/databases/*.env; do
    sh /smoke-device.sh "$settings"
done
