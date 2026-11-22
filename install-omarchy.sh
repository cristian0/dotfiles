#!/usr/bin/env bash
#
# install-omarchy.sh — integra questi dotfiles su Omarchy (Arch + Hyprland)
# SENZA toccare la shell gestita da Omarchy.
#
# ⚠️  NON lanciare `symlink-setup.sh` su Omarchy: quello symlinka TUTTI i
#     dotfile (.bashrc, .bash_profile, .inputrc, .aliases, ...) nella home e
#     sovrascriverebbe il ~/.bashrc di Omarchy, che fa il bootstrap di
#     OMARCHY_PATH + starship + eza + zoxide. Risultato: shell rotta.
#
# Qui facciamo l'unica cosa necessaria e sicura: agganciare il file portabile
# .shared dal ~/.extra di Omarchy (che Omarchy sorge in fondo al suo ~/.bashrc).
# Tutto ciò che è Mac-only (.aliases/.functions/.bash_profile/...) resta
# inutilizzato su questa macchina. Vedi README → "Dove vanno le modifiche".

set -euo pipefail

REPO="${HOME}/proj/dotfiles"
SHARED="${REPO}/.shared"
EXTRA="${HOME}/.extra"

# 0. sanity check
if [ ! -f "${SHARED}" ]; then
	echo "✖  Manca ${SHARED}."
	echo "   Clona prima il repo:  git clone <url> ${REPO}"
	exit 1
fi

# 1. aggancia .shared da ~/.extra (idempotente)
touch "${EXTRA}"
if grep -qF "dotfiles/.shared" "${EXTRA}"; then
	echo "•  ~/.extra aggancia già .shared — niente da fare"
else
	{
		echo ""
		echo "# Alias e funzioni portabili condivisi col Mac (repo dotfiles)"
		echo "[ -r ~/proj/dotfiles/.shared ] && source ~/proj/dotfiles/.shared"
	} >> "${EXTRA}"
	echo "•  aggiunto il source di .shared a ~/.extra"
fi

echo
echo "✓  Fatto. Apri un nuovo terminale (o:  source ~/.extra)."
echo "   NON lanciare symlink-setup.sh su Omarchy."
