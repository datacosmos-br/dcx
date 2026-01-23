#compdef dcx

# Zsh completion for dcx (dc-scripts CLI)
# Install: copy to ~/.zsh/completions/ or add to fpath

_dcx() {
    local -a commands plugin_cmds config_cmds

    commands=(
        'version:Show version information'
        'update:Check for and install updates'
        'plugin:Manage plugins'
        'config:Manage configuration'
        'help:Show help message'
    )

    plugin_cmds=(
        'list:List installed plugins'
        'install:Install plugin from GitHub'
        'remove:Remove installed plugin'
        'update:Update plugin(s)'
        'info:Show plugin details'
        'load:Load a plugin'
        'help:Show plugin help'
    )

    config_cmds=(
        'get:Get config value'
        'set:Set config value'
        'show:Show merged config'
        'paths:Show config search paths'
        'init:Create initial config'
        'edit:Edit config file'
        'help:Show config help'
    )

    _arguments -C \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            _describe -t commands 'dcx command' commands
            ;;
        args)
            case $words[1] in
                plugin)
                    if (( CURRENT == 2 )); then
                        _describe -t plugin_cmds 'plugin command' plugin_cmds
                    else
                        case $words[2] in
                            install)
                                # Suggest known repos
                                _values 'repository' \
                                    'datacosmos-br/dc-scripts-oracle[Oracle Database automation]'
                                ;;
                            remove|info|load|update)
                                # List installed plugins
                                local -a plugins
                                if (( $+commands[dcx] )); then
                                    plugins=(${(f)"$(dcx plugin list simple 2>/dev/null | sed 's/^\[.\] //')"})
                                    _values 'plugin' $plugins
                                fi
                                ;;
                        esac
                    fi
                    ;;
                config)
                    if (( CURRENT == 2 )); then
                        _describe -t config_cmds 'config command' config_cmds
                    else
                        case $words[2] in
                            get|set)
                                local -a keys
                                keys=(
                                    'log.level:Log level (debug, info, warn, error)'
                                    'log.format:Log format (text, json)'
                                    'log.color:Color mode (auto, always, never)'
                                    'parallel.max_jobs:Max parallel jobs'
                                    'update.auto_check:Auto-check for updates'
                                )
                                _describe -t keys 'config key' keys
                                ;;
                            edit|init)
                                _files
                                ;;
                        esac
                    fi
                    ;;
                update)
                    # Optional version argument
                    _message 'version (optional)'
                    ;;
            esac
            ;;
    esac
}

_dcx "$@"
