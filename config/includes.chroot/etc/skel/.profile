export PATH="/usr/local/bin:/usr/bin:/bin"

if [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
  exec kaadzos-sway-session
fi
