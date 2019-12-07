#!/bin/bash

# Freight Trust
# built from the Packer template in examples/vault-consul-ami/vault-consul.json.

set -eu

readonly BASH_PROFILE_FILE="/home/ubuntu/.bash_profile"
# This is necessary to retrieve the address for vault
echo "export VAULT_ADDR=https://${vault_dns}:${vault_port}" >> $BASH_PROFILE_FILE
source $BASH_PROFILE_FILE

sleep 60

readonly VAULT_TLS_CERT_DIR="/opt/vault/tls"
readonly CA_TLS_CERT_FILE="$VAULT_TLS_CERT_DIR/ca.crt.pem"
readonly VAULT_TLS_CERT_FILE="$VAULT_TLS_CERT_DIR/vault.crt.pem"
readonly VAULT_TLS_KEY_FILE="$VAULT_TLS_CERT_DIR/vault.key.pem"

function download_vault_certs {
    aws configure set s3.signature_version s3v4
    while [ -z "$(aws s3 ls s3://${vault_cert_bucket}/ca.crt.pem)" ]
    do
        echo "S3 object not found, waiting and retrying"
        sleep 5
    done
    while [ -z "$(aws s3 ls s3://${vault_cert_bucket}/vault.crt.pem)" ]
    do
        echo "S3 object not found, waiting and retrying"
        sleep 5
    done
    aws s3 cp s3://${vault_cert_bucket}/ca.crt.pem $VAULT_TLS_CERT_DIR
    aws s3 cp s3://${vault_cert_bucket}/vault.crt.pem $VAULT_TLS_CERT_DIR
    
    sudo chown ubuntu $VAULT_TLS_CERT_DIR/*
    sudo chmod 600 $VAULT_TLS_CERT_DIR/*
    sudo /opt/vault/bin/update-certificate-store --cert-file-path $CA_TLS_CERT_FILE
}

function populate_data_files {
    echo "${aws_region}" | sudo tee /opt/besu/info/aws-region.txt
    echo "${vault_ca_public_key}" | sudo tee /opt/vault/tls/ca.crt.pem
    echo "${vault_public_key}" | sudo tee /opt/vault/tls/vault.crt.pem
    echo "${vault_private_key}" | sudo tee /opt/vault/tls/vault.key.pem
    echo "${network_id}" | sudo tee /opt/besu/info/network-id.txt
    echo "${node_index}" | sudo tee /opt/besu/info/node-index.txt
}

function set_vault_tls_permissions {
    sudo chown vault /opt/vault/tls/*
    sudo chmod 600 /opt/vault/tls/*
    sudo /opt/vault/bin/update-certificate-store --cert-file-path /opt/vault/tls/ca.crt.pem
}


exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo apt update -y

populate_data_files
set_vault_tls_permissions


if [ ${vault_dns} == "127.0.0.1" ]
then
    /opt/vault/bin/generate-setup-vault ${iam_role_name}
    
    /opt/consul/bin/run-consul --server --cluster-tag-key "${consul_cluster_tag_key}" --cluster-tag-value "${consul_cluster_tag_value}"
    /opt/vault/bin/run-vault --s3-bucket "${s3_bucket_name}" --s3-bucket-region "${aws_region}" --tls-cert-file "$VAULT_TLS_CERT_FILE"  --tls-key-file "$VAULT_TLS_KEY_FILE"
else
    download_vault_certs
fi

/opt/besu/bin/run-init-freight-trust-node $VAULT_ADDR
