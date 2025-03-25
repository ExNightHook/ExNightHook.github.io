HOME_DIR="$HOME"

echo "Generating SSH-key..."
mkdir -p "$HOME_DIR/.ssh"
ssh-keygen -t rsa -b 4096 -N "" -f "$HOME_DIR/.ssh/id_rsa_gitlab" -q

cat << EOF >> "$HOME_DIR/.ssh/config"
Host gitlab.com
  IdentityFile $HOME_DIR/.ssh/id_rsa_gitlab
  IdentitiesOnly yes
EOF

eval "$(ssh-agent -s)"
ssh-add "$HOME_DIR/.ssh/id_rsa_gitlab"

clear
echo "========== Your SSH-key for GitLab =========="
cat "$HOME_DIR/.ssh/id_rsa_gitlab.pub"
echo "=============================================="
echo "Copy key in GitLab (Settings -> SSH Keys)"
sleep 5
