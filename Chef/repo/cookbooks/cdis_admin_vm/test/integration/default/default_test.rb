# InSpec test for recipe cdis_admin_vm::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://www.inspec.io/docs/reference/resources/

  # This is an example test, replace with your own test.
describe user('test1')  do
  it { should exist }
end

describe user('test2')  do
  it { should exist }
end

describe user('test3') do
  it { should exist }
end

describe file('/home/test1/.ssh/authorized_keys') do
  it { should exist }
  its('mode') { should cmp '0600' }
  it { should be_owned_by 'test1' }
  its('content') { should match ("test2\ntest3") }
end

describe file('/home/test2/.ssh/authorized_keys') do
  it { should exist }
  its('mode') { should cmp '0600' }
  it { should be_owned_by 'test2' }
  its('content') { should match ("test1\ntest2") }
end

describe file('/home/test3/.ssh/authorized_keys') do
  it { should exist }
  its('mode') { should cmp '0600' }
  it { should be_owned_by 'test3' }
  its('content') { should match ("test1\ntest2") }
end

