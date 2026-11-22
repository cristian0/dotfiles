# Load ~/.extra, ~/.bash_prompt, ~/.exports, ~/.aliases and ~/.functions
# ~/.extra can be used for settings you don’t want to commit
for file in ~/.{extra,bash_prompt,exports,aliases,functions,secret,dc}; do
	[ -r "$file" ] && source "$file"
done
unset file

# generic colouriser
GRC=`which grc`
if [ "$TERM" != dumb ] && [ -n "$GRC" ]
    then
        alias colourify="$GRC -es --colour=auto"
        alias configure='colourify ./configure'
        for app in {diff,make,gcc,g++,mtr,ping,traceroute}; do
            alias "$app"='colourify '$app
        done
fi

##
## bash history → centralizzata in ~/proj/dotfiles/.shared
## (sorgente in fondo a questo file, condivisa con Omarchy)
##


##
## Completion…
##

# bash completion.
#if which brew > /dev/null && [ -f "$(brew --prefix)/share/bash-completion/bash_completion" ]; then
#    source "$(brew --prefix)/share/bash-completion/bash_completion";
#elif [ -f /etc/bash_completion ]; then
#    source /etc/bash_completion;
# fi;

if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi

# Enable tab completion for `g` by marking it as an alias for `git`
if type _git &> /dev/null && [ -f /usr/local/etc/bash_completion.d/git-completion.bash ]; then
    complete -o default -o nospace -F _git g;
fi;

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2)" scp sftp ssh

# Add tab completion for `defaults read|write NSGlobalDomain`
# You could just use `-g` instead, but I like being explicit
complete -W "NSGlobalDomain" defaults


##
## better `cd`'ing
##

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob;

# Autocorrect typos in path names when using `cd`
shopt -s cdspell;

#
# setup ssh-agent
#


# set environment variables if user's agent already exists
[ -z "$SSH_AUTH_SOCK" ] && SSH_AUTH_SOCK=$(ls -l /tmp/ssh-*/agent.* 2> /dev/null | grep $(whoami) | awk '{print $9}')
[ -z "$SSH_AGENT_PID" -a -z `echo $SSH_AUTH_SOCK | cut -d. -f2` ] && SSH_AGENT_PID=$((`echo $SSH_AUTH_SOCK | cut -d. -f2` + 1))
[ -n "$SSH_AUTH_SOCK" ] && export SSH_AUTH_SOCK
[ -n "$SSH_AGENT_PID" ] && export SSH_AGENT_PID

# start agent if necessary
if [ -z $SSH_AGENT_PID ] && [ -z $SSH_TTY ]; then  # if no agent & not in ssh
  eval `ssh-agent -s` > /dev/null
fi

# # setup addition of keys when needed
# if [ -z "$SSH_TTY" ] ; then                     # if not using ssh
#   ssh-add -l > /dev/null                        # check for keys
#   if [ $? -ne 0 ] ; then
#     alias ssh='ssh-add -l > /dev/null || ssh-add && unalias ssh ; ssh'
#     if [ -f "/usr/lib/ssh/x11-Zssh-askpass" ] ; then
#       SSH_ASKPASS="/usr/lib/ssh/x11-ssh-askpass" ; export SSH_ASKPASS
#     fi
#   fi
# fi

# add all stored ssh keys in Mac
ssh-add -A &> /dev/null

# z beats cd most of the time.
#   github.com/rupa/z
source ~/proj/z/z.sh

# docker machine
#eval "$(docker-machine env default)"

#aws autocomplete
#complete -C aws_completer aws

#export PATH=/usr/local/lib/python2.7:$PATH

# ansible conf hosts
# export ANSIBLE_HOSTS=$HOME/.ansible/hosts

if [ -f ~/.git-completion.bash ]; then
  source ~/.git-completion.bash
fi

## nvm (node version manager)
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

## pyenv : https://github.com/pyenv/pyenv?tab=readme-ov-file#b-set-up-your-shell-environment-for-pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# ClaudeCode
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client@8.0/bin:$PATH"

# Alias/funzioni/history portabili condivisi con Omarchy (sorgi per ultimo,
# così vince sulle impostazioni qui sopra). Vedi README → "Dove vanno le modifiche".
[ -r ~/proj/dotfiles/.shared ] && source ~/proj/dotfiles/.shared
