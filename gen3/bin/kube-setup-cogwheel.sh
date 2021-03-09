#!/bin/bash
#
# Deploy cogwheel service (Set up db and secrets if not already)
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


mkdir -p $(gen3_secrets_folder)/g3auto/cogwheel


# Set up database if it does not already exist, along with Fence client
if gen3 db services | grep cogwheel &> /dev/null; then
        gen3_log_info "Found existing Cogwheel DB. Skipping setup for DB, Fence client, and wsgi_settings.py."
else
        gen3_log_info "No Cogwheel DB found. If this is first-time setup, see also cloud-automation/doc/cogwheel-setup.md for more information."

        # Mark (probable) first-time setup
        touch $(gen3_secrets_folder)/g3auto/cogwheel/.first_time_setup_flag

        gen3_log_info "Setting up new Cogwheel DB..."
        gen3 db setup cogwheel
        gen3_log_info "New Cogwheel DB created."

        # Check for indexd db server quirk
        if gen3 psql cogwheel -c "\dt" | grep index_record_g_ace &> /dev/null; then
                gen3_log_warn "Found index_record_g_ace table in the new DB. This is fine; see doc/cogwheel-setup.md for more info."
        fi

        # Check that dbcreds.json now exists
        if [[ ! -f "$(gen3_secrets_folder)/g3auto/cogwheel/dbcreds.json" ]]; then
                gen3_log_err "Could not find dbcreds.json after DB setup attempt. Aborting"
                exit 1
        fi

        # Warn if wsgi_settings.py already exists (DB setup implies first-time setup, so this is strange)
        if [[ -f "$(gen3_secrets_folder)/g3auto/cogwheel/wsgi_settings.py" ]]; then
                gen3_log_warn "Found existing wsgi_settings.py during DB setup post-processing. Appending to file"
        fi

        # Set up (or append to) wsgi_settings.py
        cd $(gen3_secrets_folder)/g3auto/cogwheel
        echo "DEBUG = False" >> wsgi_settings.py
        echo "SQLALCHEMY_DATABASE_URI = $(jq '@uri "postgresql://\(.db_username):\(.db_password)@\(.db_host)/\(.db_database)"' dbcreds.json)" >> wsgi_settings.py
        cd -
fi


cd $(gen3_secrets_folder)/g3auto/cogwheel

# Download InCommon Metadata Service signing certificate and check fingerprint
if [[ ! -f "mdqsigner.pem" ]]; then
        gen3_log_info "Downloading InCommon Metadata Service signing cert mdqsigner.pem..."
        curl https://md.incommon.org/certs/inc-md-cert-mdq.pem > mdqsigner.pem
        gen3_log_info "Checking certificate fingerprint..."
        if [ "$(cat mdqsigner.pem | openssl x509 -sha256 -noout -fingerprint)" != "SHA256 Fingerprint=60:49:74:D6:1F:E0:D7:F4:D6:3D:6C:8D:B9:8A:85:7E:64:2A:B9:B4:70:E3:E8:5D:D5:4D:66:3D:04:96:F9:00" ]; then
                gen3_log_err "Signing cert had unexpected fingerprint."
                exit 1
        fi
        gen3_log_info "Fingerprint OK. Cert download successful."
else
        gen3_log_info "Found existing mdqsigner.pem."
fi


# Generate RSA keypair for OIDC
if [[ ! -f "rsa_privatekey.pem" ]]; then
        gen3_log_info "Generating RSA keypair..."
        openssl genpkey -algorithm RSA -out rsa_privatekey.pem -outform pem
        openssl pkey -in rsa_privatekey.pem -inform pem -out rsa_publickey.pem -outform pem -pubout
        gen3_log_info "Generated rsa_privatekey.pem and rsa_publickey.pem."
elif [[ ! -f "rsa_publickey.pem" ]]; then
        gen3_log_warn "Found rsa_privatekey.pem but no rsa_publickey.pem; generating the latter."
        openssl pkey -in rsa_privatekey.pem -inform pem -out rsa_publickey.pem -outform pem -pubout
else
        gen3_log_info "Found existing rsa_privatekey.pem and rsa_publickey.pem."
fi


# Prepare oauth2_metadata.json
if [[ ! -f "oauth2_metadata.json" ]]; then
        gen3_log_info "Downloading and editing template oauth2_metadata.json..."
        curl https://raw.githubusercontent.com/uc-cdis/cogwheel/master/template.oauth2_metadata.json > oauth2_metadata.json
        sed -i "s/localhost:1234/$GEN3_CACHE_HOSTNAME\/cogwheel/g" oauth2_metadata.json
        sed -i "/issuer/s/cogwheel\//cogwheel/" oauth2_metadata.json
        gen3_log_info "Generated oauth2_metadata.json."
else
        gen3_log_info "Found existing oauth2_metadata.json."
fi


# Prepare ssl.conf
if [[ ! -f "ssl.conf" ]]; then
        gen3_log_info "Downloading and editing template ssl.conf..."
        curl https://raw.githubusercontent.com/uc-cdis/cogwheel/master/template.ssl.conf > ssl.conf
        sed -i "s/^#ServerName www.example.com:443/ServerName $GEN3_CACHE_HOSTNAME/" ssl.conf

        sed -i "/ShibRequestSetting requireSession 1/a\ \ ShibRequestSetting REMOTE_ADDR \"X-Forwarded-For\"" ssl.conf
        sed -i "s/\/oauth\/token/\/cogwheel\/oauth\/token/" ssl.conf
        sed -i "s/\/.well-known\/oauth-authorization-server/\/cogwheel\/.well-known\/oauth-authorization-server/" ssl.conf
        sed -i "s/\/jwks.json/\/cogwheel\/jwks.json/" ssl.conf

        gen3_log_info "Generated ssl.conf."
else
        gen3_log_info "Found existing ssl.conf."
fi


# Check for SP signing/encryption certs/keys
if [[ ! -f "sp-encrypt-cert.pem" || ! -f "sp-encrypt-key.pem" || ! -f "sp-signing-cert.pem" || ! -f "sp-signing-key.pem" ]]; then
        # If EVERY file is missing, generate all of them and log instructions for SP registration.
        # If only some missing, that's weird; warn and do nothing.
        if [[ ! -f "sp-encrypt-cert.pem" && ! -f "sp-encrypt-key.pem" && ! -f "sp-signing-cert.pem" && ! -f "sp-signing-key.pem" ]]; then
                gen3_log_warn "!!! Did not find any of sp-[encrypt, signing]-[cert, key].pem; generating these files now. If you intend to use InCommon and have not registered an SP, do that (see Cogwheel README) and use these certs/keys. If you have already registered an SP, manually overwrite these files with your SP's certs/keys. !!!"
                # Generate keypair
                openssl req -new -x509 -newkey rsa:2048 -keyout sp-encrypt-key.pem -days 3650 -subj "/CN=$GEN3_CACHE_HOSTNAME" -out sp-encrypt-cert.pem -nodes
                # Use same pair for signing and encryption
                cp sp-encrypt-cert.pem sp-signing-cert.pem
                cp sp-encrypt-key.pem  sp-signing-key.pem
                gen3_log_info "Generated sp-encrypt-key.pem, sp-encrypt-cert.pem, sp-signing-key.pem, sp-signing-cert.pem."
        else
                gen3_log_warn "!!! Found some but not all of sp-[encrypt, signing]-[cert, key].pem files. Please supply all four of these. See Cogwheel README for more info. !!!"
        fi
else
        gen3_log_info "Found existing SP signing/encryption certs and keys."
fi


# Download template shibboleth2.xml and log instructions to edit it
if [[ ! -f "shibboleth2.xml" ]]; then
        gen3_log_info "Downloading template shibboleth2.xml..."
        curl https://raw.githubusercontent.com/uc-cdis/cogwheel/master/template.shibboleth2.xml > shibboleth2.xml
        sed -i "s/<Sessions /<Sessions handlerURL=\"\/cogwheel\/Shibboleth.sso\" /" shibboleth2.xml

        gen3_log_warn "Downloaded template shibboleth2.xml. You must edit this file with at least your SP EntityID! See Cogwheel README for instructions."
else
        gen3_log_info "Found existing shibboleth2.xml."
fi


# Create Fence client if first-time setup
if [[ -f ".first_time_setup_flag" ]]; then
        gen3_log_warn "Creating new Fence client: Kicking off cogwheel-register-client k8s job. Check pod logs for details. Remember to edit your Fence config."
        gen3 secrets sync
        gen3 job run cogwheel-register-client
fi


# Deploy unless first-time setup
if [[ -f ".first_time_setup_flag" ]]; then
        gen3_log_info "Assuming this was first time setup; will not auto deploy Cogwheel. Edit necessary config and rerun kube-setup-cogwheel."
else
        gen3_log_info "Deploying Cogwheel service..."
        gen3 secrets sync
        gen3 roll cogwheel
        g3kubectl apply -f "${GEN3_HOME}/kube/services/cogwheel/cogwheel-service.yaml"
fi

rm -f .first_time_setup_flag

gen3_log_info "Finished Cogwheel setup."
