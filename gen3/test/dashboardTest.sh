
test_board_prefix() {
  local prefix
  prefix="$(gen3 dashboard prefix)" && [[ "$prefix" =~ ^s3://[^/]+/.+$ ]];
    because $? "the dashboard prefix looks ok: $prefix"
}

test_board_publish() {
  local tempFile
  local destPath="test/upload$(date +%s).txt"
  local finalPath
  finalPath="$(gen3 dashboard prefix)/Public/${destPath}";
    because $? "the dashboard prefix is configured"
  
  tempFile="$(mktemp "${XDG_RUNTIME_DIR}/board_publish_XXXXXX")"
  echo "frickjack" > "$tempFile"
  gen3 dashboard publish public "$tempFile" "$destPath"; 
    because $? "dashboard publish public should work - $destPath"
  aws s3 ls "${finalPath}"; because $? "dashboard publish public generates expected object at $finalPath"
  aws s3 rm "${finalPath}"

  finalPath="$(gen3 dashboard prefix)/Secure/${destPath}";
    because $? "the dashboard prefix is configured"

  gen3 dashboard publish secure "$tempFile" "$destPath"
  aws s3 ls "${finalPath}"; because $? "dashboard publish secure generates expected object at $finalPath"
  aws s3 rm "${finalPath}"
  rm "$tempFile"
}

shunit_runtest "test_board_prefix" "dashboard"
shunit_runtest "test_board_publish" "dashboard"
