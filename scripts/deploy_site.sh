#!/bin/bash

# Variables
SSH_KEY_PATH="$HOME/.ssh/secret"   # Chemin absolu vers la clé
VM_USER="sai"                      # utilisateur SSH sur la VM Alpine
HOSTNAME=($hostname)

# Récupération de l'IP en argument
FLOATING_IP="$1"

if [ -z "$FLOATING_IP" ]; then
  echo "Usage: $0 <floating_ip>"
  exit 1
fi

echo "Connexion SSH à la VM via Floating IP : $FLOATING_IP"

# Script à exécuter sur la VM (via here‑document)
ssh -T -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$VM_USER@$FLOATING_IP" << 'EOF'
#!/bin/sh
set -e

# Mettre à jour et installer nginx
doas apk update
doas apk add nginx

# Créer le fichier de configuration nginx
doas tee /etc/nginx/http.d/default.conf > /dev/null << 'CONF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/localhost/htdocs;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
CONF

# Créer le fichier index.html
doas tee /var/www/localhost/htdocs/index.html > /dev/null << 'HTML'
<!DOCTYPE html>
<html>
<head>
  <title>SAI Eval Gitops Openstack</title>
</head>
<body>
  <h1>Serveur : \$HOSTNAME</h1>
  <p>hébergé sur Microstack Openstack</p>
</body>
</html>
HTML

# Redémarrer nginx
doas rc-service nginx restart
EOF

echo "Configuration Nginx sur la VM $FLOATING_IP Terminée"
