test_jupyter_prepuller() {
  (gen3 jupyter prepuller | yq -e -r . > /dev/null); because $? "jupyter prepuller generates valid yaml"
  (gen3 jupyter prepuller extra1 extra2 | yq -e -r . > /dev/null); because $? "jupyter prepuller with extra images generates valid yaml"
}

test_jupyter_namespace() {
  local namespace
  namespace="$(
    export KUBECTL_NAMESPACE=default
    gen3 jupyter j-namespace
  )"
  [[ "$namespace" == "jupyter-pods" ]]; because $? "default namespace should map to jupyter-pods, got: $namespace"
  namespace="$(
    export KUBECTL_NAMESPACE=frickjack
    gen3 jupyter j-namespace
  )"
  [[ "$namespace" == "jupyter-pods-frickjack" ]]; because $? "frickjack namespace should map to jupyter-pods-frickjack, got: $namespace"
}

test_jupyter_setup() {
  gen3 jupyter j-namespace setup; because $? "jupyter namespace setup should work";
}

test_jupyter_idle() {
  gen3 jupyter idle; because $? "jupyter idle should run ok"
}

test_jupyter_metrics() {
  gen3 jupyter metrics; because $? "jupyter metrics should run ok"
}

shunit_runtest "test_jupyter_idle" "jupyter"
# shunit_runtest "test_jupyter_metrics" "jupyter"
shunit_runtest "test_jupyter_prepuller" "local,jupyter"
shunit_runtest "test_jupyter_namespace" "local,jupyter"
shunit_runtest "test_jupyter_setup" "jupyter"
