#
# Test print_report_full
#


test_reports() {
  gen3 report-tool --report full; because $? "generating a report should succeed"
}

shunit_runtest "test_reports" "reports"

