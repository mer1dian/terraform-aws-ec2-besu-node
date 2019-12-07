#!/bin/bash
set -u -o pipefail

function wait_for_successful_command {
    local COMMAND=$1

    $COMMAND
    until [ $? -eq 0 ]
    do
        sleep 5
        $COMMAND
    done
}

function download_chain_metadata {
  local readonly DATADIR="main-network"
  curl https://raw.githubusercontent.com/freight-trust/freight-trust-network-data/master/$DATADIR/besu-genesis.json > /opt/besu/private/besu-genesis.json
  curl https://raw.githubusercontent.com/freight-trust/freight-trust-network-data/master/$DATADIR/bootnodes.txt > /opt/besu/info/bootnodes.txt
  # TODO: Enable private transactions
  #curl https://raw.githubusercontent.com/freight-trust/freight-trust-network-data/master/$DATADIR/orion-bootnodes.txt > /opt/besu/info/orion-bootnodes.txt
}

function generate_freight-trust_supervisor_config {
    local ADDRESS=$1
    local PASSWORD=$2
    local HOSTNAME=$3
 #  local orion_CONFIG=$4

    local NETID=$(cat /opt/besu/info/network-id.txt)
    local BOOTNODE_LIST=$(cat /opt/besu/info/bootnodes.txt)

    local VERBOSITY=4
    local PW_FILE="/tmp/freight-pw"
    # Add '--privateconfigpath $orion_CONFIG' to args after enabling private transactions
    local GLOBAL_ARGS="--networkid $NETID --rpc --rpcaddr $HOSTNAME --rpcvhosts \"*\" --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,besu --rpcport 22000 --rpccorsdomain \"*\" --port 21000 --verbosity $VERBOSITY"

    # Assemble list of bootnodes
    local BOOTNODES=""
    for bootnode in ${BOOTNODE_LIST[@]}
    do
        BOOTNODES="$BOOTNODES,$bootnode"
    done
    BOOTNODES=${BOOTNODES:1}

    echo "$PASSWORD" > $PW_FILE
    ARGS="$GLOBAL_ARGS --unlock \"$ADDRESS\" --password \"$PW_FILE\" --bootnodes $BOOTNODES"

    local COMMAND="freight $ARGS"

    echo "[program:freight-trust]
command=$COMMAND
stdout_logfile=/opt/besu/log/freight-trust-stdout.log
stderr_logfile=/opt/besu/log/freight-trust-error.log
numprocs=1
autostart=true
autorestart=false
stopsignal=INT
user=ubuntu" | sudo tee /etc/supervisor/conf.d/freight-trust-supervisor.conf
}

# 
# # function complete_orion_config {
#     local HOSTNAME=$1
#     local orion_CONFIG_PATH=$2

#     local BOOTNODES=$(cat /opt/besu/info/orion-bootnodes.txt)
#     local OTHER_NODES=""

#     # Configure orion with bootnode IPs
#     for bootnode in ${BOOTNODES[@]}
#     do
#         OTHER_NODES="$OTHER_NODES,\"http://$bootnode:9000/\""
#     done
#     OTHER_NODES=${OTHER_NODES:1}
#     OTHER_NODES_LINE="othernodes = [$OTHER_NODES]"

#     echo "$OTHER_NODES_LINE" >> $orion_CONFIG_PATH

#     # Configure orion with URL
#     echo "url = \"http://$HOSTNAME:9000/\"" >> $orion_CONFIG_PATH
# }

# Wait for operator to initialize and unseal vault
wait_for_successful_command 'vault init -check'
wait_for_successful_command 'vault status'

# Wait for vault to be fully configured by the root user
wait_for_successful_command 'vault auth -method=aws'

download_chain_metadata

# Load Address, Password, and Key if we already generated them or generate new ones if none exist
NODE_INDEX=$(cat /opt/besu/info/node-index.txt)
ADDRESS=$(vault read -field=address nodes/$NODE_INDEX/addresses)
if [ $? -eq 0 ]
then
    # Address is already in vault and this is a replacement instance.  Load info from vault
    freight_PW=$(wait_for_successful_command "vault read -field=freight_pw nodes/$NODE_INDEX/passwords")
 #   orion_PW=$(wait_for_successful_command "vault read -field=orion_pw nodes/$NODE_INDEX/passwords")
    # Generate orion key files
#    wait_for_successful_command "vault read -field=orion_pub_key nodes/$NODE_INDEX/addresses" > /opt/besu/orion/private/orion.pub
#    wait_for_successful_command "vault read -field=orion_priv_key nodes/$NODE_INDEX/keys" > /opt/besu/orion/private/orion.key
    # Generate freight key file
    freight_KEY_FILE_NAME=$(wait_for_successful_command "vault read -field=freight_key_file nodes/$NODE_INDEX/keys")
    freight_KEY_FILE_DIR="/home/ubuntu/.freight/keystore"
    mkdir -p $freight_KEY_FILE_DIR
    freight_KEY_FILE_PATH="$freight_KEY_FILE_DIR/$freight_KEY_FILE_NAME"
    wait_for_successful_command "vault read -field=freight_key nodes/$NODE_INDEX/keys" > $freight_KEY_FILE_PATH
elif [ -e /home/ubuntu/.freight/keystore/* ]
then
    # Address was created but not stored in vault. This is a process reboot after a previous failure.
    # Load address from file and password from vault
    freight_PW=$(wait_for_successful_command "vault read -field=freight_pw nodes/$NODE_INDEX/passwords")
  #  orion_PW=$(wait_for_successful_command "vault read -field=orion_pw nodes/$NODE_INDEX/passwords")
    ADDRESS=0x$(cat /home/ubuntu/.freight/keystore/* | jq -r .address)
    # Generate orion keys if they weren't generated last run
# >>    if [ ! -e /opt/besu/orion/private/orion.* ]
#     then
#         echo "$orion_PW" | orion-node --generatekeys=/opt/besu/orion/private/orion
#     fi
# else <<

    # This is the first run, generate a new key and password
    freight_PW=$(uuidgen -r)
    # 
  #  orion_PW=""
    # Store the password first so we don't lose it
    wait_for_successful_command "vault write nodes/$NODE_INDEX/passwords freight_pw=\"$freight_PW\"" # orion_pw=\"$orion_PW\""
    # Generate the new key pair
    ADDRESS=0x$(echo -ne "$freight_PW\n$freight_PW\n" | freight account new | grep Address | awk '{ gsub("{|}", "") ; print $2 }')
    # Generate orion keys
  #  echo "$orion_PW" | orion-node --generatekeys=/opt/besu/orion/private/orion
fi
#orion_PUB_KEY=$(cat /opt/besu/orion/private/orion.pub)
#orion_PRIV_KEY=$(cat /opt/besu/orion/private/orion.key)
HOSTNAME=$(wait_for_successful_command 'curl http://169.254.169.254/latest/meta-data/public-hostname')
PRIV_KEY=$(cat /home/ubuntu/.freight/keystore/*$(echo $ADDRESS | cut -d 'x' -f2))
PRIV_KEY_FILENAME=$(ls /home/ubuntu/.freight/keystore/)

# Write key and address into the vault
wait_for_successful_command "vault write nodes/$NODE_INDEX/keys freight_key=$PRIV_KEY freight_key_file=$PRIV_KEY_FILENAME"

# wait_for_successful_command "vault write nodes/$NODE_INDEX/addresses address=$ADDRESS orion_pub_key=$orion_PUB_KEY hostname=$HOSTNAME"

#complete_orion_config $HOSTNAME /opt/besu/orion/config.conf

# Initialize Freight Trust to run
freight init /opt/besu/private/besu-genesis.json

# Sleep to let orion bootnodes start first
# sleep 30
sleep 10

# TODO: Run orion after enabling private transactions
# Run orion
#sudo mv /opt/besu/private/orion-supervisor.conf /etc/supervisor/conf.d/
#sudo supervisorctl reread
#sudo supervisorctl update

# Sleep to let orion-node start
sleep 5

# Generate supervisor config to run besu
generate_freight-trust_supervisor_config $ADDRESS $freight_PW $HOSTNAME 
# /opt/besu/orion/config.conf

# Remove the config that runs this and run besu
sudo rm /etc/supervisor/conf.d/init-freight-trust-node-supervisor.conf
sudo supervisorctl reread
sudo supervisorctl update
