CURRENT_DIR="$(pwd)"
# This is to Install dotfiles without precloning
sudo pacman -S git

git clone https://github.com/jsah-mc/seam.git ~/.cache/seamdots
cd ~/.cache/seamdots/
./install.sh
cd $CURRENT_DIR