#!/bin/bash

set -e


#####################################
# CFX Miner Bootstrap
# lolMiner 1.98a + f2pool
#####################################


USER_NAME="sxc258"

HOME_DIR="/home/${USER_NAME}"

MINER_DIR="${HOME_DIR}/miner"

MINER_VERSION="1.98a"

POOL="conflux.f2pool.com:6800"


#####################################
# Load wallet
#####################################


if [ ! -f /etc/cfx-miner.env ]; then
    echo "[ERROR] Missing /etc/cfx-miner.env"
    exit 1
fi


source /etc/cfx-miner.env


if [ -z "${CFX_WALLET}" ]; then
    echo "[ERROR] CFX_WALLET not configured"
    exit 1
fi


WORKER_NAME=$(hostname)

MINER_USER="${CFX_WALLET}.${WORKER_NAME}"


MINER_URL="https://github.com/Lolliedieb/lolMiner-releases/releases/download/${MINER_VERSION}/lolMiner_v${MINER_VERSION}_Lin64.tar.gz"



echo "================================="
echo "Deploying CFX Miner"
echo "Worker: ${WORKER_NAME}"
echo "================================="



#####################################
# Check NVIDIA
#####################################


if ! command -v nvidia-smi >/dev/null 2>&1
then
    echo "[ERROR] NVIDIA driver not found"
    exit 1
fi


echo "[+] GPU detected"

nvidia-smi --query-gpu=name --format=csv,noheader



#####################################
# Dependencies
#####################################


apt-get update -y

apt-get install -y \
wget \
curl \
tar



#####################################
# Prepare directory
#####################################


mkdir -p ${MINER_DIR}

chown -R ${USER_NAME}:${USER_NAME} ${MINER_DIR}



#####################################
# Download lolMiner
#####################################


cd ${MINER_DIR}


if [ ! -f lolMiner.tar.gz ]
then

    echo "[+] Download lolMiner ${MINER_VERSION}"

    wget \
    -O lolMiner.tar.gz \
    ${MINER_URL}

else

    echo "[+] lolMiner archive exists"

fi



#####################################
# Extract
#####################################


if ! find ${MINER_DIR} -maxdepth 1 -type d -name "lolMiner*" | grep -q .
then

    echo "[+] Extracting"

    tar -xf lolMiner.tar.gz

fi



LOL_DIR=$(find ${MINER_DIR} \
-maxdepth 1 \
-type d \
-name "lolMiner*" \
| head -1)


if [ -z "${LOL_DIR}" ]
then
    echo "[ERROR] lolMiner directory missing"
    exit 1
fi



#####################################
# Create miner launcher
#####################################


cat > ${MINER_DIR}/start_cfx.sh <<EOF
#!/bin/bash

cd ${LOL_DIR}

./lolMiner \\
--algo CFX \\
--pool ${POOL} \\
--user ${MINER_USER} \\
--pass x

EOF


chmod +x ${MINER_DIR}/start_cfx.sh



#####################################
# systemd service
#####################################


cat >/etc/systemd/system/cfx-miner.service <<EOF

[Unit]
Description=Conflux lolMiner
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



#####################################
# Start miner
#####################################


systemctl daemon-reload

systemctl enable cfx-miner

systemctl restart cfx-miner



sleep 3


echo "================================="
echo "CFX Miner deployed"
echo "Worker:"
echo ${WORKER_NAME}
echo "================================="


systemctl status cfx-miner --no-pager