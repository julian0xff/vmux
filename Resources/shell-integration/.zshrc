# vim:ft=zsh
#
# Compatibility shim: with the current integration model, vmux restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zshrc.

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${VMUX_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$VMUX_ZSH_ZDOTDIR"
    builtin unset VMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

builtin typeset _vmux_file="${ZDOTDIR-$HOME}/.zshrc"
[[ ! -r "$_vmux_file" ]] || builtin source -- "$_vmux_file"
builtin unset _vmux_file
