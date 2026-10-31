export PATH="/usr/local/bin:/usr/bin:/bin"

# Materialise the standard user directories once (Downloads, Pictures,
# Videos...) so the helpers always find real dirs.
xdg-user-dirs-update >/dev/null 2>&1 || true

if [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
  exec kaadzos-sway-session
fi
