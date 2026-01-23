# Bash completion for dcx (dc-scripts CLI)
# Install: source this file or copy to /etc/bash_completion.d/

_dcx_completions() {
    local cur prev words cword
    _init_completion || return

    # Main commands
    local commands="version update plugin config help"

    # Subcommands
    local plugin_cmds="list install remove update info load help"
    local config_cmds="get set show paths init edit help"

    case "${prev}" in
        dcx)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return
            ;;
        plugin)
            COMPREPLY=($(compgen -W "${plugin_cmds}" -- "${cur}"))
            return
            ;;
        config)
            COMPREPLY=($(compgen -W "${config_cmds}" -- "${cur}"))
            return
            ;;
        install)
            # Suggest some known plugin repos
            local repos="datacosmos-br/dc-scripts-oracle"
            COMPREPLY=($(compgen -W "${repos}" -- "${cur}"))
            return
            ;;
        remove|info|load|update)
            # Try to list installed plugins
            if command -v dcx &>/dev/null; then
                local plugins
                plugins=$(dcx plugin list simple 2>/dev/null | sed 's/^\[.\] //')
                COMPREPLY=($(compgen -W "${plugins}" -- "${cur}"))
            fi
            return
            ;;
        get|set)
            # Common config keys
            local keys="log.level log.format log.color parallel.max_jobs update.auto_check"
            COMPREPLY=($(compgen -W "${keys}" -- "${cur}"))
            return
            ;;
    esac

    # Default to commands
    if [[ ${cword} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
    fi
}

complete -F _dcx_completions dcx
