title "Verify root account"
control "uchi-cis-aws-foundation" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR-DS-4']
  tag cis_aws: ['1.1']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']

  describe aws_iam_root_user do
    it { should have_mfa_enabled }
    it { should_not have_access_key }
    it { should have_hardware_mfa_enabled }
  end
end

title "IAM user has password less than 90 days"
control "uchi-cis-aws-foundation" do
 tag impact_score: 0.7
 tag nist_csf: ['PR.PT-1','PR.DS-4']
 tag cis_aws: ['1.3']
 tag nist_800_53: ['IA-5']
 tag nist_subcategory: ['PR.AC-1']
 tag env: ['test']
 tag aws_account_id: ['866696907']


   aws_iam_users.usernames.each do |usernames|
     describe aws_iam_users.where(has_mfa_enabled: false) do
       its('usernames') { should be_empty }
       its('password_ever_used?') { should cmp <= 90  }
       its('password_last_used_days_ago') { should cmp >= 1 }
       its('access_keys') { should cmp <= 90 }
     end
   end
 end

title "Password policy requirement"
control "uchi-cis-aws-foundation" do
  tag impact_score: 0.7
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.4']
  tag nist_800_53: ['IA-5']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_password_policy do
    it { should require_uppercase_characters }
    it { should require_lowercase_characters }
    it { should require_numbers }
    it { should require_symbols}
    it { should allow_users_to_change_password }
    it { should prevent_password_reuse }
    its('minimum_password_length') {should be > 8 }
  end
end

title "IAM-user-inline policies"
control "uchi-cis-aws-foundation" do
  tag impact_score: 0.7
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.5']
  tag nist_800_53: ['IA-5']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_users.where(has_inline_policies: true) do
    its('usernames') { should be_empty }
  end
end

title "Do not setup access keys during initial user setup for all IAM users
that have a console password"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.23']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


    aws_iam_access_keys.entries.each do |key|
      describe key.username do
        context key do
          its('last_used_days_ago') { should_not be_nil }
        end
      end
    end
    if aws_iam_access_keys.entries.empty?
      describe 'Control skipped because no iam access keys were found' do
        skip 'This control is skipped since the aws_iam_access_keys resource returned an empty access key list'
      end
    end
  end

title "Ensure IAM policies that allow full '*:*' administrative privileges are not created"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.24']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


    aws_iam_policies.where { attachment_count > 0 }.policy_names.each do |policy|
      describe "Attached Policies #{policy} allows full '*:*' privileges?" do
        subject do
          aws_iam_policy(policy).document.where(Effect: 'Allow').actions.flatten.include?('*') &&
            aws_iam_policy(policy).document.where(Effect: 'Allow').resources.flatten.include?('*')
        end
        it { should be false }
      end
    end

    if aws_iam_policies.where { attachment_count > 0 }.policy_names.empty?
      describe 'Control skipped because no iam policies were found' do
        skip 'This control is skipped since the aws_iam_policies resource returned an empty policy list'
      end
    end
  end

title "Ensure IAM password policy prevents password reuse"
control "uchi-cis-aws-foundations-1.10" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.10']
  tag nist_800_53: ['IA-5']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


    describe aws_iam_password_policy do
      it { should exist }
    end

    describe aws_iam_password_policy do
      its('prevent_password_reuse?') { should be true }
      its('number_of_passwords_to_remember') { should cmp <= 24 }
    end if aws_iam_password_policy.exists?
  end

title "Ensure IAM password policy expires passwords within number of days"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.11']
  tag nist_800_53: ['IA-5']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']



    describe aws_iam_password_policy do
      it { should exist }
    end

    describe aws_iam_password_policy do
      its('expire_passwords?') { should be true }
      its('max_password_age_in_days') { should cmp <= 90 }
    end if aws_iam_password_policy.exists?
  end

title "Ensure no root account access key exists"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.12']
  tag nist_800_53: ['AU-6']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_root_user do
    it { should_not have_access_key }
  end
end

title "Ensure MFA is enabled for the 'root' account"
control "uchi-cis-aws-foundations-1.13" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.13']
  tag nist_800_53: ['IA-2','SC-23']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_root_user do
    it { should have_mfa_enabled }
  end
end

title "Ensure hardware MFA is enabled for the root account"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.7
  tag nist_csf: ['PR.PT-1','PR-DS-4']
  tag cis_aws: ['1.14']
  tag nist_800_53: ['IA-2','SC-23']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_root_user do
    it { should have_mfa_enabled }
    it { should_not have_virtual_mfa_enabled }
  end
end

title "Ensure multi-factor authentication (MFA) is enabled for all IAM users
that have a console password"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR-DS-4']
  tag cis_aws: ['1.2']
  tag nist_800_53: ['IA-2','SC-23']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe 'The active IAM users that do not have MFA enabled' do
      subject { users_without_mfa }
      it { should be_empty }
  end
end

title "Ensure a support role has been created to manage incidents with AWS
Support"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.22']
  tag nist_800_53: ['IR-7']
  tag nist_subcategory: ['PR.PT-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_policy('AWSSupportAccess') do
    it { should be_attached }
  end
end

title "Ensure credentials unused for 90 days or greater are disabled"
control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.3']
  tag nist_800_53: ['IA-4']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  describe aws_iam_users.where(has_console_password?: true).where(password_never_used?: true) do
    it { should_not exist }
  end

  describe aws_iam_users.where(has_console_password?: true).where(password_ever_used?: true).where { password_last_used_days_ago >= 90 } do
    it { should_not exist }
  end

  aws_iam_access_keys.where(active: true).entries.each do |key|
    describe key.username do
      context key do
        its('last_used_days_ago') { should cmp < 90 }
      end
    end
  end

  if aws_iam_access_keys.where(active: true).entries.empty?
    describe 'Control skipped because no active iam access keys were found' do
      skip 'This control is skipped since the aws_iam_access_keys resource returned an empty active access key list'
    end
  end
end

title "Ensure access keys are rotated every number of days"

control "uchi-cis-aws-foundations" do
  tag impact_score: 0.3
  tag nist_csf: ['PR.PT-1','PR.DS-4']
  tag cis_aws: ['1.4']
  tag nist_800_53: ['IA-5']
  tag nist_subcategory: ['PR.AC-1']
  tag env: ['test']
  tag aws_account_id: ['866696907']


  aws_iam_access_keys.where(active: true).entries.each do |key|
    describe key.username do
      context key do
        its('created_days_ago') { should cmp <= 90 }
        its('ever_used') { should be true }
      end
    end
  end
end

  