#!/usr/bin/env bash


#------------------------------------------------------------------------------
# ANSI escape code variables.
# ------------------------------------------------------------------------------

# Usage: printf "I ${Red}love${Color_Off} Stack Overflow\n"
# If you are using the echo command, be sure to use the -e flag to allow backslash escapes.
# echo -e "I ${Red}love${Color_Off} Stack Overflow"

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White

# ------------------------------------------------------------------------------

function print_char_line {
    local filler=${1}
    printf "%`tput cols`s" | sed "s/ /${filler}/g"
    printf '\n'
}

function flatpak_get_remote_default_branch {
    local config remote

    if [[ $# -eq 2 && $1 == --user ]]; then
        config="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/repo/config"
        remote=$2
    elif [[ $# -eq 1 ]]; then
        config=/var/lib/flatpak/repo/config
        remote=$1
    else
        return 2
    fi

    [[ -r $config ]] || return 1

    awk -v wanted="$remote" '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }

        {
            line = trim($0)

            if (line ~ /^\[remote "/) {
                section = line
                sub(/^\[remote "/, "", section)
                sub(/"\]$/, "", section)
                active = (section == wanted)
                next
            }

            if (line ~ /^\[/) {
                active = 0
                next
            }

            if (active && line ~ /^xa\.default-branch[[:space:]]*=/) {
                sub(/^[^=]*=/, "", line)
                print trim(line)
                found = 1
                exit
            }
        }

        END {
            if (!found) exit 1
        }
    ' "$config"
}

# ------------------------------------------------------------------------------

# Check base package managers
declare -a required_cmds=( "flatpak" "brew" )
fail=false
for rc in "${required_cmds[@]}"; do
    if ! command -v "${rc}" &> /dev/null ; then
        printf "[${executor}] ${BRed}ERROR${Color_Off} - Command '${rc}' unavailable!?\n"
        fail=true
    fi
done
unset required_cmds
[[ "${fail}" == true ]] && exit 1

# Check flatpaks
printf "[${BWhite}chezmoi${Color_Off}] ${BBlue}INFO${Color_Off} - Check Flatpak...\n"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if flatpak_get_remote_default_branch flathub | grep -Fq stable ; then
    flatpak remote-modify --system --default-branch=stable flathub
fi

if flatpak remotes | grep -F flathub | grep -Fq user ; then
    if flatpak_get_remote_default_branch --user flathub | grep -Fq stable ; then
        flatpak remote-modify --user --default-branch=stable flathub
    fi
fi

flatpak update -y

# Check homebrew
echo && print_char_line '-'
printf "[${BWhite}chezmoi${Color_Off}] ${BBlue}INFO${Color_Off} - Check Homebrew...\n"
brew update --force && brew upgrade -y

# Check password manager(s)
echo && print_char_line '-'
printf "[${BWhite}chezmoi${Color_Off}] ${BBlue}INFO${Color_Off} - Checking password managers...\n"
declare -a password_managers=( "org.keepassxc.KeePassXC" "com.bitwarden.desktop" )
for pm in "${password_managers[@]}"; do
    printf "[${BWhite}chezmoi${Color_Off}] ${BBlue}INFO${Color_Off} - ${pm} -> "
    if ! flatpak list --app --columns=application | grep -Fq "${pm}" ; then
        printf "${BYellow}INSTALLING${Color_Off}\n"
        flatpak install --or-update -y "${pm}"
    else
        printf "${BGreen}PRESENT${Color_Off}\n"
    fi
done

# Check gext
echo && print_char_line '-'
printf "[${BWhite}chezmoi${Color_Off}] ${BBlue}INFO${Color_Off} - Checking gnome-extensions-cli (gext) -> "
# gnome-extensions-cli
if ! command -v gext &> /dev/null ; then
    printf "${BYellow}INSTALLING${Color_Off}\n"
    brew exec --formulae uv -- uv tool install gnome-extensions-cli
else
    printf "${BGreen}PRESENT${Color_Off}\n"
fi

echo && print_char_line '='
