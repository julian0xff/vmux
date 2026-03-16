# vim:ft=zsh
#
# vmux ZDOTDIR bootstrap for zsh.
#
# GhosttyKit already uses a ZDOTDIR injection mechanism for zsh (setting ZDOTDIR
# to Ghostty's integration dir). vmux also needs to run its integration, but
# we must restore the user's real ZDOTDIR immediately so that:
# - /etc/zshrc sets HISTFILE relative to the real ZDOTDIR/HOME (shared history)
# - zsh loads the user's real .zprofile/.zshrc normally (no wrapper recursion)
#
# We restore ZDOTDIR from (in priority order):
# - GHOSTTY_ZSH_ZDOTDIR (set by GhosttyKit when it overwrote ZDOTDIR)
# - VMUX_ZSH_ZDOTDIR (set by vmux when it overwrote a user-provided ZDOTDIR)
# - unset (zsh treats unset ZDOTDIR as $HOME)

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${VMUX_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$VMUX_ZSH_ZDOTDIR"
    builtin unset VMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

{
    # zsh treats unset ZDOTDIR as if it were HOME. We do the same.
    builtin typeset _vmux_file="${ZDOTDIR-$HOME}/.zshenv"
    [[ ! -r "$_vmux_file" ]] || builtin source -- "$_vmux_file"
} always {
    if [[ -o interactive ]]; then
        # We overwrote GhosttyKit's injected ZDOTDIR, so manually load Ghostty's
        # zsh integration if available.
        #
        # We can't rely on GHOSTTY_ZSH_ZDOTDIR here because Ghostty's own zsh
        # bootstrap unsets it before chaining into this vmux wrapper.
        if [[ "${VMUX_LOAD_GHOSTTY_ZSH_INTEGRATION:-0}" == "1" ]]; then
            if [[ -n "${VMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
                builtin typeset _vmux_ghostty="$VMUX_SHELL_INTEGRATION_DIR/ghostty-integration.zsh"
            fi
            if [[ ! -r "${_vmux_ghostty:-}" && -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
                builtin typeset _vmux_ghostty="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
            fi
            [[ -r "$_vmux_ghostty" ]] && builtin source -- "$_vmux_ghostty"
        fi

        # Load vmux integration (unless disabled)
        if [[ "${VMUX_SHELL_INTEGRATION:-1}" != "0" && -n "${VMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
            builtin typeset _vmux_integ="$VMUX_SHELL_INTEGRATION_DIR/vmux-zsh-integration.zsh"
            [[ -r "$_vmux_integ" ]] && builtin source -- "$_vmux_integ"
        fi
    fi

    builtin unset _vmux_file _vmux_ghostty _vmux_integ
}
