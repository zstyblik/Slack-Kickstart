#!/bin/sh
# SSH post-inst
printf "Post-install ~ '/etc/ssh/sshd_config'.\n"
sed -r -e '/^[#]?PasswordAuthentication/c \PasswordAuthentication no' \
	-e '/^[#]?Protocol/c \Protocol 2' /etc/ssh/sshd_config \
	-e '/^[#]?PubkeyAuthentication/c \PubkeyAuthentication yes' \
	> /etc/ssh/sshd_config.new
mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
