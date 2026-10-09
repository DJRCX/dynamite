#!/bin/sh
# PAM check for the nested dev session only (see services/Lock.qml): accepts the password "dynamite".
password=$(head -c 512 | tr -d '\000\n')
[ "$password" = "dynamite" ]
