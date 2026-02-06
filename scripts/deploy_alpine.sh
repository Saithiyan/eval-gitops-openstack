#!/bin/bash

# Vérifier les arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <nom_de_la_vm>"
  exit 1
fi

VM_NAME="$1"
IMAGE="Alpine3.21"
FLAVOR="Minus"
NETWORK="LAN-LABO"
USER_DATA="/var/snap/microstack/common/cloudinit/user-data.yaml"
# "../cloudinit/user-data.yaml"

# Vérifier si la VM existe déjà
if microstack.openstack server list | grep -q "$VM_NAME"; then
  echo "La VM existe déjà !"
  exit 0
fi

# Création de la VM avec cloud-init
microstack.openstack server create "$VM_NAME" \
  --image "$IMAGE" \
  --flavor "$FLAVOR" \
  --network "$NETWORK" \
  --user-data "$USER_DATA" \
  --config-drive true

echo "VM crée"

# Attendre que la VM soit ACTIVE
while true; do
  STATUS=$(microstack.openstack server show "$VM_NAME" -f value -c status 2>/dev/null || echo "ERROR")
  if [ "$STATUS" = "ACTIVE" ]; then
    break
  elif [ "$STATUS" = "ERROR" ]; then
    echo "Erreur : la VM $VM_NAME est en état ERROR"
    exit 1
  else
    echo "État actuel de la VM $VM_NAME : $STATUS, attente..."
    sleep 5
  fi
done

# Récupérer l’IP privée
IP=$(microstack.openstack server show "$VM_NAME" -f value -c addresses | cut -d= -f2)
echo "La VM $VM_NAME est déployée avec IP : $IP"


# Créer et Récupérer le Floating IP
# FLOATING_IP=$(microstack.openstack floating ip list --server "$VM_NAME" -f value -c Floating)
FLOATING_IP=$(microstack.openstack floating ip create external \
  -f value -c floating_ip_address)

# Association du Floating IP à la VM
microstack.openstack server add floating ip "$VM_NAME" "$FLOATING_IP"
echo "Floating ip $FLOATING_IP a été ajouté pour la VM $VM_NAME"

if [ -z "$FLOATING_IP" ]; then
  echo "Aucun Floating IP associé à la VM $VM_NAME"
  exit 1
fi

echo "Floating IP de la VM $VM_NAME: $FLOATING_IP"

# Lancer le script de déploiement nginx sur la VM
bash ./deploy_site.sh "$FLOATING_IP"
