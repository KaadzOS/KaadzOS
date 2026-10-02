if [ "$(tty)" = "/dev/tty1" ]; then
  export XDG_SESSION_TYPE=wayland
  exec sway
fi
