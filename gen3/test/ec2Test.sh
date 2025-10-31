

if ! EC2_TEST_IP="$(g3kubectl get nodes -o json | jq -r -e '.items[3].status.addresses[] | select(.type == "InternalIP") | .address')" || [[ -z "$EC2_TEST_IP" ]]; then
  gen3_log_err "ec2Test failed to acquire IP address of a k8s node to test against"
fi

test_ec2_init() {
  [[ -n "$EC2_TEST_IP" ]]; because $? "acquired a test IP to test with: $EC2_TEST_IP"
}

test_ec2_filter() {
  test_ec2_init
  local filter
  
  # not sure why the config file was no longer showing up.
  if [ -f "~/.aws/config" ]; then
    echo "aws config file exists"
  else
    echo "aws config file does not exist, create it now"
    mkdir -p ~/.aws
    cat <<- EOF > ~/.aws/config
[default]
output = json
region = us-east-1

[profile jenkins]
output = json
region = us-east-1
EOF
  fi

  filter="$(gen3 ec2 filters --private-ip $EC2_TEST_IP)"; because $? "private IP filter works"
  [[ "$filter" =~ ^--filter ]]; because $? "ec2 filter starts with --filter"
  (gen3 ec2 describe --private-ip $EC2_TEST_IP || echo ERROR) | jq -r . > /dev/null
      because $? "describe private-ip works"
  local id
  id="$(gen3 ec2 instance-id --private-ip $EC2_TEST_IP)" && [[ "$id" =~ ^i-[0-9a-z]*$ ]]
      because $? "ec2 instance-id works - got: $id"
  (gen3 ec2 describe --instance-id $id || echo ERROR) | jq -r . > /dev/null
      because $? "ec2 describe with instance-id filter works"
}

test_ec2_asg_describe() {
  local info
  info="$(gen3 ec2 asg-describe default)" && jq -r . <<< "$info" > /dev/null
      because $? "default asg looks ok"
  info="$(gen3 ec2 asg-describe jupyter)" && jq -r . <<< "$info" > /dev/null
      because $? "jupyter asg looks ok"
}

shunit_runtest "test_ec2_filter" "ec2"
shunit_runtest "test_ec2_asg_describe" "ec2"
