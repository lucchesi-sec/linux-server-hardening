#!/bin/bash

# Linux Server Hardening Check Script (Enhanced with explanations)

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"
CYAN="\e[36m" # For Importance/Fix labels

PASS_COUNT=0
TOTAL_CHECKS=28 # SSH(5), UFW(3), F2B(2), UU(1), PWPolicy(2), Auditd(4), Banner(1), Sysctl(10)

print_result() {
  local status_code=$1
  local description="$2"
  local importance_text="$3" 
  local fix_text="$4"        

  if [ "$status_code" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS:${RESET} $description"
    ((PASS_COUNT++))
  else
    echo -e "${RED}❌ FAIL:${RESET} $description"
    if [[ -n "$importance_text" && -n "$fix_text" ]]; then
      echo -e "    ${CYAN}IMPORTANCE:${RESET} ${importance_text}"
      echo -e "    ${CYAN}SUGGESTION:${RESET} ${fix_text}"
    fi
  fi
}

echo -e "\n============================"
echo -e " Linux Server Hardening Check "
echo -e "============================\n"

# --- 1. Check SSH configuration ---
echo "[SSH CONFIG]"
DESC_SSH_PASS_AUTH="PasswordAuthentication is disabled"
IMPORTANCE_SSH_PASS_AUTH="Disabling password authentication and relying on SSH keys is a critical security measure. It protects against brute-force password attacks and credential stuffing."
FIX_SSH_PASS_AUTH="Ensure 'PasswordAuthentication no' is uncommented and correctly set in /etc/ssh/sshd_config. Run 'ssh-config/apply-ssh-config.sh' or manually edit the file and restart sshd."
if grep -qi "^\s*PasswordAuthentication\s\+no" /etc/ssh/sshd_config; then
  print_result 0 "$DESC_SSH_PASS_AUTH"
else
  print_result 1 "$DESC_SSH_PASS_AUTH" "$IMPORTANCE_SSH_PASS_AUTH" "$FIX_SSH_PASS_AUTH"
fi

DESC_SSH_ROOT_LOGIN="PermitRootLogin is disabled"
IMPORTANCE_SSH_ROOT_LOGIN="Disabling direct root login via SSH reduces the attack surface. Administrative tasks should be done by logging in as a non-privileged user and then using 'sudo'."
FIX_SSH_ROOT_LOGIN="Ensure 'PermitRootLogin no' is uncommented and correctly set in /etc/ssh/sshd_config. Run 'ssh-config/apply-ssh-config.sh' or manually edit and restart sshd."
if grep -qi "^\s*PermitRootLogin\s\+no" /etc/ssh/sshd_config; then
  print_result 0 "$DESC_SSH_ROOT_LOGIN"
else
  print_result 1 "$DESC_SSH_ROOT_LOGIN" "$IMPORTANCE_SSH_ROOT_LOGIN" "$FIX_SSH_ROOT_LOGIN"
fi

DESC_SSH_MAX_AUTH="MaxAuthTries is set to a low value (e.g., <= 3)"
IMPORTANCE_SSH_MAX_AUTH="Limiting maximum authentication attempts per connection helps mitigate brute-force attacks by quickly disconnecting malicious clients."
FIX_SSH_MAX_AUTH="Set 'MaxAuthTries 3' (or a low number like 2-4) in /etc/ssh/sshd_config. Run 'ssh-config/apply-ssh-config.sh' or manually edit and restart sshd."
MAX_AUTH_TRIES=$(grep -i "^\s*MaxAuthTries" /etc/ssh/sshd_config | awk '{print $2}')
if [[ -n "$MAX_AUTH_TRIES" && "$MAX_AUTH_TRIES" -le 3 ]]; then
  print_result 0 "$DESC_SSH_MAX_AUTH (Current: $MAX_AUTH_TRIES)"
else
  print_result 1 "$DESC_SSH_MAX_AUTH (Current: '$MAX_AUTH_TRIES')" "$IMPORTANCE_SSH_MAX_AUTH" "$FIX_SSH_MAX_AUTH"
fi

DESC_SSH_LOGIN_GRACE="LoginGraceTime is set to a short duration (e.g., <= 60)"
IMPORTANCE_SSH_LOGIN_GRACE="Setting a short login grace time limits how long an attacker has to attempt authentication on an open, unauthenticated connection."
FIX_SSH_LOGIN_GRACE="Set 'LoginGraceTime 60' (or lower, e.g., 30) in /etc/ssh/sshd_config. Run 'ssh-config/apply-ssh-config.sh' or manually edit and restart sshd."
LOGIN_GRACE_TIME=$(grep -i "^\s*LoginGraceTime" /etc/ssh/sshd_config | awk '{print $2}')
if [[ -n "$LOGIN_GRACE_TIME" && "$LOGIN_GRACE_TIME" -le 60 ]]; then
  print_result 0 "$DESC_SSH_LOGIN_GRACE (Current: $LOGIN_GRACE_TIME)"
else
  print_result 1 "$DESC_SSH_LOGIN_GRACE (Current: '$LOGIN_GRACE_TIME')" "$IMPORTANCE_SSH_LOGIN_GRACE" "$FIX_SSH_LOGIN_GRACE"
fi

DESC_SSH_BANNER="SSH Banner is set to /etc/issue.net"
IMPORTANCE_SSH_BANNER="Displaying a legal warning banner before login can deter unauthorized access and fulfill legal/compliance requirements."
FIX_SSH_BANNER="Ensure 'Banner /etc/issue.net' is uncommented and set in /etc/ssh/sshd_config. Ensure /etc/issue.net contains the banner. Run 'ssh-config/apply-ssh-config.sh' and 'banner/apply-banner.sh'."
if grep -qi "^\s*Banner\s\+/etc/issue.net" /etc/ssh/sshd_config; then
  print_result 0 "$DESC_SSH_BANNER"
else
  print_result 1 "$DESC_SSH_BANNER" "$IMPORTANCE_SSH_BANNER" "$FIX_SSH_BANNER"
fi

# --- 2. Check UFW firewall status ---
echo -e "\n[FIREWALL STATUS]"
UFW_STATUS_VERBOSE=$(sudo ufw status verbose 2>/dev/null) # Added 2>/dev/null to suppress "command not found" if ufw isn't installed

DESC_UFW_ACTIVE="UFW firewall is active"
IMPORTANCE_UFW_ACTIVE="A host-based firewall is fundamental for controlling network traffic and protecting against unauthorized connections."
FIX_UFW_ACTIVE="Ensure UFW is enabled using 'sudo ufw enable'. The 'src/modules/install-packages.sh' script should handle this."
if echo "$UFW_STATUS_VERBOSE" | grep -q "Status: active"; then
  print_result 0 "$DESC_UFW_ACTIVE"
else
  print_result 1 "$DESC_UFW_ACTIVE" "$IMPORTANCE_UFW_ACTIVE" "$FIX_UFW_ACTIVE"
fi

DESC_UFW_POLICY="UFW default policy is deny incoming, allow outgoing"
IMPORTANCE_UFW_POLICY="A default deny policy for incoming traffic (least privilege) is a security best practice. Allowing outgoing is common for usability."
FIX_UFW_POLICY="Set defaults: 'sudo ufw default deny incoming' and 'sudo ufw default allow outgoing'. 'src/modules/install-packages.sh' should handle this."
if echo "$UFW_STATUS_VERBOSE" | grep -q "Default: deny (incoming), allow (outgoing)"; then # Simplified check, 'disabled (routed)' can vary
  print_result 0 "$DESC_UFW_POLICY"
else
  print_result 1 "$DESC_UFW_POLICY" "$IMPORTANCE_UFW_POLICY" "$FIX_UFW_POLICY"
fi

DESC_UFW_SSH_RULE="UFW rule allows SSH"
IMPORTANCE_UFW_SSH_RULE="If SSH is used for remote administration, the firewall must explicitly allow incoming SSH connections to prevent lockout."
FIX_UFW_SSH_RULE="Add a rule like 'sudo ufw allow OpenSSH' or 'sudo ufw allow 22/tcp'. 'src/modules/install-packages.sh' should handle this. Check 'sudo ufw status verbose'."
if echo "$UFW_STATUS_VERBOSE" | grep -qE "(22\/tcp|OpenSSH|ssh)\s+(ALLOW IN|ALLOW)\s+"; then
    print_result 0 "$DESC_UFW_SSH_RULE"
else
    print_result 1 "$DESC_UFW_SSH_RULE" "$IMPORTANCE_UFW_SSH_RULE" "$FIX_UFW_SSH_RULE"
fi

# --- 3. Check Fail2Ban status and config ---
echo -e "\n[FAIL2BAN STATUS]"
DESC_F2B_ACTIVE="Fail2Ban service is running"
IMPORTANCE_F2B_ACTIVE="Fail2ban scans logs and bans IPs showing malicious signs (e.g., brute-force attempts), preventing intrusions."
FIX_F2B_ACTIVE="Ensure Fail2ban is active: 'sudo systemctl start fail2ban && sudo systemctl enable fail2ban'."
if systemctl is-active fail2ban | grep -q "active"; then
  print_result 0 "$DESC_F2B_ACTIVE"
else
  print_result 1 "$DESC_F2B_ACTIVE" "$IMPORTANCE_F2B_ACTIVE" "$FIX_F2B_ACTIVE"
fi

DESC_F2B_SSHD_JAIL="Fail2Ban sshd jail is enabled"
IMPORTANCE_F2B_SSHD_JAIL="The 'sshd' jail in Fail2ban specifically protects your SSH server from brute-force login attempts."
FIX_F2B_SSHD_JAIL="Ensure 'enabled = true' under '[sshd]' in /etc/fail2ban/jail.local. Run 'fail2ban/apply-fail2ban-config.sh' or manually configure and restart Fail2ban."
JAIL_LOCAL="/etc/fail2ban/jail.local"
JAIL_CONF="/etc/fail2ban/jail.conf"
SSHD_ENABLED_STATUS=1 
if [ -f "$JAIL_LOCAL" ]; then
    if sudo grep -qE "^\s*\[sshd\]" "$JAIL_LOCAL" && \
       sudo awk '/^\[sshd\]/{f=1} f && /^\s*enabled\s*=\s*true/{print; f=0}' "$JAIL_LOCAL" | grep -q "enabled"; then # Check for uncommented enabled = true
        SSHD_ENABLED_STATUS=0
    fi
fi
if [ "$SSHD_ENABLED_STATUS" -ne 0 ] && [ -f "$JAIL_CONF" ]; then # If not in jail.local, check jail.conf
     if sudo grep -qE "^\s*\[sshd\]" "$JAIL_CONF" && \
        sudo awk '/^\[sshd\]/{f=1} f && /^\s*enabled\s*=\s*true/{print; f=0}' "$JAIL_CONF" | grep -q "enabled"; then
         # Check jail.local doesn't explicitly disable it if jail.conf enables it
         DISABLE_CHECK=$(sudo awk '/^\[sshd\]/{f=1} f && /^\s*enabled\s*=\s*false/{print; f=0}' "$JAIL_LOCAL" 2>/dev/null)
         if [[ -z "$DISABLE_CHECK" ]]; then
              SSHD_ENABLED_STATUS=0
         fi
    fi
fi
if [ "$SSHD_ENABLED_STATUS" -eq 0 ]; then
    print_result 0 "$DESC_F2B_SSHD_JAIL"
else
    print_result 1 "$DESC_F2B_SSHD_JAIL" "$IMPORTANCE_F2B_SSHD_JAIL" "$FIX_F2B_SSHD_JAIL"
fi

# --- 4. Check for unattended-upgrades ---
echo -e "\n[AUTOMATIC UPDATES]"
DESC_UNATTENDED="Unattended security upgrades (with auto-reboot) are enabled"
IMPORTANCE_UNATTENDED="Automatic security updates protect against known vulnerabilities. Auto-reboot ensures kernel updates are applied but consider service impact."
FIX_UNATTENDED="Install 'unattended-upgrades'. Ensure 'Unattended-Upgrade::Automatic-Reboot \"true\";' is set in a configuration file under /etc/apt/apt.conf.d/ (e.g., by 'src/modules/install-packages.sh')."
# This specific check is for Automatic-Reboot "true". A more general check might be for APT::Periodic::Unattended-Upgrade "1";
# Check all files in /etc/apt/apt.conf.d/ for the setting.
if grep -qrh "^\s*Unattended-Upgrade::Automatic-Reboot\s*\"true\";" /etc/apt/apt.conf.d/ 2>/dev/null; then
  print_result 0 "$DESC_UNATTENDED"
else
  print_result 1 "$DESC_UNATTENDED" "$IMPORTANCE_UNATTENDED" "$FIX_UNATTENDED"
fi

# --- 5. Check password aging policy (system-wide) ---
echo -e "\n[PASSWORD POLICY]"
get_login_def_value() {
    grep -E "^\s*$1\s+" /etc/login.defs | sed -e 's/#.*//' -e 's/\r$//' | awk '{print $2}' | head -n 1
}
PASS_MAX_DAYS=$(get_login_def_value "PASS_MAX_DAYS")
PASS_MIN_DAYS=$(get_login_def_value "PASS_MIN_DAYS")
PASS_WARN_AGE=$(get_login_def_value "PASS_WARN_AGE")
PASS_MAX_DAYS=${PASS_MAX_DAYS:-0}; PASS_MIN_DAYS=${PASS_MIN_DAYS:-0}; PASS_WARN_AGE=${PASS_WARN_AGE:-0}

DESC_PW_AGING="Password aging policy (/etc/login.defs) correctly set (MAX_DAYS=90, MIN_DAYS=7, WARN_AGE=14)"
IMPORTANCE_PW_AGING="Enforcing password aging encourages regular password changes, reducing risk from compromised credentials."
FIX_PW_AGING="Ensure PASS_MAX_DAYS=90, PASS_MIN_DAYS=7, PASS_WARN_AGE=14 in /etc/login.defs. Run 'password-policy/apply-pam-pwquality.sh'."
CURRENT_PW_AGING_TEXT="MAX_DAYS=$PASS_MAX_DAYS MIN_DAYS=$PASS_MIN_DAYS WARN_AGE=$PASS_WARN_AGE"
if [[ "$PASS_MAX_DAYS" -eq 90 && "$PASS_MIN_DAYS" -eq 7 && "$PASS_WARN_AGE" -eq 14 ]]; then
  print_result 0 "$DESC_PW_AGING ($CURRENT_PW_AGING_TEXT)"
else
  print_result 1 "$DESC_PW_AGING (Current: $CURRENT_PW_AGING_TEXT)" "$IMPORTANCE_PW_AGING" "$FIX_PW_AGING"
fi

DESC_PW_COMPLEXITY="Password complexity (pam_pwquality.so) correctly configured"
IMPORTANCE_PW_COMPLEXITY="Strong password complexity rules (length, character types, etc.) make passwords harder to guess or crack."
FIX_PW_COMPLEXITY="Ensure pam_pwquality.so is configured in /etc/pam.d/common-password with options like 'retry=3 minlen=14 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1'. Run 'password-policy/apply-pam-pwquality.sh'."
COMMON_PASSWORD_FILE="/etc/pam.d/common-password"
EXPECTED_PWQUALITY_REGEX="^password\s+requisite\s+pam_pwquality\.so\s+retry=3\s+minlen=14\s+difok=3\s+ucredit=-1\s+lcredit=-1\s+dcredit=-1\s+ocredit=-1"
if grep -qE "$EXPECTED_PWQUALITY_REGEX" "$COMMON_PASSWORD_FILE"; then
    print_result 0 "$DESC_PW_COMPLEXITY"
else
    print_result 1 "$DESC_PW_COMPLEXITY" "$IMPORTANCE_PW_COMPLEXITY" "$FIX_PW_COMPLEXITY"
fi

# --- 6. Check auditd status and rules ---
echo -e "\n[AUDIT LOGGING]"
DESC_AUDITD_ACTIVE="auditd service is running"
IMPORTANCE_AUDITD_ACTIVE="The audit daemon (auditd) logs security-relevant system events, crucial for monitoring, forensics, and compliance."
FIX_AUDITD_ACTIVE="Ensure auditd is active: 'sudo systemctl start auditd && sudo systemctl enable auditd'."
if systemctl is-active auditd | grep -q "active"; then
  print_result 0 "$DESC_AUDITD_ACTIVE"
else
  print_result 1 "$DESC_AUDITD_ACTIVE" "$IMPORTANCE_AUDITD_ACTIVE" "$FIX_AUDITD_ACTIVE"
fi

AUDIT_RULES_LOADED=$(sudo auditctl -l 2>/dev/null)
DESC_AUDITD_IMMUTABLE="Auditd rules immutable flag (-e 2) is set"
IMPORTANCE_AUDITD_IMMUTABLE="Setting audit rules immutable (-e 2) prevents tampering until the next reboot, protecting audit integrity."
FIX_AUDITD_IMMUTABLE="Ensure your audit rules file (e.g., /etc/audit/rules.d/99-hardening-rules.rules) ends with '-e 2' and that 'augenrules --load' or 'systemctl restart auditd' loads them. Run 'auditd-rules/apply-auditd-rules.sh'."
if echo "$AUDIT_RULES_LOADED" | grep -q -- "-e 2"; then # Check for -e 2 in loaded rules, not auditctl -s
  print_result 0 "$DESC_AUDITD_IMMUTABLE"
else
  # Check auditctl -s as a fallback, though -l should show it if rules are from a file with -e 2
  if sudo auditctl -s 2>/dev/null | grep -q "enabled 2"; then
      print_result 0 "$DESC_AUDITD_IMMUTABLE (verified via auditctl -s)"
  else
      print_result 1 "$DESC_AUDITD_IMMUTABLE" "$IMPORTANCE_AUDITD_IMMUTABLE" "$FIX_AUDITD_IMMUTABLE"
  fi
fi

DESC_AUDITD_KEY_IDENTITY="Auditd rules include key 'identity' for user/group file monitoring"
IMPORTANCE_AUDITD_KEY_IDENTITY="Monitors changes to critical user/group identity files (e.g., /etc/passwd, /etc/shadow)."
FIX_AUDITD_KEY_IDENTITY="Ensure audit rules include lines like '-w /etc/passwd -p wa -k identity'. Part of 'auditd-rules/apply-auditd-rules.sh'."
if echo "$AUDIT_RULES_LOADED" | grep -q -- "-k identity"; then
   print_result 0 "$DESC_AUDITD_KEY_IDENTITY"
else
   print_result 1 "$DESC_AUDITD_KEY_IDENTITY" "$IMPORTANCE_AUDITD_KEY_IDENTITY" "$FIX_AUDITD_KEY_IDENTITY"
fi

DESC_AUDITD_KEY_SSHD="Auditd rules include key 'sshd' for SSH config monitoring"
IMPORTANCE_AUDITD_KEY_SSHD="Monitors changes to the SSH server configuration file (/etc/ssh/sshd_config)."
FIX_AUDITD_KEY_SSHD="Ensure audit rules include a line like '-w /etc/ssh/sshd_config -p wa -k sshd'. Part of 'auditd-rules/apply-auditd-rules.sh'."
if echo "$AUDIT_RULES_LOADED" | grep -q -- "-k sshd"; then
   print_result 0 "$DESC_AUDITD_KEY_SSHD"
else
   print_result 1 "$DESC_AUDITD_KEY_SSHD" "$IMPORTANCE_AUDITD_KEY_SSHD" "$FIX_AUDITD_KEY_SSHD"
fi

# --- 7. Check warning banner ---
echo -e "\n[WARNING BANNER]"
DESC_BANNER_TEXT="Login banner (/etc/issue.net) contains warning text"
IMPORTANCE_BANNER_TEXT="The pre-login banner in /etc/issue.net serves as a legal warning to anyone attempting system access."
FIX_BANNER_TEXT="Ensure /etc/issue.net contains the appropriate warning text. 'banner/apply-banner.sh' handles this."
BANNER_TEXT_EXPECTED="WARNING - Authorized Access Only" # Match text from apply-banner.sh
if grep -q "$BANNER_TEXT_EXPECTED" /etc/issue.net 2>/dev/null; then
  print_result 0 "$DESC_BANNER_TEXT"
else
  print_result 1 "$DESC_BANNER_TEXT" "$IMPORTANCE_BANNER_TEXT" "$FIX_BANNER_TEXT"
fi

# --- 8. Check Kernel Parameters (sysctl) ---
echo -e "\n[KERNEL PARAMETERS (SYSCTL)]"
check_sysctl() {
    local param="$1"
    local expected_value="$2"
    local current_value
    local desc_text="Sysctl: $param is set to $expected_value"
    local importance_text_general="Kernel parameters control system behavior (networking, memory, etc.). Security-focused settings harden the kernel."
    # Specific importance can be added per parameter if desired, for now using general.
    local fix_text_general="Ensure '$param = $expected_value' is in a file under /etc/sysctl.d/ (e.g., 99-hardening.conf) and 'sudo sysctl --system' has run. 'sysctl/apply-sysctl-config.sh' handles this."

    if ! current_value=$(sysctl -n "$param" 2>/dev/null); then
        print_result 1 "$param: Parameter not found or error reading" "$importance_text_general (Parameter $param not found)" "$fix_text_general (Ensure $param is a valid kernel parameter for your system.)"
        return
    fi

    if [[ "$current_value" == "$expected_value" ]]; then
        print_result 0 "$desc_text"
    else
        print_result 1 "$desc_text (Current: '$current_value')" "$importance_text_general (Specifically, $param being $expected_value is important for X reason - to be detailed per param if needed)" "$fix_text_general"
    fi
}

check_sysctl "net.ipv4.conf.all.rp_filter" 1
check_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" 1
check_sysctl "net.ipv4.conf.all.accept_source_route" 0
check_sysctl "net.ipv4.conf.all.accept_redirects" 0
check_sysctl "net.ipv4.conf.all.secure_redirects" 0
check_sysctl "net.ipv4.tcp_syncookies" 1
check_sysctl "net.ipv4.conf.all.log_martians" 1
check_sysctl "kernel.randomize_va_space" 2
check_sysctl "fs.protected_hardlinks" 1 
check_sysctl "kernel.dmesg_restrict" 1

# --- Summary ---
echo -e "\n============================"
echo -e " Hardening Score: ${YELLOW}$PASS_COUNT / $TOTAL_CHECKS${RESET}"
if [ "$PASS_COUNT" -eq "$TOTAL_CHECKS" ]; then
  echo -e "${GREEN}✅ All checks passed. System is hardened.${RESET}"
else
  echo -e "${YELLOW}⚠️  Some hardening checks failed. Review recommended.${RESET}"
fi
echo -e "============================"
