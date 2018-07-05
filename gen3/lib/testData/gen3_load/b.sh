#
# For testing 'gen3_load' 
# - repeated calls to 'gen3 load gen3/lib/testData/gen3_load/b'
#     should only load this file once, so [[ "$GEN3_LOAD_B" == 1 ]]
#
export GEN3_LOAD_B
if [[ -z "$GEN3_LOAD_B" ]]; then
  let GEN3_LOAD_B=0
fi
let GEN3_LOAD_B="${GEN3_LOAD_B}+1"
