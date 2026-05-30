{ pkgs, ... }: {
  # ── systemd config compliance check (runs on every rebuild) ──
  system.activationScripts.checkSystemdErrors = {
    supportsDryActivation = true;
    text = ''
      echo "========= 🛠️ System Config Compliance Check ========="
      errors=$(${pkgs.systemd}/bin/journalctl -b 0 --since "10 minutes ago" | grep -E -i "ignoring line|failed to parse|timed out" || true)
      if [ -n "$errors" ]; then
        echo -e "\e[31m⚠️ WARNING: systemd config issues or timeouts detected!\e[0m"
        echo "$errors"
      else
        echo -e "\e[32m✓ Check complete. No obvious systemd config syntax errors found.\e[0m"
      fi
      echo "========================================="
    '';
  };
}
