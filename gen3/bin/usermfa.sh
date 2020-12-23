#!/bin/bash

# lib ----------------------

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

usermfaHelp() {
  gen3 help usermfa
}

usermfaQr() {
  if [[ $# -lt 2 ]]; then
    echo "ERROR: qr requires 2 arguments" 1>&2
    usermfaHelp
    return 1
  fi
  local label
  local secret
  label="$1"
  shift
  secret="$1"
  shift
  qrencode -o - -d 300 -s 10 "otpauth://totp/${label}?secret=${secret}"
}


usermfaAddUser() {
  if [[ $# -lt 2 || ! -d "$1" ]]; then
    echo "ERROR: invalid user folder $1" 1>&2
    return 1
  fi
  local userFolder="$1"
  shift
  local label="$1"
  shift

  if [[ ! -f "$userFolder/info.json" ]]; then
    echo "ERROR: missing $userFolder/info.json" 1>&2
    return 1
  fi

  local userName
  if ! userName="$(jq -e -r .uname < "$userFolder/info.json")" || [[ -z "$userName" ]]; then
    echo "ERROR: failed to derive uname from $userFolder/info.json" 1>&2
    return 1
  fi
  if [[ -d "/home/$userName" ]]; then
    echo "ERROR: user already exists: $userName" 1>&2
    return 1
  fi
  if ! sudo -n true > /dev/null 2>&1; then
    echo "ERROR: user must have sudo privileges" 1>&2
    return 1
  fi
  if ! which google-authenticator > /dev/null 2>&1; then
    echo "ERROR: install google-authentiator: sudo apt install libpam-google-authenticator" 1>&2
    return 1
  fi

  echo -e "INFO: creating new user $userName" 1>&2
  if ! sudo useradd -m -s /bin/bash "$userName" || [[ ! -d "/home/$userName" ]]; then
    echo "ERROR: failed to create new user $userName" 1>&2
    return 1
  fi

  echo -e "INFO: setting up mfa with google-authenticator" 1>&2
  sudo su -l -c "google-authenticator --time-based --disallow-reuse --rate-limit 3 --rate-time 30 --minimal-window --issuer=gen3 --label='${userName}@$label' --qr-mode=NONE --force" "$userName"
  local mfaCode
  if ! mfaCode="$(sudo head -1 "/home/$userName/.google_authenticator")"; then
    echo "ERROR: failed to lookup google-authenticator code" 1>&2
    return 1
  fi
  if [[ -f "$userFolder/authorized_keys" ]]; then
    echo -e "INFO: copying ssh authorized_keys" 1>&2
    sudo su -l -c "mkdir '/home/${userName}/.ssh'; touch '/home/${userName}/.ssh/authorized_keys'" "$userName"
    sudo cp "$userFolder/authorized_keys" "/home/${userName}/.ssh/authorized_keys"
  fi
  sudo chmod -R go-rwX "/home/${userName}"
  local googChart="https://www.google.com/chart?chs=200x200&chld=M|0&cht=qr&chl=otpauth://totp/${userName}@${label}%3Fsecret%3D${mfaCode}%26issuer%3Dgen3"
  local newInfo
  if ! newInfo="$(jq -e -r --arg googChart "$googChart" '.mfaChart=$googChart' < "$userFolder/info.json")"; then
    echo -e "ERROR: failed to update $userFolder/info.json" 1>&2
    return 1
  fi
  cat - <<< "$newInfo" | tee "$userFolder/info.json"
  #usermfaQr "${userName}@3.228.134.250" "${mfaCode}" > "${userFolder}/mfaQr.png"
}


# helper for usermfaTests
because() {
  local code="$1"
  shift
  local message="$1"
  shift
  if [[ "$code" == 0 ]]; then
    echo "OK - $message" 1>&2
  else
    echo "FAILED - $code - $message"
    exit 1
  fi
}

# test suite
usermfaTests() {
  echo "Running testsuite"
  local qrTemp="$(mktemp "/tmp/qrTest.png_XXXXXX")"
  local resultCode
  echo "testing usermfa qr"
  usermfaQr "reuben" "secret sauce" > "$qrTemp"; because $? "usermfaQr should succeed"
  local ftype
  ftype="$(file -b "$qrTemp" | awk '{ print $1 }')" \
    && [[ "$ftype" == "PNG" ]]; 
    because $? "usermfaQr generates an mfa qr png: $qrTemp - $ftype";
  rm "$qrTemp"
  echo "usermfa qr - OK"
  echo "----------------------------"

  echo -e "\ntesting usermfa add"
  [[ ! -d "/home/frickjack" ]]; because $? "frickjack user does not already exist"
  local userFolder
  userFolder="$(mktemp -d -p "${XDG_RUNTIME_DIR}" "usermfaAdd_XXXXXX")"
  jq -r -n '.name="frick jack" | .uname="frickjack"' | tee "$userFolder/info.json"
  echo "bla bla bla bla" > "$userFolder/authorized_keys"
  usermfaAddUser "$userFolder" "3.228.134.250"; because $? "usermfa add succeeds"
  sleep 1
  [[ -d /home/frickjack ]]; because $? "frickjack user created"
  sudo test -f "/home/frickjack/.ssh/authorized_keys"; because $? "frickjack authorized keys in place"
  sudo test -f "/home/frickjack/.google_authenticator"; because $? "frickjack google_authenticator in place"
  [[ "$(jq -r .mfaChart < "$userFolder/info.json")" =~ ^https://www.google.com ]]; because $? "usermfa add updates user info $(cat "$userFolder/info.json")"
  sudo userdel -r frickjack
  /bin/rm -rf "$userFolder"
  echo "usermfa add - OK"
  echo "----------------------------"
}

# main --------  

if [[ $# -lt 1 ]]; then
  usermfaHelp
  exit 0
fi

command="$1"
shift
case "$command" in
  "add")
    usermfaAddUser "$@"
    ;;
  "qr")
    usermfaQr "$@"
    ;;
  "testsuite")
    usermfaTests "$@"
    ;;
  "*")
    usermfaHelp "$@"
    ;;
esac
