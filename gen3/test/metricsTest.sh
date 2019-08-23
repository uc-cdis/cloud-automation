test_metrics_check() {
  gen3 kube-setup-metrics check; because $? "kube-setup-metrics check should pass in the qa or dev cluster"
}

shunit_runtest "test_metrics_check" "metrics"
