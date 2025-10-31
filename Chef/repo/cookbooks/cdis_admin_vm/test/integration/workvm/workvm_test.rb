# InSpec test for recipe cdis_admin_vm::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://www.inspec.io/docs/reference/resources/

  # This is an example test, replace with your own test.
  describe package('git') do
    it { should be_installed }
  end

  describe package('jq') do
    it { should be_installed }
  end

  describe package('python') do
    it { should be_installed }
  end

  describe package('python3') do
    it { should be_installed }
  end

  describe package('google-cloud-sdk') do
    it { should be_installed }
  end

  describe package('kubectl') do
    it { should be_installed }
  end

  describe pip('awscli','/usr/bin/pip3') do
    it { should be_installed }
  end

  describe pip('jinja2','/usr/bin/pip3') do
    it { should be_installed }
  end

  describe pip('yq','/usr/bin/pip3') do
    it { should be_installed }
  end

  describe file('/usr/local/bin/terraform') do
    it { should exist }
    its('mode') { should cmp '0755' }
    it { should be_owned_by 'root' }
  end

  describe file('/usr/local/bin/terraform12') do
    it { should exist }
    its('mode') { should cmp '0755' }
    it { should be_owned_by 'root' }
  end

  describe file('/usr/local/bin/packer') do
    it { should exist }
    its('mode') { should cmp '0755' }
    it { should be_owned_by 'root' }
  end

  describe file('/usr/local/bin/helm') do
    it { should exist }
    its('mode') { should cmp '0755' }
    it { should be_owned_by 'root' }
  end
