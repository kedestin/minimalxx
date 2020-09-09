# Global settings
MNML_OK_COLOR="${MNML_OK_COLOR:-2}"
MNML_ERR_COLOR="${MNML_ERR_COLOR:-1}"

MNML_USER_CHAR="${MNML_USER_CHAR:-λ}"
MNML_INSERT_CHAR="${MNML_INSERT_CHAR:-›}"
MNML_NORMAL_CHAR="${MNML_NORMAL_CHAR:-·}"
MNML_ELLIPSIS_CHAR="${MNML_ELLIPSIS_CHAR:-..}"
MNML_BGJOB_MODE=${MNML_BGJOB_MODE:-4}

[ "${+MNML_PROMPT}" -eq 0 ] && MNML_PROMPT=(mnml_ssh mnml_pyenv mnml_status mnml_keymap)
[ "${+MNML_RPROMPT}" -eq 0 ] && MNML_RPROMPT=('mnml_cwd 2 0' mnml_git)

# Components
function mnml_status {
    local okc="$MNML_OK_COLOR"
    local errc="$MNML_ERR_COLOR"
    local uchar="$MNML_USER_CHAR"


    local colorMode="\e[%1(j.$MNML_BGJOB_MODE.0);3%(?.$okc.$errc)m"
    printf '%b' "%{$colorMode%}%(!.#.$uchar)%{\e[0m%}"
}

function mnml_keymap {
    local kmstat="$MNML_INSERT_CHAR"
    [ "$KEYMAP" = 'vicmd' ] && kmstat="$MNML_NORMAL_CHAR"
    printf '%b' "$kmstat"
}

function mnml_cwd {
    local echar="$MNML_ELLIPSIS_CHAR"
    local segments="${1:-2}"
    local seg_len="${2:-0}"

    local _w="%{\e[0m%}"
    local _g="%{\e[38;5;244m%}"

    if [ "$segments" -le 0 ]; then
        segments=0
    fi
    if [ "$seg_len" -gt 0 ] && [ "$seg_len" -lt 4 ]; then
        seg_len=4
    fi
    local seg_hlen=$((seg_len / 2 - 1))

    local cwd="%${segments}~"
    cwd="${(%)cwd}"
    cwd=("${(@s:/:)cwd}")

    local pi=""
    for i in {1..${#cwd}}; do
        pi="$cwd[$i]"
        if [ "$seg_len" -gt 0 ] && [ "${#pi}" -gt "$seg_len" ]; then
            cwd[$i]="${pi:0:$seg_hlen}$_w$echar$_g${pi: -$seg_hlen}"
        fi
    done

    printf '%b' "$_g${(j:/:)cwd//\//$_w/$_g}$_w"
}

function mnml_git {
    local statc="%{\e[0;3${MNML_OK_COLOR}m%}" # assume clean
    local bname="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"

    if [ -n "$bname" ]; then
        # if [ -n "$(git status --porcelain 2> /dev/null)" ]; then
        #     statc="%{\e[0;3${MNML_ERR_COLOR}m%}"
        # fi
        printf '%b' "$statc$bname%{\e[0m%}"
    fi
}


# function mnml_ssh {
#     if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
#         printf '%b' "$(hostname -s)"
#     fi
# }
function mnml_ssh {
    local _w="%{\e[0m%}"
    local _g="%{\e[38;5;244m%}"
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        printf '%b' "$_g$USER@$(hostname -s)$_w"
    fi
}

function mnml_pyenv {
    if [ -n "$VIRTUAL_ENV" ]; then
        _venv="$(basename $VIRTUAL_ENV)"
        printf '%b' "${_venv%%.*}"
    fi
}

# Wrappers & utils
# join outpus of components
function _mnml_expand {
    local -a arr
    arr=()
    local cmd_out=""
    local cmd
    for cmd in ${(P)1}; do
        cmd_out="$(eval "$cmd")"
        if [ -n "$cmd_out" ]; then
            arr+="$cmd_out"
        fi
    done

    printf '%b' "${(j: :)arr}"
}


# redraw prompt on keymap select
function _mnml_zle-keymap-select {
    zle reset-prompt
}


# properly bind widgets
# see: https://github.com/zsh-users/zsh-syntax-highlighting/blob/1f1e629290773bd6f9673f364303219d6da11129/zsh-syntax-highlighting.zsh#L292-L356
function _mnml_bind_widgets() {
    zmodload zsh/zleparameter

    local -a to_bind
    to_bind=(zle-keymap-select)

    typeset -F SECONDS
    local zle_wprefix=s$SECONDS-r$RANDOM

    local cur_widget
    for cur_widget in $to_bind; do
        case "${widgets[$cur_widget]:-""}" in
            user:_mnml_*);;
            user:*)
                zle -N $zle_wprefix-$cur_widget ${widgets[$cur_widget]#*:}
                eval "_mnml_ww_${(q)zle_wprefix}-${(q)cur_widget}() { _mnml_${(q)cur_widget}; zle ${(q)zle_wprefix}-${(q)cur_widget} }"
                zle -N $cur_widget _mnml_ww_$zle_wprefix-$cur_widget
                ;;
            *)
                zle -N $cur_widget _mnml_$cur_widget
                ;;
        esac
    done
}

# Setup
autoload -U colors && colors
setopt prompt_subst

PROMPT='$(_mnml_expand MNML_PROMPT) '
RPROMPT='$(_mnml_expand MNML_RPROMPT)'

_mnml_bind_widgets

# Disable default venv
export VIRTUAL_ENV_DISABLE_PROMPT=1