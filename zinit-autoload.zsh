# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# Copyright (c) 2016-2020 Sebastian Gniazdowski and contributors

builtin source "${ZINIT[BIN_DIR]}/zinit-side.zsh"

ZINIT[EXTENDED_GLOB]=""

#
# Backend, low level functions
#

# FUNCTION: .zinit-unregister-plugin [[[
# Removes the plugin from ZINIT_REGISTERED_PLUGINS array and from the
# zsh_loaded_plugins array (managed according to the plugin standard)
.zinit-unregister-plugin() {
    .zinit-any-to-user-plugin "$1" "$2"
    local uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}" \
        teleid="$3"

    # If not found, the index will be length+1
    ZINIT_REGISTERED_PLUGINS[${ZINIT_REGISTERED_PLUGINS[(i)$uspl2]}]=()
    # Support Zsh plugin standard
    zsh_loaded_plugins[${zsh_loaded_plugins[(i)$teleid]}]=()
    ZINIT_REGISTERED_STATES[$uspl2]="0"
} # ]]]
# FUNCTION: .zinit-diff-functions-compute [[[
# Computes FUNCTIONS that holds new functions added by plugin.
# Uses data gathered earlier by .zinit-diff-functions().
#
# $1 - user/plugin
.zinit-diff-functions-compute() {
    local uspl2="$1"

    # Cannot run diff if *_BEFORE or *_AFTER variable is not set
    # Following is paranoid for *_BEFORE and *_AFTER being only spaces

    builtin setopt localoptions extendedglob nokshglob noksharrays
    [[ "${ZINIT[FUNCTIONS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZINIT[FUNCTIONS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1

    typeset -A func
    local i

    # This includes new functions. Quoting is kept (i.e. no i=${(Q)i})
    for i in "${(z)ZINIT[FUNCTIONS_AFTER__$uspl2]}"; do
        func[$i]=1
    done

    # Remove duplicated entries, i.e. existing before. Quoting is kept
    for i in "${(z)ZINIT[FUNCTIONS_BEFORE__$uspl2]}"; do
        # if would do unset, then: func[opp+a\[]: invalid parameter name
        func[$i]=0
    done

    # Store the functions, associating them with plugin ($uspl2)
    ZINIT[FUNCTIONS__$uspl2]=""
    for i in "${(onk)func[@]}"; do
        [[ "${func[$i]}" = "1" ]] && ZINIT[FUNCTIONS__$uspl2]+="$i "
    done

    return 0
} # ]]]
# FUNCTION: .zinit-diff-options-compute [[[
# Computes OPTIONS that holds options changed by plugin.
# Uses data gathered earlier by .zinit-diff-options().
#
# $1 - user/plugin
.zinit-diff-options-compute() {
    local uspl2="$1"

    # Cannot run diff if *_BEFORE or *_AFTER variable is not set
    # Following is paranoid for *_BEFORE and *_AFTER being only spaces
    builtin setopt localoptions extendedglob nokshglob noksharrays
    [[ "${ZINIT[OPTIONS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZINIT[OPTIONS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1

    typeset -A opts_before opts_after opts
    opts_before=( "${(z)ZINIT[OPTIONS_BEFORE__$uspl2]}" )
    opts_after=( "${(z)ZINIT[OPTIONS_AFTER__$uspl2]}" )
    opts=( )

    # Iterate through first array (keys the same
    # on both of them though) and test for a change
    local key
    for key in "${(k)opts_before[@]}"; do
        if [[ "${opts_before[$key]}" != "${opts_after[$key]}" ]]; then
            opts[$key]="${opts_before[$key]}"
        fi
    done

    # Serialize for reporting
    local IFS=" "
    ZINIT[OPTIONS__$uspl2]="${(kv)opts[@]}"
    return 0
} # ]]]
# FUNCTION: .zinit-diff-env-compute [[[
# Computes ZINIT_PATH, ZINIT_FPATH that hold (f)path components
# added by plugin. Uses data gathered earlier by .zinit-diff-env().
#
# $1 - user/plugin
.zinit-diff-env-compute() {
    local uspl2="$1"
    typeset -a tmp

    # Cannot run diff if *_BEFORE or *_AFTER variable is not set
    # Following is paranoid for *_BEFORE and *_AFTER being only spaces
    builtin setopt localoptions extendedglob nokshglob noksharrays
    [[ "${ZINIT[PATH_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZINIT[PATH_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
    [[ "${ZINIT[FPATH_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZINIT[FPATH_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1

    typeset -A path_state fpath_state
    local i

    #
    # PATH processing
    #

    # This includes new path elements
    for i in "${(z)ZINIT[PATH_AFTER__$uspl2]}"; do
        path_state[${(Q)i}]=1
    done

    # Remove duplicated entries, i.e. existing before
    for i in "${(z)ZINIT[PATH_BEFORE__$uspl2]}"; do
        unset "path_state[$i]"
    done

    # Store the path elements, associating them with plugin ($uspl2)
    ZINIT[PATH__$uspl2]=""
    for i in "${(onk)path_state[@]}"; do
        ZINIT[PATH__$uspl2]+="${(q)i} "
    done

    #
    # FPATH processing
    #

    # This includes new path elements
    for i in "${(z)ZINIT[FPATH_AFTER__$uspl2]}"; do
        fpath_state[${(Q)i}]=1
    done

    # Remove duplicated entries, i.e. existing before
    for i in "${(z)ZINIT[FPATH_BEFORE__$uspl2]}"; do
        unset "fpath_state[$i]"
    done

    # Store the path elements, associating them with plugin ($uspl2)
    ZINIT[FPATH__$uspl2]=""
    for i in "${(onk)fpath_state[@]}"; do
        ZINIT[FPATH__$uspl2]+="${(q)i} "
    done

    return 0
} # ]]]
# FUNCTION: .zinit-diff-parameter-compute [[[
# Computes ZINIT_PARAMETERS_PRE, ZINIT_PARAMETERS_POST that hold
# parameters created or changed (their type) by plugin. Uses
# data gathered earlier by .zinit-diff-parameter().
#
# $1 - user/plugin
.zinit-diff-parameter-compute() {
    local uspl2="$1"
    typeset -a tmp

    # Cannot run diff if *_BEFORE or *_AFTER variable is not set
    # Following is paranoid for *_BEFORE and *_AFTER being only spaces
    builtin setopt localoptions extendedglob nokshglob noksharrays
    [[ "${ZINIT[PARAMETERS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZINIT[PARAMETERS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1

    # Un-concatenated parameters from moment of diff start and of diff end
    typeset -A params_before params_after
    params_before=( "${(z)ZINIT[PARAMETERS_BEFORE__$uspl2]}" )
    params_after=( "${(z)ZINIT[PARAMETERS_AFTER__$uspl2]}" )

    # The parameters that changed, with save of what
    # parameter was when diff started or when diff ended
    typeset -A params_pre params_post
    params_pre=( )
    params_post=( )

    # Iterate through all existing keys, before or after diff,
    # i.e. after all variables that were somehow live across
    # the diffing process
    local key
    typeset -aU keys
    keys=( "${(k)params_after[@]}" );
    keys=( "${keys[@]}" "${(k)params_before[@]}" );
    for key in "${keys[@]}"; do
        key="${(Q)key}"
        [[ "${params_after[$key]}" = *local* ]] && continue
        if [[ "${params_after[$key]}" != "${params_before[$key]}" ]]; then
            # Empty for a new param, a type otherwise
            [[ -z "${params_before[$key]}" ]] && params_before[$key]="\"\""
            params_pre[$key]="${params_before[$key]}"

            # Current type, can also be empty, when plugin
            # unsets a parameter
            [[ -z "${params_after[$key]}" ]] && params_after[$key]="\"\""
            params_post[$key]="${params_after[$key]}"
        fi
    done

    # Serialize for reporting
    ZINIT[PARAMETERS_PRE__$uspl2]="${(j: :)${(qkv)params_pre[@]}}"
    ZINIT[PARAMETERS_POST__$uspl2]="${(j: :)${(qkv)params_post[@]}}"

    return 0
} # ]]]
# FUNCTION: .zinit-any-to-uspl2 [[[
# Converts given plugin-spec to format that's used in keys for hash tables.
# So basically, creates string "user/plugin" (this format is called: uspl2).
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zinit-any-to-uspl2() {
    .zinit-any-to-user-plugin "$1" "$2"
    [[ "${reply[-2]}" = "%" ]] && REPLY="${reply[-2]}${reply[-1]}" || REPLY="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]//---//}"
} # ]]]
# FUNCTION: .zinit-save-set-extendedglob [[[
# Enables extendedglob-option first saving if it was already
# enabled, for restoration of this state later.
.zinit-save-set-extendedglob() {
    [[ -o "extendedglob" ]] && ZINIT[EXTENDED_GLOB]="1" || ZINIT[EXTENDED_GLOB]="0"
    builtin setopt extendedglob
} # ]]]
# FUNCTION: .zinit-restore-extendedglob [[[
# Restores extendedglob-option from state saved earlier.
.zinit-restore-extendedglob() {
    [[ "${ZINIT[EXTENDED_GLOB]}" = "0" ]] && builtin unsetopt extendedglob || builtin setopt extendedglob
} # ]]]
# FUNCTION: .zinit-prepare-readlink [[[
# Prepares readlink command, used for establishing completion's owner.
#
# $REPLY = ":" or "readlink"
.zinit-prepare-readlink() {
    REPLY=":"
    if type readlink 2>/dev/null 1>&2; then
        REPLY="readlink"
    fi
} # ]]]
# FUNCTION: .zinit-clear-report-for [[[
# Clears all report data for given user/plugin. This is
# done by resetting all related global ZINIT_* hashes.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zinit-clear-report-for() {
    .zinit-any-to-uspl2 "$1" "$2"

    # Shadowing
    ZINIT_REPORTS[$REPLY]=""
    ZINIT[BINDKEYS__$REPLY]=""
    ZINIT[ZSTYLES__$REPLY]=""
    ZINIT[ALIASES__$REPLY]=""
    ZINIT[WIDGETS_SAVED__$REPLY]=""
    ZINIT[WIDGETS_DELETE__$REPLY]=""

    # Function diffing
    ZINIT[FUNCTIONS__$REPLY]=""
    ZINIT[FUNCTIONS_BEFORE__$REPLY]=""
    ZINIT[FUNCTIONS_AFTER__$REPLY]=""

    # Option diffing
    ZINIT[OPTIONS__$REPLY]=""
    ZINIT[OPTIONS_BEFORE__$REPLY]=""
    ZINIT[OPTIONS_AFTER__$REPLY]=""

    # Environment diffing
    ZINIT[PATH__$REPLY]=""
    ZINIT[PATH_BEFORE__$REPLY]=""
    ZINIT[PATH_AFTER__$REPLY]=""
    ZINIT[FPATH__$REPLY]=""
    ZINIT[FPATH_BEFORE__$REPLY]=""
    ZINIT[FPATH_AFTER__$REPLY]=""

    # Parameter diffing
    ZINIT[PARAMETERS_PRE__$REPLY]=""
    ZINIT[PARAMETERS_POST__$REPLY]=""
    ZINIT[PARAMETERS_BEFORE__$REPLY]=""
    ZINIT[PARAMETERS_AFTER__$REPLY]=""
} # ]]]
# FUNCTION: .zinit-exists-message [[[
# Checks if plugin is loaded. Testable. Also outputs error
# message if plugin is not loaded.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zinit-exists-message() {
    .zinit-any-to-uspl2 "$1" "$2"
    if [[ -z "${ZINIT_REGISTERED_PLUGINS[(r)$REPLY]}" ]]; then
        .zinit-any-colorify-as-uspl2 "$1" "$2"
        print "${ZINIT[col-error]}No such plugin${ZINIT[col-rst]} $REPLY"
        return 1
    fi
    return 0
} # ]]]
# FUNCTION: .zinit-at-eval [[[
.zinit-at-eval() {
    local atclone="$2" atpull="$1"
    integer retval
    @zinit-substitute atclone atpull
    [[ $atpull = "%atclone" ]] && { eval "$atclone"; retval=$?; } || { eval "$atpull"; retval=$?; }
    return $retval
}
# ]]]

#
# Format functions
#

# FUNCTION: .zinit-format-functions [[[
# Creates a one or two columns text with functions created
# by given plugin.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zinit-format-functions() {
    local uspl2="$1"

    typeset -a func
    func=( "${(z)ZINIT[FUNCTIONS__$uspl2]}" )

    # Get length of longest left-right string pair,
    # and length of longest left string
    integer longest=0 longest_left=0 cur_left_len=0 count=1
    local f
    for f in "${(on)func[@]}"; do
        [[ -z "${#f}" ]] && continue
        f="${(Q)f}"

        # Compute for elements in left column,
        # ones that will be paded with spaces
        if (( count ++ % 2 != 0 )); then
            [[ "${#f}" -gt "$longest_left" ]] && longest_left="${#f}"
            cur_left_len="${#f}"
        else
            cur_left_len+="${#f}"
            cur_left_len+=1 # For separating space
            [[ "$cur_left_len" -gt "$longest" ]] && longest="$cur_left_len"
        fi
    done

    # Output in one or two columns
    local answer=""
    count=1
    for f in "${(on)func[@]}"; do
        [[ -z "$f" ]] && continue
        f="${(Q)f}"

        if (( COLUMNS >= longest )); then
            if (( count ++ % 2 != 0 )); then
                answer+="${(r:longest_left+1:: :)f}"
            else
                answer+="$f"$'\n'
            fi
        else
            answer+="$f"$'\n'
        fi
    done
    REPLY="$answer"
    # == 0 is: next element would have newline (postfix addition in "count ++")
    (( COLUMNS >= longest && count % 2 == 0 )) && REPLY="$REPLY"$'\n'
} # ]]]
# FUNCTION: .zinit-format-options [[[
# Creates one-column text about options that changed when
# plugin "$1" was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zinit-format-options() {
    local uspl2="$1"

    REPLY=""

    # Paranoid, don't want bad key/value pair error
    integer empty=0
    .zinit-save-set-extendedglob
    [[ "${ZINIT[OPTIONS__$uspl2]}" != *[$'! \t']* ]] && empty=1
    .zinit-restore-extendedglob
    (( empty )) && return 0

    typeset -A opts
    opts=( "${(z)ZINIT[OPTIONS__$uspl2]}" )

    # Get length of longest option
    integer longest=0
    local k
    for k in "${(kon)opts[@]}"; do
        [[ "${#k}" -gt "$longest" ]] && longest="${#k}"
    done

    # Output in one column
    local txt
    for k in "${(kon)opts[@]}"; do
        [[ "${opts[$k]}" = "on" ]] && txt="was unset" || txt="was set"
        REPLY+="${(r:longest+1:: :)k}$txt"$'\n'
    done
} # ]]]
# FUNCTION: .zinit-format-env [[[
# Creates one-column text about FPATH or PATH elements
# added when given plugin was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
# $2 - if 1, then examine PATH, if 2, then examine FPATH
.zinit-format-env() {
    local uspl2="$1" which="$2"

    # Format PATH?
    if [[ "$which" = "1" ]]; then
        typeset -a elem
        elem=( "${(z@)ZINIT[PATH__$uspl2]}" )
    elif [[ "$which" = "2" ]]; then
        typeset -a elem
        elem=( "${(z@)ZINIT[FPATH__$uspl2]}" )
    fi

    # Enumerate elements added
    local answer="" e
    for e in "${elem[@]}"; do
        [[ -z "$e" ]] && continue
        e="${(Q)e}"
        answer+="$e"$'\n'
    done

    [[ -n "$answer" ]] && REPLY="$answer"
} # ]]]
# FUNCTION: .zinit-format-parameter [[[
# Creates one column text that lists global parameters that
# changed when the given plugin was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zinit-format-parameter() {
    local uspl2="$1" infoc="${ZINIT[col-info]}" k

    builtin setopt localoptions extendedglob nokshglob noksharrays
    REPLY=""
    [[ "${ZINIT[PARAMETERS_PRE__$uspl2]}" != *[$'! \t']* || "${ZINIT[PARAMETERS_POST__$uspl2]}" != *[$'! \t']* ]] && return 0

    typeset -A elem_pre elem_post
    elem_pre=( "${(z)ZINIT[PARAMETERS_PRE__$uspl2]}" )
    elem_post=( "${(z)ZINIT[PARAMETERS_POST__$uspl2]}" )

    # Find longest key and longest value
    integer longest=0 vlongest1=0 vlongest2=0
    local v1 v2
    for k in "${(k)elem_post[@]}"; do
        k="${(Q)k}"
        [[ "${#k}" -gt "$longest" ]] && longest="${#k}"

        v1="${(Q)elem_pre[$k]}"
        v2="${(Q)elem_post[$k]}"
        [[ "${#v1}" -gt "$vlongest1" ]] && vlongest1="${#v1}"
        [[ "${#v2}" -gt "$vlongest2" ]] && vlongest2="${#v2}"
    done

    # Enumerate parameters that changed. A key
    # always exists in both of the arrays
    local answer="" k
    for k in "${(k)elem_post[@]}"; do
        v1="${(Q)elem_pre[$k]}"
        v2="${(Q)elem_post[$k]}"
        k="${(Q)k}"

        k="${(r:longest+1:: :)k}"
        v1="${(l:vlongest1+1:: :)v1}"
        v2="${(r:vlongest2+1:: :)v2}"
        answer+="$k ${infoc}[$v1 -> $v2]${ZINIT[col-rst]}"$'\n'
    done

    [[ -n "$answer" ]] && REPLY="$answer"

    return 0
} # ]]]

#
# Completion functions
#

# FUNCTION: .zinit-get-completion-owner [[[
# Returns "user---plugin" string (uspl1 format) of plugin that
# owns given completion.
#
# Both :A and readlink will be used, then readlink's output if
# results differ. Readlink might not be available.
#
# :A will read the link "twice" and give the final repository
# directory, possibly without username in the uspl format;
# readlink will read the link "once"
#
# $1 - absolute path to completion file (in COMPLETIONS_DIR)
# $2 - readlink command (":" or "readlink")
.zinit-get-completion-owner() {
    setopt localoptions extendedglob nokshglob noksharrays noshwordsplit
    local cpath="$1"
    local readlink_cmd="$2"
    local in_plugin_path tmp

    # Try to go not too deep into resolving the symlink,
    # to have the name as it is in .zinit/plugins
    # :A goes deep, descends fully to origin directory
    # Readlink just reads what symlink points to
    in_plugin_path="${cpath:A}"
    tmp=$( "$readlink_cmd" "$cpath" )
    # This in effect works as: "if different, then readlink"
    [[ -n "$tmp" ]] && in_plugin_path="$tmp"

    if [[ "$in_plugin_path" != "$cpath" ]]; then
        # Get the user---plugin part of path
        while [[ "$in_plugin_path" != ${ZINIT[PLUGINS_DIR]}/[^/]## && "$in_plugin_path" != "/" ]]; do
            in_plugin_path="${in_plugin_path:h}"
        done
        in_plugin_path="${in_plugin_path:t}"

        if [[ -z "$in_plugin_path" ]]; then
            in_plugin_path="${tmp:h}"
        fi
    else
        # readlink and :A have nothing
        in_plugin_path="[unknown]"
    fi

    REPLY="$in_plugin_path"
} # ]]]
# FUNCTION: .zinit-get-completion-owner-uspl2col [[[
# For shortening of code - returns colorized plugin name
# that owns given completion.
#
# $1 - absolute path to completion file (in COMPLETIONS_DIR)
# $2 - readlink command (":" or "readlink")
.zinit-get-completion-owner-uspl2col() {
    # "cpath" "readline_cmd"
    .zinit-get-completion-owner "$1" "$2"
    .zinit-any-colorify-as-uspl2 "$REPLY"
} # ]]]
# FUNCTION: .zinit-find-completions-of-plugin [[[
# Searches for completions owned by given plugin.
# Returns them in `reply' array.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-find-completions-of-plugin() {
    builtin setopt localoptions nullglob extendedglob nokshglob noksharrays
    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}" uspl
    [[ "$user" = "%" ]] && uspl="${user}${plugin}" || uspl="${reply[-2]}${reply[-2]:+---}${reply[-1]//\//---}"

    reply=( "${ZINIT[PLUGINS_DIR]}/$uspl"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*)(DN) )
} # ]]]
# FUNCTION: .zinit-check-comp-consistency [[[
# Zinit creates symlink for each installed completion.
# This function checks whether given completion (i.e.
# file like "_mkdir") is indeed a symlink. Backup file
# is a completion that is disabled - has the leading "_"
# removed.
#
# $1 - path to completion within plugin's directory
# $2 - path to backup file within plugin's directory
.zinit-check-comp-consistency() {
    local cfile="$1" bkpfile="$2"
    integer error="$3"

    # bkpfile must be a symlink
    if [[ -e "$bkpfile" && ! -L "$bkpfile" ]]; then
        print "${ZINIT[col-error]}Warning: completion's backup file \`${bkpfile:t}' isn't a symlink${ZINIT[col-rst]}"
        error=1
    fi

    # cfile must be a symlink
    if [[ -e "$cfile" && ! -L "$cfile" ]]; then
        print "${ZINIT[col-error]}Warning: completion file \`${cfile:t}' isn't a symlink${ZINIT[col-rst]}"
        error=1
    fi

    # Tell user that he can manually modify but should do it right
    (( error )) && print "${ZINIT[col-error]}Manual edit of ${ZINIT[COMPLETIONS_DIR]} occured?${ZINIT[col-rst]}"
} # ]]]
# FUNCTION: .zinit-check-which-completions-are-installed [[[
# For each argument that each should be a path to completion
# within a plugin's dir, it checks whether that completion
# is installed - returns 0 or 1 on corresponding positions
# in reply.
#
# $1, ... - path to completion within plugin's directory
.zinit-check-which-completions-are-installed() {
    local i cfile bkpfile
    reply=( )
    for i in "$@"; do
        cfile="${i:t}"
        bkpfile="${cfile#_}"

        if [[ -e "${ZINIT[COMPLETIONS_DIR]}"/"$cfile" || -e "${ZINIT[COMPLETIONS_DIR]}"/"$bkpfile" ]]; then
            reply+=( "1" )
        else
            reply+=( "0" )
        fi
    done
} # ]]]
# FUNCTION: .zinit-check-which-completions-are-enabled [[[
# For each argument that each should be a path to completion
# within a plugin's dir, it checks whether that completion
# is disabled - returns 0 or 1 on corresponding positions
# in reply.
#
# Uninstalled completions will be reported as "0"
# - i.e. disabled
#
# $1, ... - path to completion within plugin's directory
.zinit-check-which-completions-are-enabled() {
    local i cfile
    reply=( )
    for i in "$@"; do
        cfile="${i:t}"

        if [[ -e "${ZINIT[COMPLETIONS_DIR]}"/"$cfile" ]]; then
            reply+=( "1" )
        else
            reply+=( "0" )
        fi
    done
} # ]]]
# FUNCTION: .zinit-uninstall-completions [[[
# Removes all completions of given plugin from Zshell (i.e. from FPATH).
# The FPATH is typically `~/.zinit/completions/'.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-uninstall-completions() {
    builtin setopt localoptions nullglob extendedglob unset nokshglob noksharrays noshwordsplit

    typeset -a completions symlinked backup_comps
    local c cfile bkpfile
    integer action global_action=0

    .zinit-get-path "$1" "$2"
    [[ -e "$REPLY" ]] && {
        completions=( "$REPLY"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*)(DN) )
    } || {
        print "No completions found for \`$1${${1:#(%|/)*}:+${2:+/}}$2'"
        return 1
    }

    symlinked=( "${ZINIT[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc )
    backup_comps=( "${ZINIT[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )

    # Delete completions if they are really there, either
    # as completions (_fname) or backups (fname)
    for c in "${completions[@]}"; do
        action=0
        cfile="${c:t}"
        bkpfile="${cfile#_}"

        # Remove symlink to completion
        if [[ -n "${symlinked[(r)*/$cfile]}" ]]; then
            command rm -f "${ZINIT[COMPLETIONS_DIR]}/$cfile"
            action=1
        fi

        # Remove backup symlink (created by cdisable)
        if [[ -n "${backup_comps[(r)*/$bkpfile]}" ]]; then
            command rm -f "${ZINIT[COMPLETIONS_DIR]}/$bkpfile"
            action=1
        fi

        if (( action )); then
            print "${ZINIT[col-info]}Uninstalling completion \`$cfile'${ZINIT[col-rst]}"
            # Make compinit notice the change
            .zinit-forget-completion "$cfile"
            (( global_action ++ ))
        else
            print "${ZINIT[col-info]}Completion \`$cfile' not installed${ZINIT[col-rst]}"
        fi
    done

    if (( global_action > 0 )); then
        print "${ZINIT[col-info]}Uninstalled $global_action completions${ZINIT[col-rst]}"
    fi

    (( ${+functions[.zinit-forget-completion]} )) || builtin source ${ZINIT[BIN_DIR]}"/zinit-install.zsh"
    .zinit-compinit >/dev/null
} # ]]]

#
# User-exposed functions
#

# FUNCTION: .zinit-pager [[[
# BusyBox less lacks the -X and -i options, so it can use more
.zinit-pager() {
    setopt LOCAL_OPTIONS EQUALS
    if [[ ${${:-=less}:A:t} = busybox* ]] {
        more 2>/dev/null
        (( ${+commands[more]} ))
    } else {
        less -FRXi 2>/dev/null
        (( ${+commands[less]} ))
    }
    (( $? )) && cat
}
# ]]]

# FUNCTION: .zinit-self-update [[[
# Updates Zinit code (does a git pull).
#
# User-action entry point.
.zinit-self-update() {
    emulate -LR zsh
    setopt extendedglob typesetsilent warncreateglobal
    local nl=$'\n' escape=$'\x1b['
    local -a lines
    (   builtin cd -q "$ZINIT[BIN_DIR]" && \
        command git fetch --quiet && \
            lines=( ${(f)"$(command git log --color --date=short --pretty=format:'%Cgreen%cd %h %Creset%s %Cred%d%Creset || %b' ..FETCH_HEAD)"} )
        if (( ${#lines} > 0 )); then
            # Remove the (origin/master ...) segments, to expect only tags to appear
            lines=( "${(S)lines[@]//\(([,[:blank:]]#(origin|HEAD|master)[^a-zA-Z]##(HEAD|origin|master)[,[:blank:]]#)#\)/}" )
            # Remove " ||" if it ends the line (i.e. no additional text from the body)
            lines=( "${lines[@]/ \|\|[[:blank:]]#(#e)/}" )
            # If there's no ref-name, 2 consecutive spaces occur - fix this
            lines=( "${lines[@]/(#b)[[:space:]]#\|\|[[:space:]]#(*)(#e)/|| ${match[1]}}" )
            lines=( "${lines[@]/(#b)$escape([0-9]##)m[[:space:]]##${escape}m/$escape${match[1]}m${escape}m}" )
            # Replace what follows "|| ..." with the same thing but with no newlines,
            # and also only first 10 words (the (w)-flag enables word-indexing)
            lines=( "${lines[@]/(#b)[[:blank:]]#\|\|(*)(#e)/| ${${match[1]//$nl/ }[(w)1,(w)10]}}" )
            builtin print -rl -- "${lines[@]}" | .zinit-pager
        fi
        command git pull --no-stat
    )
    builtin print "Compiling Zinit (zcompile)..."
    command rm -f $ZINIT[BIN_DIR]/*.zwc(DN)
    zcompile $ZINIT[BIN_DIR]/zinit.zsh
    zcompile $ZINIT[BIN_DIR]/zinit-side.zsh
    zcompile $ZINIT[BIN_DIR]/zinit-install.zsh
    zcompile $ZINIT[BIN_DIR]/zinit-autoload.zsh
    zcompile $ZINIT[BIN_DIR]/git-process-output.zsh
    # Load for the current session
    builtin print "Reloading Zinit for the current session..."
    source $ZINIT[BIN_DIR]/zinit.zsh
    source $ZINIT[BIN_DIR]/zinit-side.zsh
    source $ZINIT[BIN_DIR]/zinit-install.zsh
    source $ZINIT[BIN_DIR]/zinit-autoload.zsh
    # Read and remember the new modification timestamps
    local file
    for file ( "" -side -install -autoload ) {
        .zinit-get-mtime-into "${ZINIT[BIN_DIR]}/zinit$file.zsh" "ZINIT[mtime$file]"
    }
} # ]]]
# FUNCTION: .zinit-show-registered-plugins [[[
# Lists loaded plugins (subcommands list, lodaded).
#
# User-action entry point.
.zinit-show-registered-plugins() {
    emulate -LR zsh
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    typeset -a filtered
    local keyword="$1"

    keyword="${keyword## ##}"
    keyword="${keyword%% ##}"
    if [[ -n "$keyword" ]]; then
        print "Installed plugins matching ${ZINIT[col-info]}$keyword${ZINIT[col-rst]}:"
        filtered=( "${(M)ZINIT_REGISTERED_PLUGINS[@]:#*$keyword*}" )
    else
        filtered=( "${ZINIT_REGISTERED_PLUGINS[@]}" )
    fi

    local i
    for i in "${filtered[@]}"; do
        [[ "$i" = "_local/zinit" ]] && continue
        .zinit-any-colorify-as-uspl2 "$i"
        # Mark light loads
        [[ "${ZINIT_REGISTERED_STATES[$i]}" = "1" ]] && REPLY="$REPLY ${ZINIT[col-info]}*${ZINIT[col-rst]}"
        print -r -- "$REPLY"
    done
} # ]]]
# FUNCTION: .zinit-unload [[[
# 0. Call the Zsh Plugin's Standard *_plugin_unload function
# 0. Call the code provided by the Zsh Plugin's Standard @zsh-plugin-run-at-update
# 1. Delete bindkeys (...)
# 2. Delete Zstyles
# 3. Restore options
# 4. Remove aliases
# 5. Restore Zle state
# 6. Unfunction functions (created by plugin)
# 7. Clean-up FPATH and PATH
# 8. Delete created variables
# 9. Forget the plugin
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-unload() {
    .zinit-any-to-user-plugin "$1" "$2"
    local uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}" user="${reply[-2]}" plugin="${reply[-1]}" quiet="${${3:+1}:-0}"
    local k

    .zinit-any-colorify-as-uspl2 "$uspl2"
    (( quiet )) || print -r -- "${ZINIT[col-bar]}---${ZINIT[col-rst]} Unloading plugin: $REPLY ${ZINIT[col-bar]}---${ZINIT[col-rst]}"

    local __dir
    [[ "$user" = "%" ]] && __dir="$plugin" || __dir="${ZINIT[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}"

    # KSH_ARRAYS immunity
    integer correct=0
    [[ -o "KSH_ARRAYS" ]] && correct=1

    # Allow unload for debug user
    if [[ "$uspl2" != "_dtrace/_dtrace" ]]; then
        .zinit-exists-message "$1" "$2" || return 1
    fi

    .zinit-any-colorify-as-uspl2 "$1" "$2"
    local uspl2col="$REPLY"

    # Store report of the plugin in variable LASTREPORT
    typeset -g LASTREPORT
    LASTREPORT=`.zinit-show-report "$1" "$2"`

    #
    # Call the Zsh Plugin's Standard *_plugin_unload function
    #

    (( ${+functions[${plugin}_plugin_unload]} )) && ${plugin}_plugin_unload

    #
    # Call the code provided by the Zsh Plugin's Standard @zsh-plugin-run-at-update
    #

    local -a tmp
    local -A sice
    tmp=( "${(z@)ZINIT_SICE[$uspl2]}" )
    (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()

    if [[ -n ${sice[ps-on-unload]} ]]; then
        (( quiet )) || print -r "Running plugin's provided unload code: ${ZINIT[col-info]}${sice[ps-on-unload][1,50]}${sice[ps-on-unload][51]:+…}${ZINIT[col-rst]}"
        local __oldcd="$PWD"
        () { setopt localoptions noautopushd; builtin cd -q "$__dir"; }
        eval "${sice[ps-on-unload]}"
        () { setopt localoptions noautopushd; builtin cd -q "$__oldcd"; }
    fi

    #
    # 1. Delete done bindkeys
    #

    typeset -a string_widget
    string_widget=( "${(z)ZINIT[BINDKEYS__$uspl2]}" )
    local sw
    for sw in "${(Oa)string_widget[@]}"; do
        [[ -z "$sw" ]] && continue
        # Remove one level of quoting to split using (z)
        sw="${(Q)sw}"
        typeset -a sw_arr
        sw_arr=( "${(z)sw}" )

        # Remove one level of quoting to pass to bindkey
        local sw_arr1="${(Q)sw_arr[1-correct]}" # Keys
        local sw_arr2="${(Q)sw_arr[2-correct]}" # Widget
        local sw_arr3="${(Q)sw_arr[3-correct]}" # Optional previous-bound widget
        local sw_arr4="${(Q)sw_arr[4-correct]}" # Optional -M or -A or -N
        local sw_arr5="${(Q)sw_arr[5-correct]}" # Optional map name
        local sw_arr6="${(Q)sw_arr[6-correct]}" # Optional -R (not with -A, -N)

        if [[ "$sw_arr4" = "-M" && "$sw_arr6" != "-R" ]]; then
            if [[ -n "$sw_arr3" ]]; then
                () {
                    emulate -LR zsh -o extendedglob
                    (( quiet )) || print -r "Restoring bindkey ${${(q)sw_arr1}//(#m)\\[\^\?\]\[\)\(\'\"\}\{\`]/${MATCH#\\}} $sw_arr3 ${ZINIT[col-info]}in map ${ZINIT[col-rst]}$sw_arr5"
                }
                bindkey -M "$sw_arr5" "$sw_arr1" "$sw_arr3"
            else
                (( quiet )) || print -r "Deleting bindkey ${(q)sw_arr1} $sw_arr2 ${ZINIT[col-info]}in map ${ZINIT[col-rst]}$sw_arr5"
                bindkey -M "$sw_arr5" -r "$sw_arr1"
            fi
        elif [[ "$sw_arr4" = "-M" && "$sw_arr6" = "-R" ]]; then
            if [[ -n "$sw_arr3" ]]; then
                (( quiet )) || print -r "Restoring ${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey ${(q)sw_arr1} $sw_arr3 ${ZINIT[col-info]}in map ${ZINIT[col-rst]}$sw_arr5"
                bindkey -RM "$sw_arr5" "$sw_arr1" "$sw_arr3"
            else
                (( quiet )) || print -r "Deleting ${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey ${(q)sw_arr1} $sw_arr2 ${ZINIT[col-info]}in map ${ZINIT[col-rst]}$sw_arr5"
                bindkey -M "$sw_arr5" -Rr "$sw_arr1"
            fi
        elif [[ "$sw_arr4" != "-M" && "$sw_arr6" = "-R" ]]; then
            if [[ -n "$sw_arr3" ]]; then
                (( quiet )) || print -r "Restoring ${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey ${(q)sw_arr1} $sw_arr3"
                bindkey -R "$sw_arr1" "$sw_arr3"
            else
                (( quiet )) || print -r "Deleting ${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey ${(q)sw_arr1} $sw_arr2"
                bindkey -Rr "$sw_arr1"
            fi
        elif [[ "$sw_arr4" = "-A" ]]; then
            (( quiet )) || print -r "Linking backup-\`main' keymap \`$sw_arr5' back to \`main'"
            bindkey -A "$sw_arr5" "main"
        elif [[ "$sw_arr4" = "-N" ]]; then
            (( quiet )) || print -r "Deleting keymap \`$sw_arr5'"
            bindkey -D "$sw_arr5"
        else
            if [[ -n "$sw_arr3" ]]; then
                () {
                    emulate -LR zsh -o extendedglob
                    (( quiet )) || print -r "Restoring bindkey ${${(q)sw_arr1}//(#m)\\[\^\?\]\[\)\(\'\"\}\{\`]/${MATCH#\\}} $sw_arr3"
                }
                bindkey "$sw_arr1" "$sw_arr3"
            else
                (( quiet )) || print -r "Deleting bindkey ${(q)sw_arr1} $sw_arr2"
                bindkey -r "$sw_arr1"
            fi
        fi
    done

    #
    # 2. Delete created Zstyles
    #

    typeset -a pattern_style
    pattern_style=( "${(z)ZINIT[ZSTYLES__$uspl2]}" )
    local ps
    for ps in "${(Oa)pattern_style[@]}"; do
        [[ -z "$ps" ]] && continue
        # Remove one level of quoting to split using (z)
        ps="${(Q)ps}"
        typeset -a ps_arr
        ps_arr=( "${(z)ps}" )

        # Remove one level of quoting to pass to zstyle
        local ps_arr1="${(Q)ps_arr[1-correct]}"
        local ps_arr2="${(Q)ps_arr[2-correct]}"

        (( quiet )) || print "Deleting zstyle $ps_arr1 $ps_arr2"

        zstyle -d "$ps_arr1" "$ps_arr2"
    done

    #
    # 3. Restore changed options
    #

    # Paranoid, don't want bad key/value pair error
    .zinit-diff-options-compute "$uspl2"
    integer empty=0
    .zinit-save-set-extendedglob
    [[ "${ZINIT[OPTIONS__$uspl2]}" != *[$'! \t']* ]] && empty=1
    .zinit-restore-extendedglob

    if (( empty != 1 )); then
        typeset -A opts
        opts=( "${(z)ZINIT[OPTIONS__$uspl2]}" )
        for k in "${(kon)opts[@]}"; do
            # Internal options
            [[ "$k" = "physical" ]] && continue

            if [[ "${opts[$k]}" = "on" ]]; then
                (( quiet )) || print "Setting option $k"
                builtin setopt "$k"
            else
                (( quiet )) || print "Unsetting option $k"
                builtin unsetopt "$k"
            fi
        done
    fi

    #
    # 4. Delete aliases
    #

    typeset -a aname_avalue
    aname_avalue=( "${(z)ZINIT[ALIASES__$uspl2]}" )
    local nv
    for nv in "${(Oa)aname_avalue[@]}"; do
        [[ -z "$nv" ]] && continue
        # Remove one level of quoting to split using (z)
        nv="${(Q)nv}"
        typeset -a nv_arr
        nv_arr=( "${(z)nv}" )

        # Remove one level of quoting to pass to unalias
        local nv_arr1="${(Q)nv_arr[1-correct]}"
        local nv_arr2="${(Q)nv_arr[2-correct]}"
        local nv_arr3="${(Q)nv_arr[3-correct]}"

        if [[ "$nv_arr3" = "-s" ]]; then
            if [[ -n "$nv_arr2" ]]; then
                (( quiet )) || print "Restoring ${ZINIT[col-info]}suffix${ZINIT[col-rst]} alias ${nv_arr1}=${nv_arr2}"
                alias "$nv_arr1" &> /dev/null && unalias -s -- "$nv_arr1"
                alias -s -- "${nv_arr1}=${nv_arr2}"
            else
                (( quiet )) || alias "$nv_arr1" &> /dev/null && {
                    print "Removing ${ZINIT[col-info]}suffix${ZINIT[col-rst]} alias ${nv_arr1}"
                    unalias -s -- "$nv_arr1"
                }
            fi
        elif [[ "$nv_arr3" = "-g" ]]; then
            if [[ -n "$nv_arr2" ]]; then
                (( quiet )) || print "Restoring ${ZINIT[col-info]}global${ZINIT[col-rst]} alias ${nv_arr1}=${nv_arr2}"
                alias "$nv_arr1" &> /dev/null && unalias -g -- "$nv_arr1"
                alias -g -- "${nv_arr1}=${nv_arr2}"
            else
                (( quiet )) || alias "$nv_arr1" &> /dev/null && {
                    print "Removing ${ZINIT[col-info]}global${ZINIT[col-rst]} alias ${nv_arr1}"
                    unalias -- "${(q)nv_arr1}"
                }
            fi
        else
            if [[ -n "$nv_arr2" ]]; then
                (( quiet )) || print "Restoring alias ${nv_arr1}=${nv_arr2}"
                alias "$nv_arr1" &> /dev/null && unalias -- "$nv_arr1"
                alias -- "${nv_arr1}=${nv_arr2}"
            else
                (( quiet )) || alias "$nv_arr1" &> /dev/null && {
                    print "Removing alias ${nv_arr1}"
                    unalias -- "$nv_arr1"
                }
            fi
        fi
    done

    #
    # 5. Restore Zle state
    #

    local -a keys
    keys=( "${(@on)ZINIT[(I)TIME_<->_*]}" )
    integer keys_size=${#keys}
    () {
        setopt localoptions extendedglob noksharrays typesetsilent
        typeset -a restore_widgets skip_delete
        local wid
        restore_widgets=( "${(z)ZINIT[WIDGETS_SAVED__$uspl2]}" )
        for wid in "${(Oa)restore_widgets[@]}"; do
            [[ -z "$wid" ]] && continue
            wid="${(Q)wid}"
            typeset -a orig_saved
            orig_saved=( "${(z)wid}" )

            local tpe="${orig_saved[1]}"
            local orig_saved1="${(Q)orig_saved[2]}" # Original widget
            local comp_wid="${(Q)orig_saved[3]}"
            local orig_saved2="${(Q)orig_saved[4]}" # Saved target function
            local orig_saved3="${(Q)orig_saved[5]}" # Saved previous $widget's contents

            local found_time_key="${keys[(r)TIME_<->_${uspl2//\//---}]}" to_process_plugin
            integer found_time_idx=0 idx=0
            to_process_plugin=""
            [[ "$found_time_key" = (#b)TIME_(<->)_* ]] && found_time_idx="${match[1]}"
            if (( found_time_idx )); then # Must be true
                for (( idx = found_time_idx + 1; idx <= keys_size; ++ idx )); do
                    found_time_key="${keys[(r)TIME_${idx}_*]}"
                    local oth_uspl2=""
                    [[ "$found_time_key" = (#b)TIME_${idx}_(*) ]] && oth_uspl2="${match[1]//---//}"
                    local -a entry_splitted
                    entry_splitted=( "${(z@)ZINIT[WIDGETS_SAVED__$oth_uspl2]}" )
                    integer found_idx="${entry_splitted[(I)(-N|-C)\ $orig_saved1\\\ *]}"
                    local -a entry_splitted2
                    entry_splitted2=( "${(z@)ZINIT[BINDKEYS__$oth_uspl2]}" )
                    integer found_idx2="${entry_splitted2[(I)*\ $orig_saved1\ *]}"
                    if (( found_idx || found_idx2 ))
                    then
                        # Skip multiple loads of the same plugin
                        # TODO: Fully handle multiple plugin loads
                        if [[ "$oth_uspl2" != "$uspl2" ]]; then
                            to_process_plugin="$oth_uspl2"
                            break # Only the first one is needed
                        fi
                    fi
                done
                if [[ -n "$to_process_plugin" ]]; then
                    if (( !found_idx && !found_idx2 )); then
                        (( quiet )) || print "Problem (1) during handling of widget \`$orig_saved1' (contents: $orig_saved2)"
                        continue
                    fi
                    (( quiet )) || print "Chaining widget \`$orig_saved1' to plugin $oth_uspl2"
                    local -a oth_orig_saved
                    if (( found_idx )) {
                        oth_orig_saved=( "${(z)${(Q)entry_splitted[found_idx]}}" )
                        local oth_fun="${oth_orig_saved[4]}"
                        # oth_orig_saved[2]="${(q)orig_saved2}" # not do this, because
                                                        # we don't want to call other
                                                        # plugin's function at any moment
                        oth_orig_saved[5]="${(q)orig_saved3}" # chain up the widget
                        entry_splitted[found_idx]="${(q)${(j: :)oth_orig_saved}}"
                        ZINIT[WIDGETS_SAVED__$oth_uspl2]="${(j: :)entry_splitted}"
                    } else {
                        oth_orig_saved=( "${(z)${(Q)entry_splitted2[found_idx2]}}" )
                        local oth_fun="${widgets[${oth_orig_saved[3]}]#*:}"
                    }
                    integer idx="${functions[$orig_saved2][(i)(#b)([^[:space:]]#${orig_saved1}[^[:space:]]#)]}"
                    if (( idx <= ${#functions[$orig_saved2]} ))
                    then
                        local prefix_X="${match[1]#\{}"
                        [[ $prefix_X != \$* ]] && prefix_X="${prefix_X%\}}"
                        idx="${functions[$oth_fun][(i)(#b)([^[:space:]]#${orig_saved1}[^[:space:]]#)]}"
                        if (( idx <= ${#functions[$oth_fun]} )); then
                            match[1]="${match[1]#\{}"
                            [[ ${match[1]} != \$* ]] && match[1]="${match[1]%\}}"
                            eval "local oth_prefix_uspl2_X=\"${match[1]}\""
                            if [[ "${widgets[$prefix_X]}" = builtin ]]; then
                                (( quiet )) || print "Builtin-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
                                zle -A ".${prefix_X#.}" "$oth_prefix_uspl2_X"
                            elif [[ "${widgets[$prefix_X]}" = completion:* ]]; then
                                (( quiet )) || print "Chain*-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
                                zle -C "$oth_prefix_uspl2_X" "${(@)${(@s.:.)${orig_saved3#user:}}[2,3]}"
                            else
                                (( quiet )) || print "Chain-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
                                zle -N "$oth_prefix_uspl2_X" "${widgets[$prefix_X]#user:}"
                            fi
                        fi

                        # The alternate method
                        #skip_delete+=( "${match[1]}" )
                        #functions[$oth_fun]="${functions[$oth_fun]//[^\{[:space:]]#$orig_saved1/${match[1]}}"
                    fi
                else
                    (( quiet )) || print "Restoring Zle widget $orig_saved1"
                    if [[ "$orig_saved3" = builtin ]]; then
                        zle -A ".$orig_saved1" "$orig_saved1"
                    elif [[ "$orig_saved3" = completion:* ]]; then
                        zle -C "$orig_saved1" "${(@)${(@s.:.)${orig_saved3#user:}}[2,3]}"
                    else
                        zle -N "$orig_saved1" "${orig_saved3#user:}"
                    fi
                fi
            else
                (( quiet )) || print "Problem (2) during handling of widget \`$orig_saved1' (contents: $orig_saved2)"
            fi
        done
    }

    typeset -a delete_widgets
    delete_widgets=( "${(z)ZINIT[WIDGETS_DELETE__$uspl2]}" )
    local wid
    for wid in "${(Oa)delete_widgets[@]}"; do
        [[ -z "$wid" ]] && continue
        wid="${(Q)wid}"
        if [[ -n "${skip_delete[(r)$wid]}" ]]; then
            print "Would delete $wid"
            continue
        fi
        if [[ "${ZINIT_ZLE_HOOKS_LIST[$wid]}" = "1" ]]; then
            (( quiet )) || print "Removing Zle hook \`$wid'"
        else
            (( quiet )) || print "Removing Zle widget \`$wid'"
        fi
        zle -D "$wid"
    done

    #
    # 6. Unfunction
    #

    .zinit-diff-functions-compute "$uspl2"
    typeset -a func
    func=( "${(z)ZINIT[FUNCTIONS__$uspl2]}" )
    local f
    for f in "${(on)func[@]}"; do
        [[ -z "$f" ]] && continue
        f="${(Q)f}"
        (( quiet )) || print "Deleting function $f"
        (( ${+functions[$f]} )) && unfunction -- "$f"
        (( ${+precmd_functions} )) && precmd_functions=( ${precmd_functions[@]:#$f} )
        (( ${+preexec_functions} )) && preexec_functions=( ${preexec_functions[@]:#$f} )
        (( ${+chpwd_functions} )) && chpwd_functions=( ${chpwd_functions[@]:#$f} )
        (( ${+periodic_functions} )) && periodic_functions=( ${periodic_functions[@]:#$f} )
        (( ${+zshaddhistory_functions} )) && zshaddhistory_functions=( ${zshaddhistory_functions[@]:#$f} )
        (( ${+zshexit_functions} )) && zshexit_functions=( ${zshexit_functions[@]:#$f} )
    done

    #
    # 7. Clean up FPATH and PATH
    #

    .zinit-diff-env-compute "$uspl2"

    # Have to iterate over $path elements and
    # skip those that were added by the plugin
    typeset -a new elem p
    elem=( "${(z)ZINIT[PATH__$uspl2]}" )
    for p in "${path[@]}"; do
        [[ -z "${elem[(r)${(q)p}]}" ]] && { new+=( "$p" ); } || {
            (( quiet )) || print "Removing PATH element ${ZINIT[col-info]}$p${ZINIT[col-rst]}"
            [[ -d "$p" ]] || (( quiet )) || print "${ZINIT[col-error]}Warning:${ZINIT[col-rst]} it didn't exist on disk"
        }
    done
    path=( "${new[@]}" )

    # The same for $fpath
    elem=( "${(z)ZINIT[FPATH__$uspl2]}" )
    new=( )
    for p in "${fpath[@]}"; do
        [[ -z "${elem[(r)${(q)p}]}" ]] && { new+=( "$p" ); } || {
            (( quiet )) || print "Removing FPATH element ${ZINIT[col-info]}$p${ZINIT[col-rst]}"
            [[ -d "$p" ]] || (( quiet )) || print "${ZINIT[col-error]}Warning:${ZINIT[col-rst]} it didn't exist on disk"
        }
    done
    fpath=( "${new[@]}" )

    #
    # 8. Delete created variables
    #

    .zinit-diff-parameter-compute "$uspl2"
    empty=0
    .zinit-save-set-extendedglob
    [[ "${ZINIT[PARAMETERS_POST__$uspl2]}" != *[$'! \t']* ]] && empty=1
    .zinit-restore-extendedglob

    if (( empty != 1 )); then
        typeset -A elem_pre elem_post
        elem_pre=( "${(z)ZINIT[PARAMETERS_PRE__$uspl2]}" )
        elem_post=( "${(z)ZINIT[PARAMETERS_POST__$uspl2]}" )

        # Find variables created or modified
        local wl found
        local -a whitelist
        whitelist=( "${(@Q)${(z@)ZINIT[ENV-WHITELIST]}}" )
        for k in "${(k)elem_post[@]}"; do
            k="${(Q)k}"
            local v1="${(Q)elem_pre[$k]}"
            local v2="${(Q)elem_post[$k]}"

            # "" means a variable was deleted, not created/changed
            if [[ $v2 != '""' ]]; then
                # Don't unset readonly variables
                [[ ${(tP)k} == *-readonly(|-*) ]] && continue

                # Don't unset arrays managed by add-zsh-hook,
                # also ignore a few special parameters
                # TODO: remember and remove hooks
                case "$k" in
                    (chpwd_functions|precmd_functions|preexec_functions|periodic_functions|zshaddhistory_functions|zshexit_functions|zsh_directory_name_functions)
                        continue
                    (path|PATH|fpath|FPATH)
                        continue;
                        ;;
                esac

                # Don't unset redefined variables, only newly defined
                # "" means variable didn't exist before plugin load
                # (didn't have a type).
                # Do an exception for the prompt variables.
                if [[ $v1 = '""' || ( $k = (RPROMPT|RPS1|RPS2|PROMPT|PS1|PS2|PS3|PS4) && $v1 != $v2 ) ]]; then
                    found=0
                    for wl in "${whitelist[@]}"; do
                        if [[ "$k" = ${~wl} ]]; then
                            found=1
                            break
                        fi
                    done
                    if (( !found )); then
                        (( quiet )) || print "Unsetting variable $k"
                        # Checked that 4.3.17 does support "--"
                        # There cannot be parameter starting with
                        # "-" but let's defensively use "--" here
                        unset -- "$k"
                    else
                        print "Skipping unset of variable $k (whitelist)"
                    fi
                fi
            fi
        done
    fi

    #
    # 9. Forget the plugin
    #

    if [[ "$uspl2" = "_dtrace/_dtrace" ]]; then
        .zinit-clear-debug-report
        (( quiet )) || print "dtrace report saved to \$LASTREPORT"
    else
        (( quiet )) || print "Unregistering plugin $uspl2col"
        .zinit-unregister-plugin "$user" "$plugin" "${sice[teleid]}"
        zsh_loaded_plugins[${zsh_loaded_plugins[(i)$user${${user:#(%|/)*}:+/}$plugin]}]=()  # Support Zsh plugin standard
        .zinit-clear-report-for "$user" "$plugin"
        (( quiet )) || print "Plugin's report saved to \$LASTREPORT"
    fi

} # ]]]
# FUNCTION: .zinit-show-report [[[
# Displays report of the plugin given.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-show-report() {
    setopt localoptions extendedglob warncreateglobal typesetsilent noksharrays
    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}" uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}"

    # Allow debug report
    if [[ "$user/$plugin" != "_dtrace/_dtrace" ]]; then
        .zinit-exists-message "$user" "$plugin" || return 1
    fi

    # Print title
    printf "${ZINIT[col-title]}Report for${ZINIT[col-rst]} %s%s plugin\n"\
            "${user:+${ZINIT[col-uname]}$user${ZINIT[col-rst]}}${${user:#(%|/)*}:+/}"\
            "${ZINIT[col-pname]}$plugin${ZINIT[col-rst]}"

    # Print "----------"
    local msg="Report for $user${${user:#(%|/)*}:+/}$plugin plugin"
    print -- "${ZINIT[col-bar]}${(r:${#msg}::-:)tmp__}${ZINIT[col-rst]}"

    local -A map
    map=(
        Error:  "${ZINIT[col-error]}"
        Warning:  "${ZINIT[col-error]}"
        Note:  "${ZINIT[col-note]}"
    )
    # Print report gathered via shadowing
    () {
        setopt localoptions extendedglob
        print -rl -- "${(@)${(f@)ZINIT_REPORTS[$uspl2]}/(#b)(#s)([^[:space:]]##)([[:space:]]##)/${map[${match[1]}]:-${ZINIT[col-keyword]}}${match[1]}${ZINIT[col-rst]}${match[2]}}"
    }

    # Print report gathered via $functions-diffing
    REPLY=""
    .zinit-diff-functions-compute "$uspl2"
    .zinit-format-functions "$uspl2"
    [[ -n "$REPLY" ]] && print "${ZINIT[col-p]}Functions created:${ZINIT[col-rst]}"$'\n'"$REPLY"

    # Print report gathered via $options-diffing
    REPLY=""
    .zinit-diff-options-compute "$uspl2"
    .zinit-format-options "$uspl2"
    [[ -n "$REPLY" ]] && print "${ZINIT[col-p]}Options changed:${ZINIT[col-rst]}"$'\n'"$REPLY"

    # Print report gathered via environment diffing
    REPLY=""
    .zinit-diff-env-compute "$uspl2"
    .zinit-format-env "$uspl2" "1"
    [[ -n "$REPLY" ]] && print "${ZINIT[col-p]}PATH elements added:${ZINIT[col-rst]}"$'\n'"$REPLY"

    REPLY=""
    .zinit-format-env "$uspl2" "2"
    [[ -n "$REPLY" ]] && print "${ZINIT[col-p]}FPATH elements added:${ZINIT[col-rst]}"$'\n'"$REPLY"

    # Print report gathered via parameter diffing
    .zinit-diff-parameter-compute "$uspl2"
    .zinit-format-parameter "$uspl2"
    [[ -n "$REPLY" ]] && print "${ZINIT[col-p]}Variables added or redefined:${ZINIT[col-rst]}"$'\n'"$REPLY"

    # Print what completions plugin has
    .zinit-find-completions-of-plugin "$user" "$plugin"
    typeset -a completions
    completions=( "${reply[@]}" )

    if [[ "${#completions[@]}" -ge "1" ]]; then
        print "${ZINIT[col-p]}Completions:${ZINIT[col-rst]}"
        .zinit-check-which-completions-are-installed "${completions[@]}"
        typeset -a installed
        installed=( "${reply[@]}" )

        .zinit-check-which-completions-are-enabled "${completions[@]}"
        typeset -a enabled
        enabled=( "${reply[@]}" )

        integer count="${#completions[@]}" idx
        for (( idx=1; idx <= count; idx ++ )); do
            print -n "${completions[idx]:t}"
            if [[ "${installed[idx]}" != "1" ]]; then
                print -n " ${ZINIT[col-uninst]}[not installed]${ZINIT[col-rst]}"
            else
                if [[ "${enabled[idx]}" = "1" ]]; then
                    print -n " ${ZINIT[col-info]}[enabled]${ZINIT[col-rst]}"
                else
                    print -n " ${ZINIT[col-error]}[disabled]${ZINIT[col-rst]}"
                fi
            fi
            print
        done
        print
    fi
} # ]]]
# FUNCTION: .zinit-show-all-reports [[[
# Displays reports of all loaded plugins.
#
# User-action entry point.
.zinit-show-all-reports() {
    local i
    for i in "${ZINIT_REGISTERED_PLUGINS[@]}"; do
        [[ "$i" = "_local/zinit" ]] && continue
        .zinit-show-report "$i"
    done
} # ]]]
# FUNCTION: .zinit-show-debug-report [[[
# Displays dtrace report (data recorded in interactive session).
#
# User-action entry point.
.zinit-show-debug-report() {
    .zinit-show-report "_dtrace/_dtrace"
} # ]]]
# FUNCTION: .zinit-update-or-status [[[
# Updates (git pull) or does `git status' for given plugin.
#
# User-action entry point.
#
# $1 - "status" for status, other for update
# $2 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $3 - plugin (only when $1 - i.e. user - given)
.zinit-update-or-status() {
    emulate -LR zsh
    setopt extendedglob nullglob warncreateglobal typesetsilent noshortloops

    local -a arr
    ZINIT[first-plugin-mark]=${${ZINIT[first-plugin-mark]:#init}:-1}

    integer retval was_snippet
    .zinit-two-paths "$2${${2:#(%|/)*}:+${3:+/}}$3"
    if [[ -d ${reply[-4]} || -d ${reply[-2]} ]]; then
        .zinit-update-or-status-snippet "$1" "$2${${2:#(%|/)*}:+${3:+/}}$3"
        retval=$?
        was_snippet=1
    fi

    .zinit-any-to-user-plugin "$2" "$3"
    local user=${reply[-2]} plugin=${reply[-1]} st=$1 \
        local_dir filename is_snippet key \
        id_as="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}"
    local -A ice

    if (( was_snippet )) {
        .zinit-exists-physically "$user" "$plugin" || return $retval
        .zinit-any-colorify-as-uspl2 "$2" "$3"
        (( !ICE_OPTS[opt_-q,--quiet] )) && \
            print -Pr "${ZINIT[col-msg2]}Updating also \`$REPLY%b${ZINIT[col-msg2]}'" \
                "plugin (already updated a snippet of the same name)...%f%b"
    } else {
        .zinit-exists-physically-message "$user" "$plugin" || return 1
    }

    if [[ $st = status ]]; then
        ( builtin cd -q ${ZINIT[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}; command git status; )
        return $retval
    fi

    # A flag for the annexes. 0 – no new commits, 1 - run-atpull mode,
    # 2 – full update/there are new commits to download, 3 - full but
    # a forced download (i.e.: the medium doesn't allow to peek update)
    ZINIT[annex-multi-flag:pull-active]=0

    (( ${#ZINIT_ICE[@]} > 0 )) && { ZINIT_SICE[$user${${user:#(%|/)*}:+/}$plugin]=""; local nf="-nftid"; }

    .zinit-compute-ice "$user${${user:#(%|/)*}:+/}$plugin" "pack$nf" \
        ice local_dir filename is_snippet || return 1
    [[ ${ice[teleid]:-$id_as} = (#b)([^/]##)/(*) ]] && { user=${match[1]}; plugin=${match[2]}; } || { user=; plugin=${ice[teleid]:-$id_as}; }

    .zinit-any-to-user-plugin ${ice[teleid]:-$id_as}
    local -a arr
    reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:preinit <->]}" )
    for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
        "${arr[5]}" plugin "${reply[-2]}" "${reply[-1]}" "$id_as" "${${${(M)user:#%}:+$plugin}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}}" preinit || \
            return $(( 10 - $? ))
    done

    # Check if repository has a remote set, if it is _local
    local repo=${ZINIT[PLUGINS_DIR]}/${id_as//\//---}
    if [[ -f $repo/.git/config ]]; then
        local -a config
        config=( ${(f)"$(<$repo/.git/config)"} )
        if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]]; then
            (( !ICE_OPTS[opt_-q,--quiet] )) && {
                .zinit-any-colorify-as-uspl2 "$id_as"
                [[ $id_as = _local/* ]] && print -r -- "Skipping local plugin $REPLY" || \
                    print -r -- "$REPLY doesn't have a remote set, will not fetch"
            }
            return 1
        fi
    fi

    command rm -f $local_dir/.zinit_lastupd

    if (( 1 )); then
        if [[ -z ${ice[is_release]} && ${ice[from]} = (gh-r|github-rel) ]]; then
            ice[is_release]=true
        fi
        local do_update=0 skip_pull=0
        if [[ -n ${ice[is_release]} ]] {
            (( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source ${ZINIT[BIN_DIR]}"/zinit-install.zsh"
            {
                ZINIT_ICE=( "${(kv)ice[@]}" )
                .zinit-get-latest-gh-r-version "$user" "$plugin" || return $?
            } always {
                ZINIT_ICE=()
            }
            local version=${REPLY/(#b)(\/[^\/]##)(#c4,4)\/([^\/]##)*/${match[2]}}
            if [[ ${ice[is_release]} = $REPLY ]] {
                (( !ICE_OPTS[opt_-q,--quiet] )) && \
                    print -- "\rBinary release already up to date (version: $version)"
                skip_pull=1
                (( ${+ice[run-atpull]} )) && { do_update=1; }
            } else {
                do_update=1
            }
            ZINIT[annex-multi-flag:pull-active]=$(( 0 + 2*do_update - (skip_pull && do_update) ))

            if (( do_update )) {
                if (( ICE_OPTS[opt_-q,--quiet] && !PUPDATE )) {
                    .zinit-any-colorify-as-uspl2 "$id_as"
                    (( ZINIT[first-plugin-mark] )) && {
                        ZINIT[first-plugin-mark]=0
                    } || print
                    print "\rUpdating $REPLY"
                }

                (( !skip_pull && ICE_OPTS[opt_-r,--reset] )) && {
                    print -P "${ZINIT[col-msg2]}Removing the previous file(s) (-r/--reset given)...%f"
                    command rm -rf "${local_dir:-/tmp/xyzabc312}"/*(ND)
                }
                ZINIT_ICE=( "${(kv)ice[@]}" )
                # Run annexes' atpull hooks (the before atpull-ice ones)
                [[ ${+ice[atpull]} = 1 && ${ice[atpull]} = "!"* ]] && {
                    reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:\\\!atpull <->]}" )
                    for key in "${reply[@]}"; do
                        arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
                        "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" \!atpull
                    done
                }

                (( !skip_pull && ${+ZINIT_ICE[reset]} )) && (
                    (( !ICE_OPTS[opt_-q,--quiet] )) && print -P "%F{220}reset: running ${ZINIT_ICE[reset]:-rm -rf ${local_dir:-/tmp/xyzabc312}/*}%f"
                    eval ${ZINIT_ICE[reset]:-command rm -rf "${local_dir:-/tmp/xyzabc312}"/*(ND)}
                )

                [[ ${ice[atpull]} = "!"* ]] && .zinit-countdown atpull && ( (( ${+ice[nocd]} == 0 )) && { builtin cd -q "$local_dir" && .zinit-at-eval "${ice[atpull]#\!}" "${ice[atclone]}"; ((1)); } || .zinit-at-eval "${ice[atpull]#\!}" "${ice[atclone]}"; )
                print -r -- mark >! $local_dir/.zinit_lastupd

                if (( !skip_pull )) {
                    .zinit-setup-plugin-dir "$user" "$plugin" "$id_as" release -u $version || \
                        ZINIT[annex-multi-flag:pull-active]=0
                    if (( ICE_OPTS[opt_-q,--quiet] != 1 )) {
                        print
                    }
                }
                ZINIT_ICE=()
            }
        } else {
            ( builtin cd -q "$local_dir" || return 1
              integer had_output=0
              local IFS=$'\n'
              command git fetch --quiet && \
                command git log --color --date=short --pretty=format:'%Cgreen%cd %h %Creset%s%n' ..FETCH_HEAD | \
                while read line; do
                  [[ -n ${line%%[[:space:]]##} ]] && {
                      [[ $had_output -eq 0 ]] && {
                          had_output=1
                          if (( ICE_OPTS[opt_-q,--quiet] && !PUPDATE )) {
                              .zinit-any-colorify-as-uspl2 "$id_as"
                              (( ZINIT[first-plugin-mark] )) && {
                                  ZINIT[first-plugin-mark]=0
                              } || print
                              print "Updating $REPLY"
                          }
                      }
                      print $line
                  }
                done | \
                command tee .zinit_lastupd | \
                .zinit-pager &

              integer pager_pid=$!
              { sleep 20 && kill -9 $pager_pid 2>/dev/null 1>&2; } &!
              { wait $pager_pid; } > /dev/null 2>&1

              local -a log
              { log=( ${(@f)"$(<$local_dir/.zinit_lastupd)"} ); } 2>/dev/null

              [[ ${#log} -gt 0 ]] && do_update=1 || \
                  {
                      skip_pull=1
                      (( ${+ice[run-atpull]} )) && {
                          do_update=1
                          print -r -- mark >! $local_dir/.zinit_lastupd
                          if (( ICE_OPTS[opt_-q,--quiet] && !PUPDATE )) {
                              .zinit-any-colorify-as-uspl2 "$id_as"
                              (( ZINIT[first-plugin-mark] )) && {
                                  ZINIT[first-plugin-mark]=0
                              } || print
                              print "\rUpdating $REPLY"
                          }
                      }
                  }

              ZINIT[annex-multi-flag:pull-active]=$(( 0 + 2*do_update - (skip_pull && do_update) ))

              if (( do_update )) {
                  (( !skip_pull && ICE_OPTS[opt_-r,--reset] )) && {
                      print -P "${ZINIT[col-msg2]}Resetting the repository (-r/--reset given)...%f"
                      command git reset --hard HEAD
                  }
                  ZINIT_ICE=( "${(kv)ice[@]}" )
                  # Run annexes' atpull hooks (the before atpull-ice ones)
                  [[ ${+ice[atpull]} = 1 && ${ice[atpull]} = "!"* ]] && {
                      reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:\\\!atpull <->]}" )
                      for key in "${reply[@]}"; do
                          arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
                          "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" \!atpull
                      done
                  }
                  (( ${+ZINIT_ICE[reset]} )) && (
                      (( !ICE_OPTS[opt_-q,--quiet] )) && print -P "%F{220}reset: running ${ZINIT_ICE[reset]:-git reset --hard HEAD}%f"
                      eval "${ZINIT_ICE[reset]:-command git reset --hard HEAD}"
                  )
                  [[ ${ice[atpull]} = "!"* ]] && .zinit-countdown atpull && ( (( ${+ice[nocd]} == 0 )) && { builtin cd -q "$local_dir" && .zinit-at-eval "${ice[atpull]#\!}" "${ice[atclone]}"; ((1)); } || .zinit-at-eval "${ice[atpull]#\!}" "${ice[atclone]}"; )
                  ZINIT_ICE=()
                  (( !skip_pull )) && command git pull --no-stat
              }
              return ${ZINIT[annex-multi-flag:pull-active]}
            )
            ZINIT[annex-multi-flag:pull-active]=$?
        }

        [[ -d $local_dir/.git ]] && \
            (
                builtin cd -q "$local_dir" # || return 1 - don't return, maybe it's some hook's logic
                if (( ICE_OPTS[opt_-q,--quiet] )) {
                    command git pull --recurse-submodules &> /dev/null
                } else {
                    command git pull --recurse-submodules | grep -v "Already up to date."
                }
            )

        local -a log
        { log=( ${(@f)"$(<$local_dir/.zinit_lastupd)"} ); } 2>/dev/null

        command rm -f $local_dir/.zinit_lastupd

        # Any new commits?
        [[ ${#log} -gt 0 ]] && {
            [[ ${+ice[make]} = 1 && ${ice[make]} = "!!"* ]] && .zinit-countdown make && { command make -C "$local_dir" ${(@s; ;)${ice[make]#\!\!}}; }

            if [[ -z ${ice[is_release]} && -n ${ice[mv]} ]]; then
                if [[ ${ice[mv]} = *("->"|"→")* ]] {
                    local from=${ice[mv]%%[[:space:]]#(->|→)*} to=${ice[mv]##*(->|→)[[:space:]]#} || \
                } else {
                    local from=${ice[mv]%%[[:space:]]##*} to=${ice[mv]##*[[:space:]]##}
                }
                local -a afr
                ( builtin cd -q "$local_dir" || return 1
                  afr=( ${~from}(DN) )
                  [[ ${#afr} -gt 0 ]] && { 
                      if (( !ICE_OPTS[opt_-q,--quiet] )) {
                          command mv -vf "${afr[1]}" "$to"
                          command mv -vf "${afr[1]}".zwc "$to".zwc 2>/dev/null;
                      } else {
                          command mv -f "${afr[1]}" "$to"
                          command mv -f "${afr[1]}".zwc "$to".zwc 2>/dev/null;
                      }
                  }
                )
            fi

            if [[ -z ${ice[is_release]} && -n ${ice[cp]} ]]; then
                if [[ ${ice[cp]} = *("->"|"→")* ]] {
                    local from=${ice[cp]%%[[:space:]]#(->|→)*} to=${ice[cp]##*(->|→)[[:space:]]#} || \
                } else {
                    local from=${ice[cp]%%[[:space:]]##*} to=${ice[cp]##*[[:space:]]##}
                }
                local -a afr
                ( builtin cd -q "$local_dir" || return 1
                  afr=( ${~from}(DN) )
                  [[ ${#afr} -gt 0 ]] && {
                      if (( !ICE_OPTS[opt_-q,--quiet] )) {
                          command cp -vf "${afr[1]}" "$to"
                          command cp -vf "${afr[1]}".zwc "$to".zwc 2>/dev/null
                      } else {
                          command cp -f "${afr[1]}" "$to"
                          command cp -f "${afr[1]}".zwc "$to".zwc 2>/dev/null
                      }
                  }
                )
            fi

            ZINIT_ICE=( "${(kv)ice[@]}" )
            # Run annexes' atpull hooks (the before atpull-ice ones)
            [[ ${ice[atpull]} != "!"* ]] && {
                reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:\\\!atpull <->]}" )
                for key in "${reply[@]}"; do
                    arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
                    "${arr[5]}" "plugin" "$user" "$plugin" "$id_as" "$local_dir" \!atpull
                done
            }

            [[ ${+ice[make]} = 1 && ${ice[make]} = ("!"[^\!]*|"!") ]] && .zinit-countdown make && { command make -C "$local_dir" ${(@s; ;)${ice[make]#\!}}; }
            [[ -n ${ice[atpull]} && ${ice[atpull][1]} != "!" ]] && .zinit-countdown "atpull" && ( (( ${+ice[nocd]} == 0 )) && { builtin cd -q "$local_dir" && .zinit-at-eval "${ice[atpull]}" "${ice[atclone]}"; ((1)); } || .zinit-at-eval "${ice[atpull]}" "${ice[atclone]}"; )
            [[ ${+ice[make]} = 1 && ${ice[make]} != "!"* ]] && .zinit-countdown make && command make -C "$local_dir" ${(@s; ;)${ice[make]}}

            # Run annexes' atpull hooks (the after atpull-ice ones)
            reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:atpull <->]}" )
            for key in "${reply[@]}"; do
                arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
                "${arr[5]}" "plugin" "$user" "$plugin" "$id_as" "$local_dir" atpull
            done
            ZINIT_ICE=()
        }

        # Store ices to disk at update of plugin
        .zinit-store-ices "$local_dir/._zinit" ice "" "" "" ""
    fi
    ZINIT_ICE=( "${(kv)ice[@]}" )

    if (( ZINIT[annex-multi-flag:pull-active] > 0 && ${+ZINIT_ICE[extract]} )) {
        (( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source ${ZINIT[BIN_DIR]}"/zinit-install.zsh"
        local extract=${ZINIT_ICE[extract]}
        [[ -n $extract ]] && @zinit-substitute extract
        .zinit-extract plugin "$extract" "$local_dir"
    }

    # Run annexes' atpull hooks (the `always' after atpull-ice ones)
    reply=( ${(@on)ZINIT_EXTS[(I)z-annex hook:%atpull <->]} )
    for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
        "${arr[5]}" "plugin" "$user" "$plugin" "$id_as" "$local_dir" \%atpull
    done

    if [[ -n ${ZINIT_ICE[ps-on-update]} ]]; then
        if (( !ICE_OPTS[opt_-q,--quiet] )) {
            print -r "Running plugin's provided update code: ${ZINIT[col-info]}${ZINIT_ICE[ps-on-update][1,50]}${ZINIT_ICE[ps-on-update][51]:+…}${ZINIT[col-rst]}"
            (
                builtin cd -q "$local_dir" || return 1
                eval "${ZINIT_ICE[ps-on-update]}"
            )
        } else {
            (
                builtin cd -q "$local_dir" || return 1
                eval "${ZINIT_ICE[ps-on-update]}" &> /dev/null
            )
        }
    fi
    ZINIT_ICE=()

    if (( PUPDATE && ZINIT[annex-multi-flag:pull-active] > 0 )) {
        print ${ZINIT[annex-multi-flag:pull-active]} >! $PUFILE.ind
    }

    return $retval
} # ]]]
# FUNCTION: .zinit-update-or-status-snippet [[[
#
# Implements update or status operation for snippet given by URL.
#
# $1 - "status" or "update"
# $2 - snippet URL
.zinit-update-or-status-snippet() {
    local st="$1" URL="${2%/}" local_dir filename is_snippet
    (( ${#ZINIT_ICE[@]} > 0 )) && { ZINIT_SICE[$URL]=""; local nf="-nftid"; }
    .zinit-compute-ice "$URL" "pack$nf" \
        ZINIT_ICE local_dir filename is_snippet || return 1

    integer retval

    if [[ "$st" = "status" ]]; then
        if (( ${+ZINIT_ICE[svn]} )); then
            print -r -- "${ZINIT[col-info]}Status for ${${${local_dir:h}:t}##*--}/${local_dir:t}${ZINIT[col-rst]}"
            ( builtin cd -q "$local_dir"; command svn status -vu )
            retval=$?
            print
        else
            print -r -- "${ZINIT[col-info]}Status for ${${local_dir:h}##*--}/$filename${ZINIT[col-rst]}"
            ( builtin cd -q "$local_dir"; command ls -lth $filename )
            retval=$?
            print
        fi
    else
        (( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source ${ZINIT[BIN_DIR]}"/zinit-install.zsh"
        .zinit-update-snippet "${ZINIT_ICE[teleid]:-$URL}"
        retval=$?
    fi

    ZINIT_ICE=()

    if (( PUPDATE && ZINIT[annex-multi-flag:pull-active] > 0 )) {
        print ${ZINIT[annex-multi-flag:pull-active]} >! $PUFILE.ind
    }

    return $retval
}
# ]]]
# FUNCTION: .zinit-update-or-status-all [[[
# Updates (git pull) or does `git status` for all existing plugins.
# This includes also plugins that are not loaded into Zsh (but exist
# on disk). Also updates (i.e. redownloads) snippets.
#
# User-action entry point.
.zinit-update-or-status-all() {
    emulate -LR zsh
    setopt extendedglob nullglob warncreateglobal typesetsilent noshortloops

    [[ $2 = restart ]] && \
        print -P "$ZINIT[col-msg2]Restarting the update with the new codebase loaded.%f%b\n"

    local file
    integer sum el
    for file ( "" -side -install -autoload ) {
        .zinit-get-mtime-into "${ZINIT[BIN_DIR]}/zinit$file.zsh" el; sum+=el
    }

    # Reload Zinit?
    if [[ $2 != restart ]] && (( ZINIT[mtime] + ZINIT[mtime-side] +
        ZINIT[mtime-install] + ZINIT[mtime-autoload] != sum
    )) {
        print -P "$ZINIT[col-msg2]Detected Zinit update in another session -" \
            "$ZINIT[col-pre]reloading Zinit$ZINIT[col-msg2]...%f%b"
        source $ZINIT[BIN_DIR]/zinit.zsh
        source $ZINIT[BIN_DIR]/zinit-side.zsh
        source $ZINIT[BIN_DIR]/zinit-install.zsh
        source $ZINIT[BIN_DIR]/zinit-autoload.zsh
        for file ( "" -side -install -autoload ) {
            .zinit-get-mtime-into "${ZINIT[BIN_DIR]}/zinit$file.zsh" "ZINIT[mtime$file]"
        }
        print -P "%B$ZINIT[col-pname]Done.%f%b\n"
        .zinit-update-or-status-all "$1" restart
        return $?
    }

    if (( ICE_OPTS[opt_-p,--parallel] )) && [[ $1 = update ]] {
        (( !ICE_OPTS[opt_-q,--quiet] )) && \
            print -Pr -- "$ZINIT[col-info2]Parallel Update Starts Now...%f"
        .zinit-update-all-parallel
        return $?
    }

    local st=$1 id_as repo snip pd user plugin
    integer PUPDATE=0

    local -A ZINIT_ICE

    local -a snipps
    snipps=( ${ZINIT[SNIPPETS_DIR]}/**/(._zinit|._zplugin)(ND) )

    [[ $st != status && ${ICE_OPTS[opt_-q,--quiet]} != 1 && -n $snipps ]] && \
        print "${ZINIT[col-info]}Note:${ZINIT[col-rst]} updating also unloaded snippets"

    for snip in ${ZINIT[SNIPPETS_DIR]}/**/(._zinit|._zplugin)/mode(D); do
        [[ ! -f ${snip:h}/url ]] && continue
        [[ -f ${snip:h}/id-as ]] && \
            id_as="$(<${snip:h}/id-as)" || \
            id_as=
        .zinit-update-or-status-snippet "$st" "${id_as:-$(<${snip:h}/url)}"
        ZINIT_ICE=()
    done
    [[ -n $snipps ]] && print

    ZINIT_ICE=()

    if [[ $st = status ]]; then
        (( !ICE_OPTS[opt_-q,--quiet] )) && \
            print "${ZINIT[col-info]}Note:${ZINIT[col-rst]} status done also for unloaded plugins"
    else
        (( !ICE_OPTS[opt_-q,--quiet] )) && \
            print "${ZINIT[col-info]}Note:${ZINIT[col-rst]} updating also unloaded plugins"
    fi

    ZINIT[first-plugin-mark]=init

    for repo in ${ZINIT[PLUGINS_DIR]}/*; do
        pd=${repo:t}

        # Two special cases
        [[ $pd = custom || $pd = _local---zinit ]] && continue

        .zinit-any-colorify-as-uspl2 "$pd"

        # Check if repository has a remote set
        if [[ -f $repo/.git/config ]]; then
            local -a config
            config=( ${(f)"$(<$repo/.git/config)"} )
            if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]]; then
                if (( !ICE_OPTS[opt_-q,--quiet] )) {
                    [[ $pd = _local---* ]] && \
                        print -- "\nSkipping local plugin $REPLY" || \
                        print "\n$REPLY doesn't have a remote set, will not fetch"
                }
                continue
            fi
        fi

        .zinit-any-to-user-plugin "$pd"
        local user=${reply[-2]} plugin=${reply[-1]}

        # Must be a git repository or a binary release
        if [[ ! -d $repo/.git && ! -f $repo/._zinit/is_release ]]; then
            (( !ICE_OPTS[opt_-q,--quiet] )) && \
                print "$REPLY: not a git repository"
            continue
        fi

        if [[ $st = status ]]; then
            print "\nStatus for plugin $REPLY"
            ( builtin cd -q "$repo"; command git status )
        else
            (( !ICE_OPTS[opt_-q,--quiet] )) && print "Updating $REPLY" || print -n .
            .zinit-update-or-status update "$user" "$plugin"
        fi
    done
} # ]]]
# FUNCTION: .zinit-update-in-parallel [[[
.zinit-update-all-parallel() {
    emulate -LR zsh
    setopt extendedglob warncreateglobal typesetsilent \
        noshortloops nomonitor nonotify

    local id_as repo snip uspl user plugin PUDIR="$(mktemp -d)"

    local -A PUAssocArray map
    map=( / --  "=" -EQ-  "?" -QM-  "&" -AMP-  : - )
    local -a files
    integer main_counter counter PUPDATE=1

    files=( ${ZINIT[SNIPPETS_DIR]}/**/(._zinit|._zplugin)/mode(ND) )
    main_counter=${#files}
    for snip ( "${files[@]}" ) {
        main_counter=main_counter-1
        # The continue may cause the tail of processes to
        # fall-through to the following plugins-specific `wait'
        # Should happen only in a very special conditions
        # TODO handle this
        [[ ! -f ${snip:h}/url ]] && continue
        [[ -f ${snip:h}/id-as ]] && \
            id_as="$(<${snip:h}/id-as)" || \
            id_as=

        counter+=1
        local ef_id="${id_as:-$(<${snip:h}/url)}"
        local PUFILEMAIN=${${ef_id#/}//(#m)[\/=\?\&:]/${map[$MATCH]}}
        local PUFILE=$PUDIR/${counter}_$PUFILEMAIN.out

        .zinit-update-or-status-snippet "$st" "$ef_id" &>! $PUFILE &

        PUAssocArray[$!]=$PUFILE

        .zinit-wait-for-update-jobs snippets
    }

    counter=0
    PUAssocArray=()

    local -a files2
    files=( ${ZINIT[PLUGINS_DIR]}/*(ND/) )

    # Pre-process plugins
    for repo ( $files ) {
        uspl=${repo:t}
        # Two special cases
        [[ $uspl = custom || $uspl = _local---zinit ]] && continue

        # Check if repository has a remote set
        if [[ -f $repo/.git/config ]] {
            local -a config
            config=( ${(f)"$(<$repo/.git/config)"} )
            if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]] {
                continue
            }
        }

        .zinit-any-to-user-plugin "$uspl"
        local user=${reply[-2]} plugin=${reply[-1]}

        # Must be a git repository or a binary release
        if [[ ! -d $repo/.git && ! -f $repo/._zinit/is_release ]] {
            continue
        }
        files2+=( $repo )
    }

    main_counter=${#files2}
    for repo ( "${files2[@]}" ) {
        main_counter=main_counter-1

        uspl=${repo:t}
        id_as=${uspl//---//}

        counter+=1
        local PUFILEMAIN=${${id_as#/}//(#m)[\/=\?\&:]/${map[$MATCH]}}
        local PUFILE=$PUDIR/${counter}_$PUFILEMAIN.out

        .zinit-any-colorify-as-uspl2 "$uspl"
        print -r -- "Updating $REPLY..." >! $PUFILE

        .zinit-any-to-user-plugin "$uspl"
        local user=${reply[-2]} plugin=${reply[-1]}

        .zinit-update-or-status update "$user" "$plugin" &>>! $PUFILE &

        PUAssocArray[$!]=$PUFILE

        .zinit-wait-for-update-jobs plugins

    }
    # Shouldn't happen
    # (( ${#PUAssocArray} > 0 )) && wait ${(k)PUAssocArray}
}
# ]]]
# FUNCTION: .zinit-wait-for-update-jobs [[[
.zinit-wait-for-update-jobs() {
    local tpe=$1
    if (( counter > ICE_OPTS[value] || main_counter == 0 )) {
        wait ${(k)PUAssocArray}
        local ind_file
        for ind_file ( ${^${(von)PUAssocArray}}.ind(DN.) ) {
            command cat ${ind_file:r}
            command rm -f $ind_file
        }
        command rm -f ${(v)PUAssocArray}
        counter=0
        PUAssocArray=()
    } elif (( counter == 1 && !ICE_OPTS[opt_-q,--quiet] )) {
        print -Pr -- "$ZINIT[col-obj]Spawning the next$ZINIT[col-file]" \
            "$ICE_OPTS[value]$ZINIT[col-obj] concurrent update jobs" \
            "($ZINIT[col-msg2]%F{191}$tpe$ZINIT[col-obj])...%f%b"
    }
}
# ]]]
# FUNCTION: .zinit-show-zstatus [[[
# Shows Zinit status, i.e. number of loaded plugins,
# of available completions, etc.
#
# User-action entry point.
.zinit-show-zstatus() {
    builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

    local infoc="${ZINIT[col-info2]}"

    print "Zinit's main directory: ${infoc}${ZINIT[HOME_DIR]}${ZINIT[col-rst]}"
    print "Zinit's binary directory: ${infoc}${ZINIT[BIN_DIR]}${ZINIT[col-rst]}"
    print "Plugin directory: ${infoc}${ZINIT[PLUGINS_DIR]}${ZINIT[col-rst]}"
    print "Completions directory: ${infoc}${ZINIT[COMPLETIONS_DIR]}${ZINIT[col-rst]}"

    # Without _zlocal/zinit
    print "Loaded plugins: ${infoc}$(( ${#ZINIT_REGISTERED_PLUGINS[@]} - 1 ))${ZINIT[col-rst]}"

    # Count light-loaded plugins
    integer light=0
    local s
    for s in "${ZINIT_REGISTERED_STATES[@]}"; do
        [[ "$s" = 1 ]] && (( light ++ ))
    done
    # Without _zlocal/zinit
    print "Light loaded: ${infoc}$(( light - 1 ))${ZINIT[col-rst]}"

    # Downloaded plugins, without _zlocal/zinit, custom
    typeset -a plugins
    plugins=( "${ZINIT[PLUGINS_DIR]}"/*(DN) )
    print "Downloaded plugins: ${infoc}$(( ${#plugins} - 1 ))${ZINIT[col-rst]}"

    # Number of enabled completions, with _zlocal/zinit
    typeset -a completions
    completions=( "${ZINIT[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc(DN) )
    print "Enabled completions: ${infoc}${#completions[@]}${ZINIT[col-rst]}"

    # Number of disabled completions, with _zlocal/zinit
    completions=( "${ZINIT[COMPLETIONS_DIR]}"/[^_.]*~*.zwc(DN) )
    print "Disabled completions: ${infoc}${#completions[@]}${ZINIT[col-rst]}"

    # Number of completions existing in all plugins
    completions=( "${ZINIT[PLUGINS_DIR]}"/*/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*)(DN) )
    print "Completions available overall: ${infoc}${#completions[@]}${ZINIT[col-rst]}"

    # Enumerate snippets loaded
    print "Snippets loaded: ${infoc}${(j:, :onv)ZINIT_SNIPPETS[@]}${ZINIT[col-rst]}"

    # Number of compiled plugins
    typeset -a matches m
    integer count=0
    matches=( ${ZINIT[PLUGINS_DIR]}/*/*.zwc(DN) )

    local cur_plugin="" uspl1
    for m in "${matches[@]}"; do
        uspl1="${${m:h}:t}"

        if [[ "$cur_plugin" != "$uspl1" ]]; then
            (( count ++ ))
            cur_plugin="$uspl1"
        fi
    done

    print "Compiled plugins: ${infoc}$count${ZINIT[col-rst]}"
} # ]]]
# FUNCTION: .zinit-show-times [[[
# Shows loading times of all loaded plugins.
#
# User-action entry point.
.zinit-show-times() {
    setopt localoptions extendedglob nokshglob noksharrays
    local opt="$1 $2 $3" entry entry2 entry3 user plugin
    float -F 3 sum=0.0
    local -A sice
    local -a tmp

    [[ "$opt" = *-[a-z]#m[a-z]#* ]] && \
        { print "Plugin loading moments (relative to the first prompt):"; ((1)); } || \
        print "Plugin loading times:"

    for entry in "${(@on)ZINIT[(I)TIME_[0-9]##_*]}"; do
        entry2="${entry#TIME_[0-9]##_}"
        entry3="AT_$entry"
        if [[ "$entry2" = (http|https|ftp|ftps|scp|OMZ|PZT):* ]]; then
            REPLY="${ZINIT[col-pname]}$entry2${ZINIT[col-rst]}"

            tmp=( "${(z@)ZINIT_SICE[${entry2%/}]}" )
            (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()
        else
            user="${entry2%%---*}"
            plugin="${entry2#*---}"
            [[ "$user" = \% ]] && plugin="/${plugin//---/\/}"
            [[ "$user" = "$plugin" && "$user/$plugin" != "$entry2" ]] && user=""
            .zinit-any-colorify-as-uspl2 "$user" "$plugin"

            tmp=( "${(z@)ZINIT_SICE[$user/$plugin]}" )
            (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()
        fi

        local attime=$(( ZINIT[$entry3] - ZINIT[START_TIME] ))
        if [[ "$opt" = *-[a-z]#s[a-z]#* ]]; then
            local time="$ZINIT[$entry] sec"
            attime="${(M)attime#*.???} sec"
        else
            local time="${(l:5:: :)$(( ZINIT[$entry] * 1000 ))%%[,.]*} ms"
            attime="${(l:5:: :)$(( attime * 1000 ))%%[,.]*} ms"
        fi
        [[ -z $EPOCHREALTIME ]] && attime="<no zsh/datetime module → no time data>"

        if [[ "$opt" = *-[a-z]#m[a-z]#* ]]; then
            time="$attime"
        fi

        if [[ ${sice[as]} == "command" ]]; then
            print "$time" - "$REPLY (command)"
        elif [[ -n ${sice[sbin]} ]]; then
            print "$time" - "$REPLY (sbin command)"
        elif [[ -n ${sice[fbin]} ]]; then
            print "$time" - "$REPLY (fbin command)"
        elif [[ ( ${sice[pick]} = /dev/null || ${sice[as]} = null ) && ${+sice[make]} = 1 ]]; then
            print "$time" - "$REPLY (/dev/null make plugin)"
        else
            print "$time" - "$REPLY"
        fi

        (( sum += ZINIT[$entry] ))
    done
    print "Total: $sum sec"
}
# ]]]
# FUNCTION: .zinit-list-bindkeys [[[
.zinit-list-bindkeys() {
    local uspl2 uspl2col sw first=1
    local -a string_widget

    # KSH_ARRAYS immunity
    integer correct=0
    [[ -o "KSH_ARRAYS" ]] && correct=1

    for uspl2 in "${(@ko)ZINIT[(I)BINDKEYS__*]}"; do
        [[ -z "${ZINIT[$uspl2]}" ]] && continue

        (( !first )) && print
        first=0

        uspl2="${uspl2#BINDKEYS__}"

        .zinit-any-colorify-as-uspl2 "$uspl2"
        uspl2col="$REPLY"
        print "$uspl2col"

        string_widget=( "${(z@)ZINIT[BINDKEYS__$uspl2]}" )
        for sw in "${(Oa)string_widget[@]}"; do
            [[ -z "$sw" ]] && continue
            # Remove one level of quoting to split using (z)
            sw="${(Q)sw}"
            typeset -a sw_arr
            sw_arr=( "${(z@)sw}" )

            # Remove one level of quoting to pass to bindkey
            local sw_arr1="${(Q)sw_arr[1-correct]}" # Keys
            local sw_arr2="${(Q)sw_arr[2-correct]}" # Widget
            local sw_arr3="${(Q)sw_arr[3-correct]}" # Optional -M or -A or -N
            local sw_arr4="${(Q)sw_arr[4-correct]}" # Optional map name
            local sw_arr5="${(Q)sw_arr[5-correct]}" # Optional -R (not with -A, -N)

            if [[ "$sw_arr3" = "-M" && "$sw_arr5" != "-R" ]]; then
                print "bindkey $sw_arr1 $sw_arr2 ${ZINIT[col-info]}for keymap $sw_arr4${ZINIT[col-rst]}"
            elif [[ "$sw_arr3" = "-M" && "$sw_arr5" = "-R" ]]; then
                print "${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey $sw_arr1 $sw_arr2 ${ZINIT[col-info]}mapped to $sw_arr4${ZINIT[col-rst]}"
            elif [[ "$sw_arr3" != "-M" && "$sw_arr5" = "-R" ]]; then
                print "${ZINIT[col-info]}range${ZINIT[col-rst]} bindkey $sw_arr1 $sw_arr2"
            elif [[ "$sw_arr3" = "-A" ]]; then
                print "Override of keymap \`main'"
            elif [[ "$sw_arr3" = "-N" ]]; then
                print "New keymap \`$sw_arr4'"
            else
                print "bindkey $sw_arr1 $sw_arr2"
            fi
        done
    done
}
# ]]]

# FUNCTION: .zinit-compiled [[[
# Displays list of plugins that are compiled.
#
# User-action entry point.
.zinit-compiled() {
    builtin setopt localoptions nullglob

    typeset -a matches m
    matches=( ${ZINIT[PLUGINS_DIR]}/*/*.zwc(DN) )

    if [[ "${#matches[@]}" -eq "0" ]]; then
        print "No compiled plugins"
        return 0
    fi

    local cur_plugin="" uspl1 file user plugin
    for m in "${matches[@]}"; do
        file="${m:t}"
        uspl1="${${m:h}:t}"
        .zinit-any-to-user-plugin "$uspl1"
        user="${reply[-2]}" plugin="${reply[-1]}"

        if [[ "$cur_plugin" != "$uspl1" ]]; then
            [[ -n "$cur_plugin" ]] && print # newline
            .zinit-any-colorify-as-uspl2 "$user" "$plugin"
            print -r -- "$REPLY:"
            cur_plugin="$uspl1"
        fi

        print "$file"
    done
} # ]]]
# FUNCTION: .zinit-compile-uncompile-all [[[
# Compiles or uncompiles all existing (on disk) plugins.
#
# User-action entry point.
.zinit-compile-uncompile-all() {
    builtin setopt localoptions nullglob

    local compile="$1"

    typeset -a plugins
    plugins=( "${ZINIT[PLUGINS_DIR]}"/*(DN) )

    local p user plugin
    for p in "${plugins[@]}"; do
        [[ "${p:t}" = "custom" || "${p:t}" = "_local---zinit" ]] && continue

        .zinit-any-to-user-plugin "${p:t}"
        user="${reply[-2]}" plugin="${reply[-1]}"

        .zinit-any-colorify-as-uspl2 "$user" "$plugin"
        print -r -- "$REPLY:"

        if [[ "$compile" = "1" ]]; then
            .zinit-compile-plugin "$user" "$plugin"
        else
            .zinit-uncompile-plugin "$user" "$plugin" "1"
        fi
    done
} # ]]]
# FUNCTION: .zinit-uncompile-plugin [[[
# Uncompiles given plugin.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-uncompile-plugin() {
    builtin setopt localoptions nullglob

    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}" silent="$3"

    # There are plugins having ".plugin.zsh"
    # in ${plugin} directory name, also some
    # have ".zsh" there
    [[ "$user" = "%" ]] && local pdir_path="$plugin" || local pdir_path="${ZINIT[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}"
    typeset -a matches m
    matches=( $pdir_path/*.zwc(DN) )

    if [[ "${#matches[@]}" -eq "0" ]]; then
        if [[ "$silent" = "1" ]]; then
            print "not compiled"
        else
            .zinit-any-colorify-as-uspl2 "$user" "$plugin"
            print -r -- "$REPLY not compiled"
        fi
        return 1
    fi

    for m in "${matches[@]}"; do
        print "Removing ${ZINIT[col-info]}${m:t}${ZINIT[col-rst]}"
        command rm -f "$m"
    done
} # ]]]

# FUNCTION: .zinit-show-completions [[[
# Display installed (enabled and disabled), completions. Detect
# stray and improper ones.
#
# Completions live even when plugin isn't loaded - if they are
# installed and enabled.
#
# User-action entry point.
.zinit-show-completions() {
    builtin setopt localoptions nullglob extendedglob nokshglob noksharrays
    local count="${1:-3}"

    typeset -a completions
    completions=( "${ZINIT[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc "${ZINIT[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )

    local cpath c o s group

    # Prepare readlink command for establishing
    # completion's owner
    .zinit-prepare-readlink
    local rdlink="$REPLY"

    float flmax=${#completions} flcur=0
    typeset -F1 flper

    local -A owner_to_group
    local -a packs splitted

    integer disabled unknown stray
    for cpath in "${completions[@]}"; do
        c="${cpath:t}"
        [[ "${c#_}" = "${c}" ]] && disabled=1 || disabled=0
        c="${c#_}"

        # This will resolve completion's symlink to obtain
        # information about the repository it comes from, i.e.
        # about user and plugin, taken from directory name
        .zinit-get-completion-owner "$cpath" "$rdlink"
        [[ "$REPLY" = "[unknown]" ]] && unknown=1 || unknown=0
        o="$REPLY"

        # If we successfully read a symlink (unknown == 0), test if it isn't broken
        stray=0
        if (( unknown == 0 )); then
            [[ ! -f "$cpath" ]] && stray=1
        fi

        s=$(( 1*disabled + 2*unknown + 4*stray ))

        owner_to_group[${o}--$s]+="$c;"
        group="${owner_to_group[${o}--$s]%;}"
        splitted=( "${(s:;:)group}" )

        if [[ "${#splitted}" -ge "$count" ]]; then
            packs+=( "${(q)group//;/, } ${(q)o} ${(q)s}" )
            unset "owner_to_group[${o}--$s]"
        fi

        (( ++ flcur ))
        flper=$(( flcur / flmax * 100 ))
        print -u 2 -n -- "\r${flper}% "
    done

    for o in "${(k)owner_to_group[@]}"; do
        group="${owner_to_group[$o]%;}"
        s="${o##*--}"
        o="${o%--*}"
        packs+=( "${(q)group//;/, } ${(q)o} ${(q)s}" )
    done
    packs=( "${(on)packs[@]}" )

    print -u 2 # newline after percent

    # Find longest completion name
    integer longest=0
    local -a unpacked
    for c in "${packs[@]}"; do
        unpacked=( "${(Q@)${(z@)c}}" )
        [[ "${#unpacked[1]}" -gt "$longest" ]] && longest="${#unpacked[1]}"
    done

    for c in "${packs[@]}"; do
        unpacked=( "${(Q@)${(z@)c}}" ) # TODO: ${(Q)${(z@)c}[@]} ?

        .zinit-any-colorify-as-uspl2 "$unpacked[2]"
        print -n "${(r:longest+1:: :)unpacked[1]} $REPLY"

        (( unpacked[3] & 0x1 )) && print -n " ${ZINIT[col-error]}[disabled]${ZINIT[col-rst]}"
        (( unpacked[3] & 0x2 )) && print -n " ${ZINIT[col-error]}[unknown file, clean with cclear]${ZINIT[col-rst]}"
        (( unpacked[3] & 0x4 )) && print -n " ${ZINIT[col-error]}[stray, clean with cclear]${ZINIT[col-rst]}"
        print
    done
} # ]]]
# FUNCTION: .zinit-clear-completions [[[
# Delete stray and improper completions.
#
# Completions live even when plugin isn't loaded - if they are
# installed and enabled.
#
# User-action entry point.
.zinit-clear-completions() {
    builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

    typeset -a completions
    completions=( "${ZINIT[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc "${ZINIT[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )

    # Find longest completion name
    local cpath c
    integer longest=0
    for cpath in "${completions[@]}"; do
        c="${cpath:t}"
        c="${c#_}"
        [[ "${#c}" -gt "$longest" ]] && longest="${#c}"
    done

    .zinit-prepare-readlink
    local rdlink="$REPLY"

    integer disabled unknown stray
    for cpath in "${completions[@]}"; do
        c="${cpath:t}"
        [[ "${c#_}" = "${c}" ]] && disabled=1 || disabled=0
        c="${c#_}"

        # This will resolve completion's symlink to obtain
        # information about the repository it comes from, i.e.
        # about user and plugin, taken from directory name
        .zinit-get-completion-owner "$cpath" "$rdlink"
        [[ "$REPLY" = "[unknown]" ]] && unknown=1 || unknown=0
        .zinit-any-colorify-as-uspl2 "$REPLY"

        # If we successfully read a symlink (unknown == 0), test if it isn't broken
        stray=0
        if (( unknown == 0 )); then
            [[ ! -f "$cpath" ]] && stray=1
        fi

        if (( unknown == 1 || stray == 1 )); then
            print -n "Removing completion: ${(r:longest+1:: :)c} $REPLY"
            (( disabled )) && print -n " ${ZINIT[col-error]}[disabled]${ZINIT[col-rst]}"
            (( unknown )) && print -n " ${ZINIT[col-error]}[unknown file]${ZINIT[col-rst]}"
            (( stray )) && print -n " ${ZINIT[col-error]}[stray]${ZINIT[col-rst]}"
            print
            command rm -f "$cpath"
        fi
    done
} # ]]]
# FUNCTION: .zinit-search-completions [[[
# While .zinit-show-completions() shows what completions are
# installed, this functions searches through all plugin dirs
# showing what's available in general (for installation).
#
# User-action entry point.
.zinit-search-completions() {
    builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

    typeset -a plugin_paths
    plugin_paths=( "${ZINIT[PLUGINS_DIR]}"/*(DN) )

    # Find longest plugin name. Things are ran twice here, first pass
    # is to get longest name of plugin which is having any completions
    integer longest=0
    typeset -a completions
    local pp
    for pp in "${plugin_paths[@]}"; do
        completions=( "$pp"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*)(DN^/) )
        if [[ "${#completions[@]}" -gt 0 ]]; then
            local pd="${pp:t}"
            [[ "${#pd}" -gt "$longest" ]] && longest="${#pd}"
        fi
    done

    print "${ZINIT[col-info]}[+]${ZINIT[col-rst]} is installed, ${ZINIT[col-p]}[-]${ZINIT[col-rst]} uninstalled, ${ZINIT[col-error]}[+-]${ZINIT[col-rst]} partially installed"

    local c
    for pp in "${plugin_paths[@]}"; do
        completions=( "$pp"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*)(DN^/) )

        if [[ "${#completions[@]}" -gt 0 ]]; then
            # Array of completions, e.g. ( _cp _xauth )
            completions=( "${completions[@]:t}" )

            # Detect if the completions are installed
            integer all_installed="${#completions[@]}"
            for c in "${completions[@]}"; do
                if [[ -e "${ZINIT[COMPLETIONS_DIR]}/$c" || -e "${ZINIT[COMPLETIONS_DIR]}/${c#_}" ]]; then
                    (( all_installed -- ))
                fi
            done

            if [[ "$all_installed" -eq "${#completions[@]}" ]]; then
                print -n "${ZINIT[col-p]}[-]${ZINIT[col-rst]} "
            elif [[ "$all_installed" -eq "0" ]]; then
                print -n "${ZINIT[col-info]}[+]${ZINIT[col-rst]} "
            else
                print -n "${ZINIT[col-error]}[+-]${ZINIT[col-rst]} "
            fi

            # Convert directory name to colorified $user/$plugin
            .zinit-any-colorify-as-uspl2 "${pp:t}"

            # Adjust for escape code (nasty, utilizes fact that
            # ${ZINIT[col-rst]} is used twice, so as a $ZINIT_COL)
            integer adjust_ec=$(( ${#ZINIT[col-rst]} * 2 + ${#ZINIT[col-uname]} + ${#ZINIT[col-pname]} ))

            print "${(r:longest+adjust_ec:: :)REPLY} ${(j:, :)completions}"
        fi
    done
} # ]]]
# FUNCTION: .zinit-cenable [[[
# Disables given installed completion.
#
# User-action entry point.
#
# $1 - e.g. "_mkdir" or "mkdir"
.zinit-cenable() {
    local c="$1"
    c="${c#_}"

    local cfile="${ZINIT[COMPLETIONS_DIR]}/_${c}"
    local bkpfile="${cfile:h}/$c"

    if [[ ! -e "$cfile" && ! -e "$bkpfile" ]]; then
        print "${ZINIT[col-error]}No such completion \`$c'${ZINIT[col-rst]}"
        return 1
    fi

    # Check if there is no backup file
    # This is treated as if the completion is already enabled
    if [[ ! -e "$bkpfile" ]]; then
        print "Completion ${ZINIT[col-info]}$c${ZINIT[col-rst]} already enabled"

        .zinit-check-comp-consistency "$cfile" "$bkpfile" 0
        return 1
    fi

    # Disabled, but completion file already exists?
    if [[ -e "$cfile" ]]; then
        print "${ZINIT[col-error]}Warning: completion's file \`${cfile:t}' exists, will overwrite${ZINIT[col-rst]}"
        print "${ZINIT[col-error]}Completion is actually enabled and will re-enable it again${ZINIT[col-rst]}"
        .zinit-check-comp-consistency "$cfile" "$bkpfile" 1
        command rm -f "$cfile"
    else
        .zinit-check-comp-consistency "$cfile" "$bkpfile" 0
    fi

    # Enable
    command mv "$bkpfile" "$cfile" # move completion's backup file created when disabling

    # Prepare readlink command for establishing completion's owner
    .zinit-prepare-readlink
    # Get completion's owning plugin
    .zinit-get-completion-owner-uspl2col "$cfile" "$REPLY"

    print "Enabled ${ZINIT[col-info]}$c${ZINIT[col-rst]} completion belonging to $REPLY"

    return 0
} # ]]]
# FUNCTION: .zinit-cdisable [[[
# Enables given installed completion.
#
# User-action entry point.
#
# $1 - e.g. "_mkdir" or "mkdir"
.zinit-cdisable() {
    local c="$1"
    c="${c#_}"

    local cfile="${ZINIT[COMPLETIONS_DIR]}/_${c}"
    local bkpfile="${cfile:h}/$c"

    if [[ ! -e "$cfile" && ! -e "$bkpfile" ]]; then
        print "${ZINIT[col-error]}No such completion \`$c'${ZINIT[col-rst]}"
        return 1
    fi

    # Check if it's already disabled
    # Not existing "$cfile" says that
    if [[ ! -e "$cfile" ]]; then
        print "Completion ${ZINIT[col-info]}$c${ZINIT[col-rst]} already disabled"

        .zinit-check-comp-consistency "$cfile" "$bkpfile" 0
        return 1
    fi

    # No disable, but bkpfile exists?
    if [[ -e "$bkpfile" ]]; then
        print "${ZINIT[col-error]}Warning: completion's backup file \`${bkpfile:t}' already exists, will overwrite${ZINIT[col-rst]}"
        .zinit-check-comp-consistency "$cfile" "$bkpfile" 1
        command rm -f "$bkpfile"
    else
        .zinit-check-comp-consistency "$cfile" "$bkpfile" 0
    fi

    # Disable
    command mv "$cfile" "$bkpfile"

    # Prepare readlink command for establishing completion's owner
    .zinit-prepare-readlink
    # Get completion's owning plugin
    .zinit-get-completion-owner-uspl2col "$bkpfile" "$REPLY"

    print "Disabled ${ZINIT[col-info]}$c${ZINIT[col-rst]} completion belonging to $REPLY"

    return 0
} # ]]]

# FUNCTION: .zinit-cd [[[
# Jumps to plugin's directory (in Zinit's home directory).
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-cd() {
    setopt localoptions extendedglob nokshglob noksharrays
    .zinit-get-path "$1" "$2" && {
        if [[ -e "$REPLY" ]]; then
            builtin cd "$REPLY"
        else
            print -r -- "No such plugin or snippet"
            return 1
        fi
        print
    } || {
        print -r -- "No such plugin or snippet"
        return 1
    }
} # ]]]
# FUNCTION: .zinit-run-delete-hooks [[[
.zinit-run-delete-hooks() {
    if [[ -n ${ZINIT_ICE[atdelete]} ]]; then
        .zinit-countdown "atdelete" && ( (( ${+ZINIT_ICE[nocd]} == 0 )) && \
                { builtin cd -q "$5" && eval "${ZINIT_ICE[atdelete]}"; ((1)); } || \
                eval "${ZINIT_ICE[atdelete]}" )
    fi
    local -a arr
    local key
    reply=( "${(@on)ZINIT_EXTS[(I)z-annex hook:atdelete <->]}" )
    for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
        "${arr[5]}" "$1" "$2" $3 "$4" "$5" atdelete
    done
}
# ]]]
# FUNCTION: .zinit-delete [[[
# Deletes plugin's or snippet's directory (in Zinit's home directory).
#
# User-action entry point.
#
# $1 - snippet URL or plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-delete() {
    setopt localoptions extendedglob nokshglob noksharrays warncreateglobal

    # Parse options
    local -a opts
    opts=( --all --clean --yes -y -q --quiet )
    : ${@[@]//(#b)([ $'\t']##|(#s))(${(~j.|.)opts})([ $'\t']##|(#e))/${ICE_OPTS[${opt_map[${match[2]}]}]::=1}}
    set -- "${@[@]:#(${(~j.|.)opts})}"

    local the_id="$1${${1:#(%|/)*}:+${2:+/}}$2"

    # --all given?
    if (( ICE_OPTS[opt_--all] )); then
        .zinit-confirm "Prune all plugins in \`${ZINIT[PLUGINS_DIR]}'"\
"and snippets in \`${ZINIT[SNIPPETS_DIR]}'?" \
"command rm -rf ${${ZINIT[PLUGINS_DIR]##[[:space:]]##}:-/tmp/abcEFG312}/*~*/_local---zinit(ND) "\
"${${ZINIT[SNIPPETS_DIR]##[[:space:]]##}:-/tmp/abcEFG312}/*~*/plugins(ND)"
        return $?
    fi

    # --clean given?
    if (( ICE_OPTS[opt_--clean] )); then
        .zinit-confirm "Prune ${ZINIT[col-info]}CURRENTLY NOT LOADED${ZINIT[col-rst]}"\
" plugins in ${ZINIT[PLUGINS_DIR]}"\
" and snippets in ${ZINIT[SNIPPETS_DIR]}?" \
"command rm -rf ${${ZINIT[PLUGINS_DIR]##[[:space:]]##}:-/tmp/abcEFG312}/*~*/(${(j:|:)${ZINIT_REGISTERED_PLUGINS[@]//\//---}})(ND) "\
"${${ZINIT[SNIPPETS_DIR]##[[:space:]]##}:-/tmp/abcEFG312}/*~*/(plugins|OMZ::lib|${(j:|:)${(@)${(@)${${ZINIT_SNIPPETS[@]% <*>}[@]:h}//\//--}}})(ND)"
        return $?
    fi

    local -A ZINIT_ICE
    local local_dir filename is_snippet

    .zinit-compute-ice "$the_id" "pack" \
        ZINIT_ICE local_dir filename is_snippet || return 1

    if [[ "$local_dir" != /* ]]
    then
        print "Obtained a risky, not-absolute path ($local_dir), aborting"
        return 1
    fi

    ZINIT_ICE[teleid]="${ZINIT_ICE[teleid]:-${ZINIT_ICE[id-as]}}"

    local -a files
    files=( "$local_dir"/*.(zsh|sh|bash|ksh)(DN:t)
        "$local_dir"/*(*DN:t) "$local_dir"/*(@DN:t) "$local_dir"/*(.DN:t)
        "$local_dir"/*~*/.(_zinit|svn|git)(/DN:t) "$local_dir"/*(=DN:t)
        "$local_dir"/*(pDN:t) "$local_dir"/*(%DN:t)
    )
    (( !${#files} )) && files=( "no files?" )
    files=( ${(@)files[1,4]} ${files[4]+more…} )

    if (( is_snippet )); then
        if [[ "${+ZINIT_ICE[svn]}" = "1" ]] {
            if [[ -e "$local_dir" ]]
            then
                .zinit-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
                    ".zinit-run-delete-hooks snippet \"${ZINIT_ICE[teleid]}\" \"\" \"$the_id\" \
                    \"$local_dir\"; \
                    command rm -rf ${(q)${${local_dir:#/}:-/tmp/abcYZX321}}"
            else
                print "No such snippet"
                return 1
            fi
        } else {
            if [[ -e "$local_dir" ]]; then
                .zinit-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
                    ".zinit-run-delete-hooks snippet \"${ZINIT_ICE[teleid]}\" \"\" \"$the_id\" \
                    \"$local_dir\"; command rm -rf \
                        ${(q)${${local_dir:#/}:-/tmp/abcYZX321}}"
            else
                print "No such snippet"
                return 1
            fi
        }
    else
        .zinit-any-to-user-plugin "${ZINIT_ICE[teleid]}"
        if [[ -e "$local_dir" ]]; then
            .zinit-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
                ".zinit-run-delete-hooks plugin \"${reply[-2]}\" \"${reply[-1]}\" \"$the_id\" \
                \"$local_dir\"; \
                command rm -rf ${(q)${${local_dir:#/}:-/tmp/abcYZX321}}"
        else
            print -r -- "No such plugin or snippet"
            return 1
        fi
    fi

    return 0
} # ]]]
# FUNCTION: .zinit-confirm [[[
# Prints given question, waits for "y" key, evals
# given expression if "y" obtained
#
# $1 - question
# $2 - expression
.zinit-confirm() {
    if (( ICE_OPTS[opt_-y,--yes] )); then
        integer retval
        eval "$2"; retval=$?
        (( ICE_OPTS[opt_-q,--quiet] )) || print "\nDone (action executed, exit code: $retval)"
    else
        print "$1"
        print "[yY/n…]"
        local ans
        read -q ans
        [[ "$ans" = "y" ]] && { eval "$2"; print "\nDone (action executed, exit code: $?)"; } || { print "\nBreak, no action"; return 1; }
    fi
    return 0
}
# ]]]
# FUNCTION: .zinit-changes [[[
# Shows `git log` of given plugin.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-changes() {
    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}"

    .zinit-exists-physically-message "$user" "$plugin" || return 1

    (
        builtin cd -q "${ZINIT[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}" && \
        command git log -p --graph --decorate --date=relative -C -M
    )
} # ]]]
# FUNCTION: .zinit-recently [[[
# Shows plugins that obtained commits in specified past time.
#
# User-action entry point.
#
# $1 - time spec, e.g. "1 week"
.zinit-recently() {
    emulate -LR zsh
    builtin setopt nullglob extendedglob warncreateglobal \
                typesetsilent noshortloops

    local IFS=.
    local gitout
    local timespec=${*// ##/.}
    timespec=${timespec//.##/.}
    [[ -z $timespec ]] && timespec=1.week

    typeset -a plugins
    plugins=( ${ZINIT[PLUGINS_DIR]}/*(DN) )

    local p uspl1
    for p in ${plugins[@]}; do
        uspl1=${p:t}
        [[ $uspl1 = custom || $uspl1 = _local---zinit ]] && continue

        pushd "$p" >/dev/null
        if [[ -d .git ]]; then
            gitout=`command git log --all --max-count=1 --since=$timespec 2>/dev/null`
            if [[ -n $gitout ]]; then
                .zinit-any-colorify-as-uspl2 "$uspl1"
                print -r -- "$REPLY"
            fi
        fi
        popd >/dev/null
    done
} # ]]]
# FUNCTION: .zinit-create [[[
# Creates a plugin, also on Github (if not "_local/name" plugin).
#
# User-action entry point.
#
# $1 - (optional) plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zinit-create() {
    emulate -LR zsh
    setopt localoptions extendedglob warncreateglobal typesetsilent \
        noshortloops rcquotes 

    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}"

    if (( ${+commands[curl]} == 0 || ${+commands[git]} == 0 )); then
        print "${ZINIT[col-error]}curl and git are needed${ZINIT[col-rst]}"
        return 1
    fi

    # Read whether to create under organization
    local isorg
    vared -cp 'Create under an organization? (y/n): ' isorg

    if [[ $isorg = (y|yes) ]]; then
        local org="$user"
        vared -cp "Github organization name: " org
    fi

    # Read user
    local compcontext="user:User Name:(\"$USER\" \"$user\")"
    vared -cp "Github user name or just \"_local\" (or leave blank, for an userless plugin): " user

    # Read plugin
    unset compcontext
    vared -cp 'Plugin name: ' plugin

    if [[ "$plugin" = "_unknown" ]]; then
        print "${ZINIT[col-error]}No plugin name entered${ZINIT[col-rst]}"
        return 1
    fi

    plugin="${plugin//[^a-zA-Z0-9_]##/-}"
    .zinit-any-colorify-as-uspl2 "${${${(M)isorg:#(y|yes)}:+$org}:-$user}" "$plugin"
    local uspl2col="$REPLY"
    print "Plugin is $uspl2col"

    if .zinit-exists-physically "${${${(M)isorg:#(y|yes)}:+$org}:-$user}" "$plugin"; then
        print "${ZINIT[col-error]}Repository${ZINIT[col-rst]} $uspl2col ${ZINIT[col-error]}already exists locally${ZINIT[col-rst]}"
        return 1
    fi

    builtin cd -q "${ZINIT[PLUGINS_DIR]}"

    if [[ "$user" != "_local" && -n "$user" ]]; then
        print "${ZINIT[col-info]}Creating Github repository${ZINIT[col-rst]}"
        if [[ $isorg = (y|yes) ]]; then
            curl --silent -u "$user" https://api.github.com/orgs/$org/repos -d '{"name":"'"$plugin"'"}' >/dev/null
        else
            curl --silent -u "$user" https://api.github.com/user/repos -d '{"name":"'"$plugin"'"}' >/dev/null
        fi
        command git clone "https://github.com/${${${(M)isorg:#(y|yes)}:+$org}:-$user}/${plugin}.git" "${${${(M)isorg:#(y|yes)}:+$org}:-$user}---${plugin//\//---}" || {
            print "${ZINIT[col-error]}Creation of remote repository $uspl2col ${ZINIT[col-error]}failed${ZINIT[col-rst]}"
            print "${ZINIT[col-error]}Bad credentials?${ZINIT[col-rst]}"
            return 1
        }
        builtin cd -q "${${${(M)isorg:#(y|yes)}:+$org}:-$user}---${plugin//\//---}"
        command git config credential.https://github.com.username "${user}"
    else
        print "${ZINIT[col-info]}Creating local git repository${${user:+.}:-, ${ZINIT[col-pname]}free-style, without the \"_local/\" part${ZINIT[col-info]}.}${ZINIT[col-rst]}"
        command mkdir "${user:+${user}---}${plugin//\//---}"
        builtin cd -q "${user:+${user}---}${plugin//\//---}"
        command git init || {
            print "Git repository initialization failed, aborting"
            return 1
        }
    fi

    local user_name="$(command git config user.name 2>/dev/null)"
    local year="${$(command date "+%Y"):-2020}"

    command cat >! "${plugin:t}.plugin.zsh" <<EOF
# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

# Copyright (c) $year $user_name

# According to the Zsh Plugin Standard:
# http://zdharma.org/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html

0=\${\${ZERO:-\${0:#\$ZSH_ARGZERO}}:-\${(%):-%N}}
0=\${\${(M)0:#/*}:-\$PWD/\$0}

# Then \${0:h} to get plugin's directory

if [[ \${zsh_loaded_plugins[-1]} != */${plugin:t} && -z \${fpath[(r)\${0:h}]} ]] {
    fpath+=( "\${0:h}" )
}

# Standard hash for plugins, to not pollute the namespace
typeset -gA Plugins
Plugins[${${(U)plugin:t}//-/_}_DIR]="\${0:h}"

autoload -Uz example-script

# Use alternate vim marks [[[ and ]]] as the original ones can
# confuse nested substitutions, e.g.: \${\${\${VAR}}}

# vim:ft=zsh:tw=80:sw=4:sts=4:et:foldmarker=[[[,]]]
EOF

    command cat >>! .git/config <<EOF

[diff "zsh"]
    xfuncname = "^((function[[:blank:]]+[^[:blank:]]+[[:blank:]]*(\\\\(\\\\)|))|([^[:blank:]]+[[:blank:]]*\\\\(\\\\)))[[:blank:]]*(\\\\{|)[[:blank:]]*$"
[diff "markdown"]
    xfuncname = "^#+[[:blank:]].*$"
EOF

    print -r -- "*.zsh  diff=zsh" >! .gitattributes
    print -r -- "*.md   diff=markdown" >! .gitattributes
    print -r -- "# $plugin" >! "README.md"
    command cp -vf "${ZINIT[BIN_DIR]}/LICENSE" LICENSE
    command cp -vf "${ZINIT[BIN_DIR]}/doc/Zsh.gitignore" .gitignore
    command cp -vf "${ZINIT[BIN_DIR]}/doc/example-script" .

    command sed -i -e "s/MY_PLUGIN_DIR/${${(U)plugin:t}//-/_}_DIR/g" example-script
    command sed -i -e "s/USER_NAME/$user_name/g" example-script
    command sed -i -e "s/YEAR/$year/g" example-script

    if [[ "$user" != "_local" && -n "$user" ]]; then
        print "Remote repository $uspl2col set up as origin."
        print "You're in plugin's local folder, the files aren't added to git."
        print "Your next step after commiting will be:"
        print "git push -u origin master"
    else
        print "Created local $uspl2col plugin."
        print "You're in plugin's repository folder, the files aren't added to git."
    fi
} # ]]]
# FUNCTION: .zinit-glance [[[
# Shows colorized source code of plugin. Is able to use pygmentize,
# highlight, GNU source-highlight.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-glance() {
    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}"

    .zinit-exists-physically-message "$user" "$plugin" || return 1

    .zinit-first "$1" "$2" || {
        print "${ZINIT[col-error]}No source file found, cannot glance${ZINIT[col-rst]}"
        return 1
    }

    local fname="${reply[-1]}"

    integer has_256_colors=0
    [[ "$TERM" = xterm* || "$TERM" = "screen" ]] && has_256_colors=1

    {
        if (( ${+commands[pygmentize]} )); then
            print "Glancing with ${ZINIT[col-info]}pygmentize${ZINIT[col-rst]}"
            pygmentize -l bash -g "$fname"
        elif (( ${+commands[highlight]} )); then
            print "Glancing with ${ZINIT[col-info]}highlight${ZINIT[col-rst]}"
            if (( has_256_colors )); then
                highlight -q --force -S sh -O xterm256 "$fname"
            else
                highlight -q --force -S sh -O ansi "$fname"
            fi
        elif (( ${+commands[source-highlight]} )); then
            print "Glancing with ${ZINIT[col-info]}source-highlight${ZINIT[col-rst]}"
            source-highlight -fesc --failsafe -s zsh -o STDOUT -i "$fname"
        else
            cat "$fname"
        fi
    } | {
        if [[ -t 1 ]]; then
            .zinit-pager
        else
            cat
        fi
    }
} # ]]]
# FUNCTION: .zinit-edit [[[
# Runs $EDITOR on source of given plugin. If the variable is not
# set then defaults to `vim'.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-edit() {
    local -A ZINIT_ICE
    local local_dir filename is_snippet the_id="$1${${1:#(%|/)*}:+${2:+/}}$2"

    .zinit-compute-ice "$the_id" "pack" \
        ZINIT_ICE local_dir filename is_snippet || return 1

    ZINIT_ICE[teleid]="${ZINIT_ICE[teleid]:-${ZINIT_ICE[id-as]}}"

    if (( is_snippet )); then
        if [[ ! -e "$local_dir" ]]; then
            print "No such snippet"
            return 1
        fi
    else
        if [[ ! -e "$local_dir" ]]; then
            print -r -- "No such plugin or snippet"
            return 1
        fi
    fi

    "${EDITOR:-vim}" "$local_dir"
    return 0
} # ]]]
# FUNCTION: .zinit-stress [[[
# Compiles plugin with various options on and off to see
# how well the code is written. The options are:
#
# NO_SHORT_LOOPS, IGNORE_BRACES, IGNORE_CLOSE_BRACES, SH_GLOB,
# CSH_JUNKIE_QUOTES, NO_MULTI_FUNC_DEF.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zinit-stress() {
    .zinit-any-to-user-plugin "$1" "$2"
    local user="${reply[-2]}" plugin="${reply[-1]}"

    .zinit-exists-physically-message "$user" "$plugin" || return 1

    .zinit-first "$1" "$2" || {
        print "${ZINIT[col-error]}No source file found, cannot stress${ZINIT[col-rst]}"
        return 1
    }

    local pdir_path="${reply[-2]}" fname="${reply[-1]}"

    integer compiled=1
    [[ -e "${fname}.zwc" ]] && command rm -f "${fname}.zwc" || compiled=0

    local -a ZINIT_STRESS_TEST_OPTIONS
    ZINIT_STRESS_TEST_OPTIONS=(
        "NO_SHORT_LOOPS" "IGNORE_BRACES" "IGNORE_CLOSE_BRACES"
        "SH_GLOB" "CSH_JUNKIE_QUOTES" "NO_MULTI_FUNC_DEF"
    )

    (
        emulate -LR ksh
        builtin unsetopt shglob kshglob
        for i in "${ZINIT_STRESS_TEST_OPTIONS[@]}"; do
            builtin setopt "$i"
            print -n "Stress-testing ${fname:t} for option $i "
            zcompile -R "$fname" 2>/dev/null && {
                print "[${ZINIT[col-success]}Success${ZINIT[col-rst]}]"
            } || {
                print "[${ZINIT[col-failure]}Fail${ZINIT[col-rst]}]"
            }
            builtin unsetopt "$i"
        done
    )

    command rm -f "${fname}.zwc"
    (( compiled )) && zcompile "$fname"
} # ]]]
# FUNCTION: .zinit-list-compdef-replay [[[
# Shows recorded compdefs (called by plugins loaded earlier).
# Plugins often call `compdef' hoping for `compinit' being
# already ran. Zinit solves this by recording compdefs.
#
# User-action entry point.
.zinit-list-compdef-replay() {
    print "Recorded compdefs:"
    local cdf
    for cdf in "${ZINIT_COMPDEF_REPLAY[@]}"; do
        print "compdef ${(Q)cdf}"
    done
} # ]]]
# FUNCTION: .zinit-ls [[[
.zinit-ls() {
    (( ${+commands[tree]} )) || {
        print "${ZINIT[col-error]}No \`tree' program, it is required by the subcommand \`ls\'${ZINIT[col-rst]}"
        print "Download from: http://mama.indstate.edu/users/ice/tree/"
        print "It is also available probably in all distributions and Homebrew, as package \`tree'"
    }
    (
        setopt localoptions extendedglob nokshglob noksharrays
        builtin cd -q "${ZINIT[SNIPPETS_DIR]}"
        local -a list
        list=( "${(f@)"$(LANG=en_US.utf-8 tree -L 3 --charset utf-8)"}" )
        # Oh-My-Zsh single file
        list=( "${list[@]//(#b)(https--github.com--robbyrussell--oh-my-zsh--raw--master(--)(#c0,1)(*))/$ZINIT[col-info]Oh-My-Zsh$ZINIT[col-error]${match[2]/--//}$ZINIT[col-pname]${match[3]//--/$ZINIT[col-error]/$ZINIT[col-pname]} $ZINIT[col-info](single-file)$ZINIT[col-rst] ${match[1]}}" )
        # Oh-My-Zsh SVN
        list=( "${list[@]//(#b)(https--github.com--robbyrussell--oh-my-zsh--trunk(--)(#c0,1)(*))/$ZINIT[col-info]Oh-My-Zsh$ZINIT[col-error]${match[2]/--//}$ZINIT[col-pname]${match[3]//--/$ZINIT[col-error]/$ZINIT[col-pname]} $ZINIT[col-info](SVN)$ZINIT[col-rst] ${match[1]}}" )
        # Prezto single file
        list=( "${list[@]//(#b)(https--github.com--sorin-ionescu--prezto--raw--master(--)(#c0,1)(*))/$ZINIT[col-info]Prezto$ZINIT[col-error]${match[2]/--//}$ZINIT[col-pname]${match[3]//--/$ZINIT[col-error]/$ZINIT[col-pname]} $ZINIT[col-info](single-file)$ZINIT[col-rst] ${match[1]}}" )
        # Prezto SVN
        list=( "${list[@]//(#b)(https--github.com--sorin-ionescu--prezto--trunk(--)(#c0,1)(*))/$ZINIT[col-info]Prezto$ZINIT[col-error]${match[2]/--//}$ZINIT[col-pname]${match[3]//--/$ZINIT[col-error]/$ZINIT[col-pname]} $ZINIT[col-info](SVN)$ZINIT[col-rst] ${match[1]}}" )

        # First-level names
        list=( "${list[@]//(#b)(#s)(│   └──|    └──|    ├──|│   ├──) (*)/${match[1]} $ZINIT[col-error]${match[2]}$ZINIT[col-rst]}" )

        list[-1]+=", located at ZINIT[SNIPPETS_DIR], i.e. ${ZINIT[SNIPPETS_DIR]}"
        print -rl -- "${list[@]}"
    )
}
# ]]]
# FUNCTION: .zinit-get-path [[[
# Returns path of given ID-string, which may be a plugin-spec
# (like "user/plugin" or "user" "plugin"), an absolute path
# ("%" "/home/..." and also "%SNIPPETS/..." etc.), or a plugin
# nickname (i.e. id-as'' ice-mod), or a snippet nickname.
.zinit-get-path() {
    emulate -LR zsh
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    local the_id=$1${${1:#(%|/)*}:+${2:+/}}$2

    if [[ $the_id = (%|/)* ]]; then
        REPLY=${the_id#%}
        return 0
    fi

    .zinit-two-paths "$the_id"
    local s_path=${reply[-4]} s_svn=${reply[-3]} \
            _path=${reply[-2]} _filename=${reply[-1]}

    reply=()
    REPLY=

    if [[ -d $s_path || -d $_path ]]; then
        local -A sice
        local -a tmp
        tmp=( "${(z@)ZINIT_SICE[$the_id]}" )
        (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" )

        [[ ${+sice[svn]} = 1 || -n $s_svn ]] && {
            [[ -e $s_path ]] && REPLY=$s_path
        } || {
            reply=( ${_filename:+"$_filename"} )
            [[ -e $_path ]] && REPLY=$_path
        }
    else
        .zinit-any-to-user-plugin "$1" "$2"
        local user=${reply[-2]} plugin=${reply[-1]}
        reply=()

        .zinit-exists-physically "$user" "$plugin" || return 1

        .zinit-shands-exp "$1" "$2" && {
            :
        } || {
            REPLY=${ZINIT[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}
        }
    fi

    return 0
}
# ]]]
# FUNCTION: .zinit-recall [[[
.zinit-recall() {
    local -A ice
    local el val cand1 cand2 local_dir filename is_snippet

    local -a ice_order nval_ices output
    ice_order=(
        svn proto from teleid bindmap cloneopts id-as depth if wait load
        unload blockf pick bpick src as ver silent lucid notify mv cp
        atinit atclone atload atpull nocd run-atpull has cloneonly make
        service trackbinds multisrc compile nocompile nocompletions
        reset-prompt wrap-track reset sh \!sh bash \!bash ksh \!ksh csh
        \!csh aliases countdown ps-on-unload ps-on-update trigger-load
        light-mode is-snippet atdelete pack git verbose on-update-of
        subscribe param extract
        # Include all additional ices – after
        # stripping them from the possible: ''
        ${(@us.|.)${ZINIT_EXTS[ice-mods]//\'\'/}}
    )
    nval_ices=(
            blockf silent lucid trackbinds cloneonly nocd run-atpull
            nocompletions sh \!sh bash \!bash ksh \!ksh csh \!csh
            aliases countdown light-mode is-snippet git verbose

            # Include only those additional ices,
            # don't have the '' in their name, i.e.
            # aren't designed to hold value
            ${(@)${(@s.|.)ZINIT_EXTS[ice-mods]}:#*\'\'*}

            # Must be last
            svn
    )
    .zinit-compute-ice "$1${${1:#(%|/)*}:+${2:+/}}$2" "pack" \
        ice local_dir filename is_snippet || return 1

    [[ -e "$local_dir" ]] && {
        for el in "${ice_order[@]}"; do
            val="${ice[$el]}"
            cand1="${(qqq)val}"
            cand2="${(qq)val}"
            if [[ -n "$val" ]]; then
                [[ "${cand1/\\\$/}" != "$cand1" || "${cand1/\\\!/}" != "$cand1" ]] && output+=( "$el$cand2" ) || output+=( "$el$cand1" )
            elif [[ ${+ice[$el]} = 1 && ( -n "${nval_ices[(r)$el]}" || "$el" = (make|nocompile|notify|reset) ) ]]; then
                output+=( "$el" )
            fi
        done

        if [[ "${#output}" = 0 ]]; then
            print -zr "# No Ice modifiers"
        else
            print -zr "zinit ice ${output[*]}; zinit "
        fi
        .zinit-deploy-message @rst
    } || print -r -- "No such plugin or snippet"
}
# ]]]
# FUNCTION: .zinit-module [[[
# Function that has sub-commands passed as long-options (with two dashes, --).
# It's an attempt to plugin only this one function into `zinit' function
# defined in zinit.zsh, to not make this file longer than it's needed.
.zinit-module() {
    if [[ "$1" = "build" ]]; then
        .zinit-build-module "${@[2,-1]}"
    elif [[ "$1" = "info" ]]; then
        if [[ "$2" = "--link" ]]; then
              print -r "You can copy the error messages and submit"
              print -r "error-report at: https://github.com/zdharma/zinit/issues"
        else
            print -r "To load the module, add following 2 lines to .zshrc, at top:"
            print -r "    module_path+=( \"${ZINIT[BIN_DIR]}/zmodules/Src\" )"
            print -r "    zmodload zdharma/zplugin"
            print -r ""
            print -r "After loading, use command \`zpmod' to communicate with the module."
            print -r "See \`zpmod -h' for more information."
        fi
    elif [[ "$1" = (help|usage) ]]; then
        print -r "Usage: zinit module {build|info|help} [options]"
        print -r "       zinit module build [--clean]"
        print -r "       zinit module info [--link]"
        print -r ""
        print -r "To start using the zinit Zsh module run: \`zinit module build'"
        print -r "and follow the instructions. Option --clean causes \`make distclean'"
        print -r "to be run. To display the instructions on loading the module, run:"
        print -r "\`zinit module info'."
    fi
}
# ]]]
# FUNCTION: .zinit-build-module [[[
# Performs ./configure && make on the module and displays information
# how to load the module in .zshrc.
.zinit-build-module() {
    setopt localoptions localtraps
    trap 'return 1' INT TERM
    ( builtin cd -q "${ZINIT[BIN_DIR]}"/zmodules
      print -r -- "${ZINIT[col-pname]}== Building module zdharma/zplugin, running: make clean, then ./configure and then make ==${ZINIT[col-rst]}"
      print -r -- "${ZINIT[col-pname]}== The module sources are located at: "${ZINIT[BIN_DIR]}"/zmodules ==${ZINIT[col-rst]}"
      [[ -f Makefile ]] && { [[ "$1" = "--clean" ]] && {
              print -r -- ${ZINIT[col-p]}-- make distclean --${ZINIT[col-rst]}
              make distclean
              ((1))
          } || {
              print -r -- ${ZINIT[col-p]}-- make clean --${ZINIT[col-rst]}
              make clean
          }
      }
      print -r -- ${ZINIT[col-p]}-- ./configure --${ZINIT[col-rst]}
      CPPFLAGS=-I/usr/local/include CFLAGS="-g -Wall -O3" LDFLAGS=-L/usr/local/lib ./configure --disable-gdbm --without-tcsetpgrp && {
          print -r -- ${ZINIT[col-p]}-- make --${ZINIT[col-rst]}
          make && {
            [[ -f Src/zdharma/zplugin.so ]] && cp -vf Src/zdharma/zplugin.{so,bundle}
            print -r -- "${ZINIT[col-info]}Module has been built correctly.${ZINIT[col-rst]}"
            .zinit-module info
          } || {
              print -rn -- "${ZINIT[col-error]}Module didn't build.${ZINIT[col-rst]} "
              .zinit-module info --link
          }
      }
    )
}
# ]]]

#
# Help function
#

# FUNCTION: .zinit-help [[[
# Shows usage information.
#
# User-action entry point.
.zinit-help() {
           print -r -- "${ZINIT[col-p]}Usage${ZINIT[col-rst]}:
—— -h|--help|help                – usage information
—— man                           – manual
—— self-update                   – updates and compiles Zinit
—— times [-s] [-m]               – statistics on plugin load times, sorted in order of loading; -s – use seconds instead of milliseconds, -m – show plugin loading moments
—— zstatus                       – overall Zinit status
—— load ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}                 – load plugin, can also receive absolute local path
—— light [-b] ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}           – light plugin load, without reporting/tracking (-b – do track but bindkey-calls only)
—— unload ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}               – unload plugin loaded with \`zinit load ...', -q – quiet
—— snippet [-f] ${ZINIT[col-pname]}{url}${ZINIT[col-rst]}            – source local or remote file (by direct URL), -f: force – don't use cache
—— ls                            – list snippets in formatted and colorized manner
—— ice <ice specification>       – add ICE to next command, argument is e.g. from\"gitlab\"
—— update [-q] ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}|URL      – Git update plugin or snippet (or all plugins and snippets if ——all passed); besides -q accepts also ——quiet, and also -r/--reset – this option causes to run git reset --hard / svn revert before pulling changes
—— status ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}|URL           – Git status for plugin or svn status for snippet (or for all those if ——all passed)
—— report ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}               – show plugin's report (or all plugins' if ——all passed)
—— delete [--all|--clean] ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}|URL – remove plugin or snippet from disk (good to forget wrongly passed ice-mods); --all – purge, --clean – delete plugins and snippets that are not loaded
—— loaded|list [keyword]         – show what plugins are loaded (filter with \'keyword')
—— cd ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}                   – cd into plugin's directory; also support snippets, if feed with URL
—— create ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}               – create plugin (also together with Github repository)
—— edit ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}                 – edit plugin's file with \$EDITOR
—— glance ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}               – look at plugin's source (pygmentize, {,source-}highlight)
—— stress ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}               – test plugin for compatibility with set of options
—— changes ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}              – view plugin's git log
—— recently ${ZINIT[col-info]}[time-spec]${ZINIT[col-rst]}          – show plugins that changed recently, argument is e.g. 1 month 2 days
—— clist|completions             – list completions in use
—— cdisable ${ZINIT[col-info]}cname${ZINIT[col-rst]}                – disable completion \`cname'
—— cenable ${ZINIT[col-info]}cname${ZINIT[col-rst]}                 – enable completion \`cname'
—— creinstall ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}           – install completions for plugin, can also receive absolute local path; -q – quiet
—— cuninstall ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}           – uninstall completions for plugin
—— csearch                       – search for available completions from any plugin
—— compinit                      – refresh installed completions
—— dtrace|dstart                 – start tracking what's going on in session
—— dstop                         – stop tracking what's going on in session
—— dunload                       – revert changes recorded between dstart and dstop
—— dreport                       – report what was going on in session
—— dclear                        – clear report of what was going on in session
—— compile ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}              – compile plugin (or all plugins if ——all passed)
—— uncompile ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}            – remove compiled version of plugin (or of all plugins if ——all passed)
—— compiled                      – list plugins that are compiled
—— cdlist                        – show compdef replay list
—— cdreplay [-q]                 – replay compdefs (to be done after compinit), -q – quiet
—— cdclear [-q]                  – clear compdef replay list, -q – quiet
—— srv {service-id} [cmd]        – control a service, command can be: stop,start,restart,next,quit; \`next' moves the service to another Zshell
—— recall ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]}|URL           – fetch saved ice modifiers and construct \`zinit ice ...' command
—— env-whitelist [-v|-h] {env..} – allows to specify names (also patterns) of variables left unchanged during an unload. -v – verbose
—— bindkeys                      – lists bindkeys set up by each plugin
—— module                        – manage binary Zsh module shipped with Zinit, see \`zinit module help'
—— add-fpath|fpath ${ZINIT[col-info]}[-f|--front]${ZINIT[col-rst]} \\
    ${ZINIT[col-pname]}plg-spec ${ZINIT[col-info]}[subdirectory]${ZINIT[col-rst]}      – adds given plugin directory to \$fpath; if the second argument is given, it is appended to the directory path; if the option -f/--front is given, the directory path is prepended instead of appended to \$fpath. The ${ZINIT[col-pname]}plg-spec${ZINIT[col-rst]} can be absolute path
—— run [-l] [plugin] {command}   – runs the given command in the given plugin's directory; if the option -l will be given then the plugin should be skipped – the option will cause the previous plugin to be reused"

    integer idx
    local type key
    local -a arr
    for type in subcommand hook; do
        for (( idx=1; idx <= ZINIT_EXTS[seqno]; ++ idx )); do
            key="${(k)ZINIT_EXTS[(r)$idx *]}"
            [[ -z "$key" || "$key" != "z-annex $type:"* ]] && continue
            arr=( "${(Q)${(z@)ZINIT_EXTS[$key]}[@]}" )
            (( ${+functions[${arr[6]}]} )) && { "${arr[6]}"; ((1)); } || \
                { print -rl -- "(Couldn't find the help-handler \`${arr[6]}' of the z-annex \`${arr[3]}')"; }
        done
    done

print "
Available ice-modifiers:
        svn proto from teleid bindmap cloneopts id-as depth if wait load
        unload blockf on-update-of subscribe pick bpick src as ver silent
        lucid notify mv cp atinit atclone atload atpull nocd run-atpull has
        cloneonly make service trackbinds multisrc compile nocompile
        nocompletions reset-prompt wrap-track reset aliases sh bash ksh csh
        countdown trigger-load light-mode is-snippet atdelete pack git extract
        param"
} # ]]]

# vim:ft=zsh:sw=4:sts=4:et:foldmarker=[[[,]]]
