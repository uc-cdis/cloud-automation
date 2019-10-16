#
# Run the lua module attached to our
# ambassador-gen3 api gateway through a test suite
#
test_nrun() {
  gen3 nrun elasticdump --help > /dev/null;  because $? "gen3 nrun elasticdump should work"
}

shunit_runtest "test_nrun" "nrun,local"
