# copy paste this file in bit by bit.
# don't run it.
  echo "do not run this script in one go. hit ctrl-c NOW"
  read -n 1



# read migration.md where more migrationy tips are!


# https://github.com/jamiew/git-friendly
# the `push` command which copies the github compare URL to my clipboard is heaven
#bash < <( curl https://raw.github.com/jamiew/git-friendly/master/install.sh)

# https://rvm.io
# rvm for the rubiess
#curl -L https://get.rvm.io | bash -s stable --ruby

# https://github.com/isaacs/nave
# needs npm, obviously.
# TODO: I think i'd rather curl down the nave.sh, symlink it into /bin and use that for initial node install.
#npm install -g nave


# homebrew!
# (google machines are funny so i have to do this. everyone else should use the regular thang)
#mkdir $HOME/.homebrew && curl -L https://github.com/mxcl/homebrew/tarball/master | tar xz --strip 1 -C $HOME/.homebrew
#export PATH=$HOME/.homebrew/bin:$HOME/.homebrew/sbin:$PATH
# install all the things
./brew.sh


# https://github.com/rupa/z
# z, oh how i love you
cd ~/proj
git clone https://github.com/rupa/z.git
chmod +x ~/proj/z/z.sh
# also consider moving over your current .z file if possible. it's painful to rebuild :)

# z binary is already referenced from .bash_profile


# change to bash 4 (installed by homebrew)
#BASHPATH=$(brew --prefix)/bin/bash
#sudo echo $BASHPATH >> /etc/shells
#chsh -s $BASHPATH # will set for current user only.
#echo $BASH_VERSION # should be 4.x not the old 3.2.X

# Later, confirm iterm settings aren't conflicting.

# create your .gitconfig.local like this
#[user]
#    name = cristiano
#    email = cristiano@eboox.it




# symlinks!
#   put/move git credentials into ~/.gitconfig.local
#   http://stackoverflow.com/a/13615531/89484
./symlink-setup.sh
