#!/bin/bash

README="$GEN3_HOME/doc/README.md"
detail="$1"
PAGER="${PAGER:-less}"

open() {
  local filePath="$1"
  echo "$filePath" | cat - "$filePath" | $PAGER
  
}
if [[ -z "$detail" ]]; then
  open "$README"
  exit $?
fi

# Try to find an exact match
filePath="$(find "$GEN3_HOME/doc" -name "${detail}.md" -print | head -1)"
if [[ -n "$filePath" ]]; then
  open "$filePath"
  exit $?
fi

# Try to help the user find what she wants
echo "Could not find ${detail}.md under $GEN3_HOME/doc"
echo --------------
echo grep "$README"
grep "$detail" "$README"
