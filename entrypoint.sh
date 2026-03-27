#!/bin/bash

mkdir -p /home/ubuntu/.ssh2
cp /home/ubuntu/.ssh/authorized_keys /home/ubuntu/.ssh2/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh2
chmod 700 /home/ubuntu/.ssh2
chmod 600 /home/ubuntu/.ssh2/authorized_keys

# Tell sshd to use the alternate path
echo "AuthorizedKeysFile /home/ubuntu/.ssh2/authorized_keys" >> /etc/ssh/sshd_config

/usr/sbin/sshd
exec su - ubuntu