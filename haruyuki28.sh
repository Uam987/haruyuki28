#!/bin/bash

set -e

########################################
# Haruyuki28 CFX Miner Bootstrap
# lolMiner 1.98a + f2pool
########################################


echo "================================="
echo "[+] Haruyuki28 miner deployment"
echo "================================="


########################################
# Configuration
########################################


USER_NAME="sxc258"

HOME_DIR="/home/${USER_NAME}"

MINER_DIR="${HOME_DIR}/miner"

MINER_VERSION="1.98a"

POOL="conflux.f2pool.com:6800"

MINER_URL="https://github.com/Lolliedieb/lolMiner-releases/releases/download/${MINER_VERSION}/lolMiner_v${MINER_VERSION}_Lin64.tar.gz"



########################################
# Load wallet
########################################


ENV_FILE="/etc/cfx-miner.env"


if [ ! -f "${ENV_FILE}" ]; then

    echo "[ERROR] ${ENV_FILE} not found"

    exit 1

fi


source ${ENV_FILE}



if [ -z "${CFX_WALLET}" ]; then

    echo "[ERROR] CFX_WALLET is empty"

    exit 1

fi



WORKER_NAME=$(hostname)


MINER_ACCOUNT="${CFX_WALLET}.${WORKER_NAME}"



echo "[+] Worker:"
echo ${WORKER_NAME}





########################################
# Check NVIDIA
########################################


if ! command -v nvidia-smi >/dev/null 2>&1
then

    echo "[ERROR] NVIDIA driver missing"

    exit 1

fi



echo "[+] NVIDIA GPU"

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader



########################################
# Install dependencies
########################################


echo "[+] Installing dependencies"


apt-get update -y


apt-get install -y \
wget \
curl \
tar



########################################
# Prepare directory
########################################


mkdir -p ${MINER_DIR}


chown -R ${USER_NAME}:${USER_NAME} ${MINER_DIR}




########################################
# Download lolMiner
########################################


cd ${MINER_DIR}



if [ ! -f lolMiner.tar.gz ]
then

    echo "[+] Downloading lolMiner ${MINER_VERSION}"

    wget \
    -O lolMiner.tar.gz \
    ${MINER_URL}


else

    echo "[+] Existing lolMiner archive found"

fi




########################################
# Extract miner
########################################


LOL_DIR=$(find ${MINER_DIR} \
-maxdepth 1 \
-type d \
-name "lolMiner*" \
| head -1)



if [ -z "${LOL_DIR}" ]
then

    echo "[+] Extracting lolMiner"

    tar -xf lolMiner.tar.gz

fi



LOL_DIR=$(find ${MINER_DIR} \
-maxdepth 1 \
-type d \
-name "lolMiner*" \
| head -1)



if [ -z "${LOL_DIR}" ]
then

    echo "[ERROR] lolMiner directory not found"

    exit 1

fi



echo "[+] Miner path:"
echo ${LOL_DIR}




########################################
# Create launcher
########################################


cat > ${MINER_DIR}/start_cfx.sh <<EOF
#!/bin/bash

cd ${LOL_DIR}


./lolMiner \\
--algo CFX \\
--pool ${POOL} \\
--user ${MINER_ACCOUNT} \\
--pass x

EOF



chmod +x ${MINER_DIR}/start_cfx.sh




########################################
# Create systemd service
########################################


cat >/etc/systemd/system/cfx-miner.service <<EOF

[Unit]

Description=CFX lolMiner

After=network-online.target

Wants=network-online.target



[Service]

Type=simple

User=${USER_NAME}

WorkingDirectory=${MINER_DIR}

ExecStart=${MINER_DIR}/start_cfx.sh

Restart=always

RestartSec=15



[Install]

WantedBy=multi-user.target

EOF





########################################
# Enable service
########################################


echo "[+] Starting miner"



systemctl daemon-reload


systemctl enable cfx-miner


systemctl restart cfx-miner



sleep 5




########################################
# Finish
########################################


echo "================================="
echo "[+] Deployment finished"
echo "[+] Wallet:"
echo ${CFX_WALLET}
echo "[+] Worker:"
echo ${WORKER_NAME}
echo "================================="



systemctl status cfx-miner --no-pager
