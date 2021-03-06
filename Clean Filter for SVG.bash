#!/usr/bin/env bash
# A filter program to cleanup contents in an SVG image that is considered useless
# 林博仁(Buo-ren, Lin) <Buo.Ren.Lin@gmail.com> © 2019

# NOTE: ALWAYS PRINT MESSAGES TO STDERR as output to stdout will contaminate the input files when the program is operate in filter mode.

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set \
    -o errexit \
    -o errtrace \
    -o nounset \
    -o pipefail

## Runtime Dependencies Checking
declare \
    runtime_dependency_checking_result=still-pass \
    required_software

for required_command in \
    basename \
    dirname \
    mktemp \
    realpath \
    xmlstarlet; do
    if ! command -v "${required_command}" &>/dev/null; then
        runtime_dependency_checking_result=fail

        case "${required_command}" in
            basename | \
                cat | \
                dirname | \
                mktemp | \
                realpath)
                required_software='GNU Coreutils'
                ;;
            *)
                required_software="${required_command}"
                ;;
        esac

        printf -- \
            'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n' \
            "${required_software}" \
            1>&2
        unset required_software
    fi
done
unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
    printf -- \
        'Error: Runtime dependency checking fail, the progrom cannot continue.\n' \
        1>&2
    exit 1
fi
unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v 'BASH_SOURCE[0]' ]; then
    RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
    RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
    RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
    RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
    # We intentionally leaves these variables for script developers
    # shellcheck disable=SC2034
    declare -r \
        RUNTIME_EXECUTABLE_PATH \
        RUNTIME_EXECUTABLE_FILENAME \
        RUNTIME_EXECUTABLE_NAME \
        RUNTIME_EXECUTABLE_DIRECTORY \
        RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_ARGUMENTS=("${@}")

## Global Variables
### Temporary file used in converter mode
### This parameter will be dropped in exit trap as we need to clean the temporary file
declare converter_intermediate_file

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init() {
    local flag_converter_mode=false
    local -a input_files=()
    local indentation_style=spaces
    local -i indentation_space_width=4

    if ! process_commandline_arguments \
        flag_converter_mode \
        input_files \
        indentation_style \
        indentation_space_width; then
        printf -- \
            'Error: Invalid command-line parameters.\n' \
            1>&2

        printf '\n' 1>&2 # separate error message and help message
        print_help
        exit 1
    fi

    case "${flag_converter_mode}" in
        false)
            # Filter mode
            printf -- \
                '%s: Cleaning SVG markup...\n' \
                "${RUNTIME_EXECUTABLE_NAME}" \
                1>&2
            pass_over_filter \
                "${indentation_style}" \
                "${indentation_space_width}"
            ;;
        true)
            converter_intermediate_file="$(
                mktemp \
                    --tmpdir \
                    --suffix=.xml \
                    "${RUNTIME_EXECUTABLE_NAME}.XXXX"
            )"

            for input_file in "${input_files[@]}"; do
                printf -- \
                    '%s: Cleaning "%s"...\n' \
                    "${RUNTIME_EXECUTABLE_NAME}" \
                    "${input_file}" \
                    1>&2
                pass_over_filter \
                    "${indentation_style}" \
                    "${indentation_space_width}" \
                    <"${input_file}" \
                    >"${converter_intermediate_file}"
                cp \
                    --force \
                    "${converter_intermediate_file}" \
                    "${input_file}"
            done
            unset input_file
            ;;
        *)
            printf -- \
                "FATAL: Shouldn't be here, report bug.\\n" \
                1>&2
            exit 1
            ;;
    esac

    exit 0
}
declare -fr init

print_help() {
    # Backticks in help message is Markdown's <code> markup
    # BASH_MANUAL: Basic Shell Features > Shell Commands > Compound Commands > Grouping Commands
    # shellcheck disable=SC2016
    {
        printf '# Help Information for %s #\n' \
            "${RUNTIME_COMMANDLINE_BASECOMMAND}"
        printf '## SYNOPSIS ##\n'
        printf '### Filter Mode(default) ###\n'
        printf "Pipe the SVG file's content to the filter and save the cleaned file from stdout using shell's I/O redirection feature.  The following example assumes that you're using Bourn-compatible shell.\\n\\n"

        printf '    `cat _svg_file_ | "%s" _command-line_options_ > _cleaned_svg_file`\n\n' \
            "${RUNTIME_COMMANDLINE_BASECOMMAND}"

        printf '### Converter Mode ###\n'
        printf 'This mode allows you to use the filter as an converter, to clean the file you specified in the command-line option IN-PLACE.  No backups will be made and the origin content will be replaced.\n\n'

        printf '    `"%s" --converter _svg_file_ ...`\n\n' \
            "${RUNTIME_COMMANDLINE_BASECOMMAND}"

        printf '## COMMAND-LINE OPTIONS ##\n'
        printf '### `-d` / `--debug` ###\n'
        printf 'Enable script debugging\n\n'

        printf '### `-h` / `--help` ###\n'
        printf 'Print this message\n\n'

        printf '### `--converter` / `-C` ###\n'
        printf 'Operate in converter mode instead of filter mode, accept non-option arguments as input files\n\n'

        printf '### `--` ###\n'
        printf 'Signals that further command-line arguments are all input files\n\n'
    } 1>&2
    return 0
}
declare -fr print_help

process_commandline_arguments() {
    local -n flag_converter_mode_ref="${1}"
    shift
    local -n input_files_ref="${1}"
    shift
    local -n indentation_style_ref="${1}"
    shift
    # Indirect reference
    # shellcheck disable=SC2034
    local -n indentation_space_width_ref="${1}"
    shift

    if [ "${#RUNTIME_COMMANDLINE_ARGUMENTS[@]}" -eq 0 ]; then
        return 0
    fi

    # Modifyable parameters for parsing by consuming
    local -a parameters=("${RUNTIME_COMMANDLINE_ARGUMENTS[@]}")

    # Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer its activation till returning(Y: Do debug)
    local enable_debug=N

    local \
        flag_indentation_style_specified=false \
        flag_indentation_space_width_specified=false

    while true; do
        if [ "${#parameters[@]}" -eq 0 ]; then
            break
        else
            case "${parameters[0]}" in
                --debug | \
                    -d)
                    enable_debug=Y
                    ;;
                --help | \
                    -h)
                    print_help
                    exit 0
                    ;;
                --converter | \
                    -C)
                    flag_converter_mode_ref=true
                    ;;
                --indentation-style*)
                    flag_indentation_style_specified=true
                    if test "${parameters[0]}" = --indentation-style; then
                        if test "${#parameters[@]}" -eq 1; then
                            printf -- \
                                '%s: Error: %s option requires one argument!\n' \
                                "${FUNCNAME[0]}" \
                                "${parameters[0]}" \
                                1>&2
                            return 1
                        fi
                        indentation_style_ref="${parameters[1]}"
                        # shift array by 1 = unset 1st then repack
                        unset 'parameters[0]'
                        if [ "${#parameters[@]}" -ne 0 ]; then
                            parameters=("${parameters[@]}")
                        fi
                    else
                        indentation_style_ref="$(
                            cut \
                                --delimiter== \
                                --fields=2 \
                                <<<"${parameters[0]}"
                        )"
                    fi
                    ;;
                --indentation-space-width*)
                    flag_indentation_space_width_specified=true
                    if test "${parameters[0]}" = --indentation-space-width; then
                        if test "${#parameters[@]}" -eq 1; then
                            printf -- \
                                '%s: Error: %s option requires one argument!\n' \
                                "${FUNCNAME[0]}" \
                                "${parameters[0]}" \
                                1>&2
                            return 1
                        fi
                        indentation_space_width_ref="${parameters[1]}"
                        # shift array by 1 = unset 1st then repack
                        unset 'parameters[0]'
                        if [ "${#parameters[@]}" -ne 0 ]; then
                            parameters=("${parameters[@]}")
                        fi
                    else
                        # Indirectly referenced
                        # shellcheck disable=SC2034
                        indentation_space_width_ref="$(
                            cut \
                                --delimiter== \
                                --fields=2 \
                                <<<"${parameters[0]}"
                        )"
                    fi
                    ;;
                --)
                    # shift array by 1 = unset 1st then repack
                    unset 'parameters[0]'
                    if [ "${#parameters[@]}" -ne 0 ]; then
                        parameters=("${parameters[@]}")
                    fi

                    input_files_ref=("${input_files_ref[@]}" "${parameters[@]}")

                    # Break out loop as all arguments are processed
                    break
                    ;;
                *)
                    # Assuming converter mode
                    input_files_ref+=("${parameters[0]}")
                    ;;
            esac
            # shift array by 1 = unset 1st then repack
            unset 'parameters[0]'
            if [ "${#parameters[@]}" -ne 0 ]; then
                parameters=("${parameters[@]}")
            fi
        fi
    done

    if test "${flag_indentation_style_specified}" = true \
        && test "${flag_indentation_space_width_specified}" = true \
        && test "${indentation_style_ref}" != spaces; then
        printf -- \
            '%s: Error: --indentation-space-width option can only specified if --indentation-style is spaces\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if test "${indentation_style_ref}" != spaces \
        && test "${indentation_style_ref}" != tabs; then
        printf -- \
            '%s: Error: Invalid --indentation-style argument.\n' \
            "${FUNCNAME[@]}" \
            1>&2
        return 1
    fi

    if [ "${flag_converter_mode_ref}" = false ] && [ "${#input_files_ref[@]}" -ne 0 ]; then
        printf -- \
            '%s: Error: Only in --converter mode can have non-option arguments.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if [ "${flag_converter_mode_ref}" = true ] && [ "${#input_files_ref[@]}" -eq 0 ]; then
        printf -- \
            '%s: Error: No input files are supplied.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if [ "${enable_debug}" = Y ]; then
        trap 'trap_return "${FUNCNAME[0]}"' RETURN
        set -o xtrace
    fi
    return 0
}
declare -fr process_commandline_arguments

pass_over_filter() {
    local indentation_style="${1}"
    shift
    local indentation_space_width="${1}"
    shift

    local temp_result_file
    temp_result_file="$(
        mktemp \
            --tmpdir \
            xmlstarlet.cleaner.XXXXXX
    )"

    cat >"${temp_result_file}"

    # Inkscape-specific info
    ## Info of the previous session
    ### Window settings
    #### Inkscape window's width and height in previous session
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:window-width'
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:window-height'

    #### Inkscape windows's location in previous session
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:window-x'
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:window-y'

    #### Inkscape windows's maximized status in previous session
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:window-maximized'

    ### Current working layer of the previous Inkscape session
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:current-layer'

    ### The zoom level of previous Inkscape session
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:zoom'

    ## Export settings
    ### Export DPI settings - Not useful in practice
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg//@inkscape:export-xdpi'
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg//@inkscape:export-ydpi'
    ### The full path of the exported picture, contains sensitive information such as absolute paths
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg//@inkscape:export-filename'

    ## Inkscape version
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/@inkscape:version'

    ## Essentially the SVG filename
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/@sodipodi:docname'

    ## File load/save settings
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/@inkscape:output_extension'

    ## Inkscape-specific page settings that is not particulary useful to be included in image, and should fallback to sensible defaults
    ### Whether or not showing a slim "shadow" at the right and bottom side of page
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:showpageshadow'
    ### Whether or not showing a grid
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:showgrid'

    ## FIXME: What is these?
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:cx'
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:cy'
    xml_remove_xpath \
        "${temp_result_file}" \
        '/_:svg/sodipodi:namedview/@inkscape:snap-nodes'

    xml_beautify_file \
        "${indentation_style}" \
        "${indentation_space_width}" \
        "${temp_result_file}"

    cat "${temp_result_file}"

    rm \
        --force \
        "${temp_result_file}"
}
declare -fr pass_over_filter

# Remove data from XML file specified by XPath
xml_remove_xpath() {
    local -r xml_file="$1"
    shift
    local -r node_xpath="$1"

    local temp_file
    temp_file="$(
        mktemp \
            --tmpdir \
            clean-filter-for-svg.XXXXXX
    )"
    local -r temp_file

    xmlstarlet \
        edit \
        --pf \
        --ps \
        --delete \
        "${node_xpath}" \
        "${xml_file}" \
        >"${temp_file}"

    mv \
        --force \
        "${temp_file}" \
        "${xml_file}"
}

# Beautify a XML file(indentation: tabular charactor, currently not adjustable)
xml_beautify_file() {
    local indentation_style="${1}"
    shift
    local indentation_space_width="${1}"
    shift
    local xml_file="$1"
    shift

    local temp_file
    temp_file="$(
        mktemp \
            --tmpdir \
            clean-filter-for-svg.XXXXXX
    )"
    local -r temp_file

    case "${indentation_style}" in
        spaces)
            xmlstarlet \
                format \
                --encode UTF-8 \
                --indent-spaces "${indentation_space_width}" \
                "${xml_file}" \
                >"${temp_file}"
            ;;
        tabs)
            xmlstarlet \
                format \
                --encode UTF-8 \
                --indent-tab \
                "${xml_file}" \
                >"${temp_file}"
            ;;
        *)
            printf -- \
                '%s: Error: Invalid indentation style %s.\n' \
                "${FUNCNAME[0]}" \
                "${indentation_style}" \
                1>&2
            return 1
            ;;
    esac

    mv \
        --force \
        "${temp_file}" \
        "${xml_file}"
}

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit() {
    printf \
        'An error occurred and the script is prematurely aborted\n' \
        1>&2
    return 0
}
declare -fr trap_errexit
trap trap_errexit ERR

trap_exit() {
    # Clean up temp files if available
    if test -v converter_intermediate_file; then
        if ! rm \
            "${converter_intermediate_file}"; then
            printf -- \
                '%s: Error: Unable to remove the temporary file.\n' \
                "${FUNCNAME[0]}" \
                1>&2
            return 1
        fi
        unset converter_intermediate_file
    fi
    return 0
}
declare -fr trap_exit
trap trap_exit EXIT

trap_return() {
    local returning_function="${1}"

    printf \
        'DEBUG: %s: returning from %s\n' \
        "${FUNCNAME[0]}" \
        "${returning_function}" \
        1>&2
}
declare -fr trap_return

trap_interrupt() {
    printf '\n' # Separate previous output
    printf \
        'Recieved SIGINT, script is interrupted.' \
        1>&2
    return 1
}
declare -fr trap_interrupt
trap trap_interrupt INT

init "${@}"
