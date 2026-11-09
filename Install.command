#!/bin/zsh
set -e
cd "${0:A:h}"
/usr/bin/python3 build.py
/usr/bin/python3 install.py
