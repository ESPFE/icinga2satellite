#!/bin/bash

CHECKFILE='/opt/start.done'
MASTER_PORT=${MASTER_PORT:-"5665"}
NODE_ZONE=${NODE_ZONE:-"$NODE_NAME"}
PKI_DIR='/etc/icinga2/pki'

if [ ! -f '$CHECKFILE' ]; then
	echo "[start.sh] Configuring Icinga2 Satellite..."
   
	icinga2 pki save-cert \
		--host ${MASTER_HOST} \
		--port ${MASTER_PORT} \
		--trustedcert ${PKI_DIR}/${MASTER_HOST}.cert
		
	icinga2 pki new-cert \
		--cn ${NODE_NAME} \
		--key ${PKI_DIR}/${NODE_NAME}.key \
		--csr ${PKI_DIR}/${NODE_NAME}.csr \
		--cert ${PKI_DIR}/${NODE_NAME}.cert
		
	icinga2 pki request \
		--key ${PKI_DIR}/${NODE_NAME}.key \
		--cert ${PKI_DIR}/${NODE_NAME}.cert \
		--ca ${PKI_DIR}/${MASTER_HOST}.ca \
		--host ${MASTER_HOST} \
		--port ${MASTER_PORT} \
		--ticket ${PKI_TICKET} \
		--trustedcert ${PKI_DIR}/${MASTER_HOST}.cert
   
	icinga2 node setup \
		--accept-commands \
   		--accept-config \
   		--master_host ${MASTER_HOST} \
   		--endpoint ${MASTER_HOST} \
   		--ticket ${PKI_TICKET} \
   		--cn ${NODE_NAME} \
   		--zone ${NODE_ZONE} \
   		--trustedcert ${PKI_DIR}/${MASTER_HOST}.cert
   

	if [ $? -eq 0 ]; then
		echo "[start.sh] Configuration finished!"
		touch '$CHECKFILE';
	else
		echo "[start.sh] Configuration failed!"
		exit $?
	fi
fi

# Start supervisor
/usr/bin/supervisord
