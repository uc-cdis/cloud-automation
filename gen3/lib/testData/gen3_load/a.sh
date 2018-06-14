#
# For testing 'gen3_load' 
# - repeated calls to 'gen3 load gen3/lib/testData/gen3_load/a'
#     should only load this file once, so [[ "$GEN3_LOAD_A" == 1 ]]
#
export GEN3_LOAD_A
if [[ -z "$GEN3_LOAD_A" ]]; then
  let GEN3_LOAD_A=0
fi
let GEN3_LOAD_A="${GEN3_LOAD_A}+1"
