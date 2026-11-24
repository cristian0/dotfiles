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
# Qui facciamo l'unica cosa necessaria e sicura: symlinkare ~/.extra alla
# config specifica di air (.extra.air di questo repo), che a sua volta sorge
# .shared. Omarchy sorge ~/.extra in fondo al suo ~/.bashrc.
# Tutto ciò che è Mac-only (.aliases/.functions/.bash_profile/...) resta
# inutilizzato su questa macchina. Vedi README → "Dove vanno le modifiche".

set -euo pipefail

REPO="${HOME}/proj/dotfiles"
SHARED="${REPO}/.shared"
EXTRA_AIR="${REPO}/.extra.air"
EXTRA="${HOME}/.extra"

# 0. sanity check
if [ ! -f "${SHARED}" ] || [ ! -f "${EXTRA_AIR}" ]; then
	echo "✖  Manca ${SHARED} o ${EXTRA_AIR}."
	echo "   Clona prima il repo:  git clone <url> ${REPO}"
	exit 1
fi

# 1. ~/.extra -> .extra.air (idempotente)
#
# La config di shell di air vive QUI (dotfiles, file .extra.air tracciato),
# non nel repo homeserver: così air dipende solo da dotfiles, presente su ogni
# macchina. cm/mm/pimg stanno in .extra.air; il Mac non la sorgenta.
if [ -L "${EXTRA}" ] && [ "$(readlink "${EXTRA}")" = "${EXTRA_AIR}" ]; then
	echo "•  ~/.extra già symlink a .extra.air — niente da fare"
else
	if [ -e "${EXTRA}" ] || [ -L "${EXTRA}" ]; then
		backup="${EXTRA}.bak.$(date +%Y%m%d-%H%M%S)"
		mv "${EXTRA}" "${backup}"
		echo "•  ~/.extra preesistente spostato in ${backup}"
	fi
	ln -s "${EXTRA_AIR}" "${EXTRA}"
	echo "•  creato symlink ~/.extra → ${EXTRA_AIR}"
fi

echo
echo "✓  Fatto. Apri un nuovo terminale (o:  source ~/.extra)."
echo "   NON lanciare symlink-setup.sh su Omarchy."
