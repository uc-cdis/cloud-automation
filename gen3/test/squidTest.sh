#
# Verify squid whitelist and wildcard do not overlap
#

test_squid_rules() {
  local whiteFile="$GEN3_HOME/files/squid_whitelist/web_whitelist"
  local wildFile="$GEN3_HOME/files/squid_whitelist/web_wildcard_whitelist"
  [[ -f "$whiteFile" ]]; because $? "whitelist file exists: $whiteFile"
  [[ -f "$wildFile" ]]; because $? "wildcard file exists: $wildFile"

  local rule
  for rule in $(cat "$wildFile"); do
    ! grep "${rule#.}" "$whiteFile"; because $? "whitelist does not duplicate wildcard rule: $rule"
  done
}

shunit_runtest "test_squid_rules" "local,squid"
