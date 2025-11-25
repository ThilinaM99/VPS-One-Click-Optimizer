#!/bin/bash
# 
# VPS OPtimizer Bash Script
# Author: github.com/opiran-club
#
# For more information and updates, visit github.com/opiran-club and @opiranclub on telegram.

set -o pipefail

CYAN="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
BLUE="\e[94m"
MAGENTA="\e[95m"
WHITE="\e[97m"
NC="\e[0m"
BOLD=$(tput bold)

# Logging function
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper function to check if command exists
_exists() {
    command -v "$1" >/dev/null 2>&1
}
check_qdisc_support() {
    local algorithm="$1"

    if tc qdisc add dev lo root "$algorithm" 2>/dev/null; then
        echo && echo -e "$GREEN $algorithm is supported by your kernel. $NC"
        # Remove the test qdisc immediately
        tc qdisc del dev lo root 2>/dev/null
        return 0
    else
        echo && echo -e "$RED $algorithm is not supported by your kernel. $NC"
        return 1
    fi
}
ask_bbr_version_1() {
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    echo && echo -e "${YELLOW}Installing and configuring BBRv1 + FQ...${NC}"
    sed -i '/^net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/^net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
        if [ $? -eq 0 ]; then
            echo && echo -e "${GREEN}Kernel parameter optimization for OpenVZ was successful.${NC}"
        else
            echo && echo -e "${RED}Optimization failed. Restoring original sysctl configuration.${NC}"
            mv /etc/sysctl.conf.bak /etc/sysctl.conf
        fi
}
fun_bar() {
    local title="$1"
    local command1="$2"
    local command2="$3"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        $command1 -y > /dev/null 2>&1
        $command2 -y > /dev/null 2>&1
        touch $HOME/fim
    ) &
    tput civis
    echo -ne "  ${BOLD}${YELLOW}$title${BOLD} - ${YELLOW}["
    while true; do
        for ((i = 0; i < 18; i++)); do
            echo -ne "${RED}#"
            sleep 0.1
        done
        if [[ -e "$HOME/fim" ]]; then
            rm "$HOME/fim"
            break
        fi
        echo -e "${YELLOW}]"
        sleep 0.5
        tput cuu1
        tput el 
        echo -ne "  ${BOLD}${YELLOW}$title${BOLD} - ${YELLOW}["
    done
    echo -e "${YELLOW}]${WHITE} -${GREEN} DONE!${WHITE}"
    tput cnorm
}
if [ "$EUID" -ne 0 ]; then
echo && echo -e "\n ${RED}This script must be run as root.${NC}"
exit 1
fi

sourcelist() {
    clear
    title="Source List Adjustment to Official Repositories"
    logo 
    echo ""
    echo -e "${MAGENTA}$title${NC}"
    echo ""
    echo -e "\e[93m+-------------------------------------+\e[0m"
    echo ""

    cp /etc/apt/sources.list /etc/apt/sources.list.bak || {
        echo && echo -e "${RED}Error backing up sources.list. Aborting.${NC}"
        return 1
    }

    if ! command -v jq >/dev/null 2>&1; then
        echo && echo -e "${YELLOW}jq not found, attempting to install...${NC}"
        if ! apt-get install -y jq; then
            echo && echo -e "${RED}Error installing jq. Aborting.${NC}"
            return 1
        fi
    fi

    get_release_codename() {
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            case "$ID" in
                "ubuntu")
                    release=$(lsb_release -cs)
                    ;;
                "debian")
                    release=$(lsb_release -cs)
                    ;;
                *)
                    echo && echo -e "${RED}Unsupported OS. Cannot determine release codename.${NC}"
                    return 1
                    ;;
            esac
            echo "$release"
        else
            echo && echo -e "${RED}Unable to detect OS. No changes made.${NC}"
            return 1
        fi
    }

    release=$(get_release_codename)
    if [ $? -ne 0 ]; then
        return 1
    fi

    update_ubuntu_sources() {
        local mirror_url
        if [ "$1" = "iran" ]; then
            mirror_url="http://mirror.arvancloud.ir/ubuntu"
        else
            mirror_url="http://archive.ubuntu.com/ubuntu"
        fi
        temp_file=$(mktemp)
        cat <<EOL > "$temp_file"
deb $mirror_url $release main restricted
deb $mirror_url $release-updates main restricted
deb $mirror_url $release universe
deb $mirror_url $release-updates universe
deb $mirror_url $release multiverse
deb $mirror_url $release-updates multiverse
deb $mirror_url $release-backports main restricted universe multiverse
deb $mirror_url $release-security main restricted
deb $mirror_url $release-security universe
deb $mirror_url $release-security multiverse
EOL
        mv "$temp_file" /etc/apt/sources.list || {
            echo && echo -e "${RED}Error writing to sources.list.  Changes not saved.${NC}"
            rm -f "$temp_file"
            return 1
        }
    }

    update_debian_sources() {
        local mirror_url
        local security_mirror_url
        if [ "$1" = "iran" ]; then
            mirror_url="http://mirror.arvancloud.ir/debian"
            security_mirror_url="http://mirror.arvancloud.ir/debian-security"
        else
            mirror_url="http://deb.debian.org/debian"
            security_mirror_url="http://security.debian.org/debian-security"
        fi
        temp_file=$(mktemp)
        cat <<EOL > "$temp_file"
deb $mirror_url $release main
deb $mirror_url $release-updates main
deb $mirror_url $release-backports main
deb $security_mirror_url $release-security main
EOL
        mv "$temp_file" /etc/apt/sources.list || {
            echo && echo -e "${RED}Error writing to sources.list. Changes not saved.${NC}"
            rm -f "$temp_file"
            return 1
        }
    }

    if [ -f /etc/os-release ]; then
        source /etc/os-release
        location_info=$(curl -s --max-time 5 "http://ipwho.is" 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            log_warn "Failed to fetch location information. Using default mirrors."
            location="Unknown"
        else
            public_ip=$(echo "$location_info" | jq -r '.ip // empty' 2>/dev/null)
            location=$(echo "$location_info" | jq -r '.country // empty' 2>/dev/null)
        fi
        if [[ "$location" == "Iran" ]]; then
             echo && echo -ne "${YELLOW}Location detected as ${GREEN}Iran${YELLOW}. Update sources list to Iranian mirrors? ${GREEN}[SUGGESTED Y] ${YELLOW}[y/n]: ${NC}"
        else
            echo && echo -ne "${YELLOW}Location detected as ${GREEN}$location${YELLOW}. Update sources list to default mirrors? ${GREEN}[SUGGESTED Y] ${YELLOW}[y/n]: ${NC}"
        fi
        read -r update_choice

        case $update_choice in
            [Yy]*)
                case "$ID" in
                    "ubuntu")
                        update_ubuntu_sources "$([[ "$location" == "Iran" ]] && echo "iran" || echo "non-iran")"
                        echo && echo -e "${GREEN}Ubuntu sources list updated.${NC}"
                        ;;
                    "debian")
                        update_debian_sources "$([[ "$location" == "Iran" ]] && echo "iran" || echo "non-iran")"
                        echo && echo -e "${GREEN}Debian sources list updated.${NC}"
                        ;;
                    *)
                        echo && echo -e "${RED}Unsupported OS detected. No changes made.${NC}"
                        ;;
                esac
                ;;
            [Nn]*)
                echo && echo -e "${YELLOW}Skipping sources list update.${NC}"
                ;;
            *)
                echo && echo -e "${RED}Invalid input. No changes made.${NC}"
                ;;
        esac
    else
        echo && echo -e "${RED}Unable to detect OS. No changes made.${NC}"
    fi
    press_enter
}

press_enter() {
    echo -e "\n ${MAGENTA}Press Enter to continue... ${NC}"
    read
}

ask_reboot() {
echo && echo -e "\n ${YELLOW}Reboot now? (Recommended) ${GREEN}[y/n]${NC}"
read reboot
case "$reboot" in
        [Yy]) 
        systemctl reboot
        ;;
        *) 
        return 
        ;;
    esac
exit
}
set_timezone() {
    clear
    title="Timezone Adjustment"
    logo 
    echo && printf "${MAGENTA}%s ${NC}\n" "$title"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n"
    current_timezone=$(timedatectl | awk '/Time zone/ {print $3}')
    echo && printf "${YELLOW}Your current timezone is ${GREEN}%s${NC}\n" "$current_timezone"
    
    if ! _exists curl; then
        log_error "curl is not installed. Please install curl to proceed."
        return 1
    fi
    
    if ! _exists jq; then
        log_error "jq is not installed. Please install jq to proceed."
        return 1
    fi
    
    local sources=("http://ipwho.is" "http://ip-api.com/json")
    local public_ip location timezone content
    
    for source in "${sources[@]}"; do
        content=$(curl -s --max-time 5 "$source" 2>/dev/null) || continue
        
        case "$source" in
            "http://ipwho.is")
                public_ip=$(echo "$content" | jq -r '.ip // empty' 2>/dev/null)
                location=$(echo "$content" | jq -r '.city // empty' 2>/dev/null)
                timezone=$(echo "$content" | jq -r '.timezone.id // empty' 2>/dev/null | xargs)
                ;;
            "http://ip-api.com/json")
                public_ip=$(echo "$content" | jq -r '.query // empty' 2>/dev/null)
                location=$(echo "$content" | jq -r '.city // empty' 2>/dev/null)
                timezone=$(echo "$content" | jq -r '.timezone // empty' 2>/dev/null | xargs)
                ;;
        esac
        
        if [[ -n "$location" && -n "$timezone" && -n "$public_ip" ]]; then
            break
        fi
    done
    
    if [[ -n "$location" && -n "$timezone" && -n "$public_ip" ]]; then
        printf "${YELLOW}Your public IP is ${GREEN}%s${NC}\n" "$public_ip"
        printf "${YELLOW}Your location is ${GREEN}%s${NC}\n" "$location"
        printf "${YELLOW}Your detected timezone is ${GREEN}%s${NC}\n" "$timezone"
        date_time=$(TZ="$timezone" date "+%Y-%m-%d %H:%M:%S")
        echo && printf "${YELLOW}The current date and time in your detected timezone is ${GREEN}%s${NC}\n" "$date_time"
    else
        log_warn "Failed to fetch location and timezone information from all sources."
    fi
    press_enter
}
logo1="     ______    _______    __      _______        __      _____  ___   "
logo2="    /      \  |   __  \  |  \    /       \      /  \     \    \|   \  "
logo3="   /  ____  \ (  |__)  ) |   |  |         |    /    \    |.\   \    | "
logo4="  /  /    )  )|   ____/  |   |  |_____/   )   /' /\  \   |: \   \   | "
logo5=" (  (____/  / (   /      |.  |   //      /   //  __'  \  |.  \    \.| "
logo6="  \        / /    \      /\  |\ |:  __   \  /   /  \\   \ |    \    \| "
logo7="   \_____/ (_______)    (__\_|_)|__|  \___)(___/    \___)\___|\____\) "

logo() {
echo -e "${BLUE}${logo1:0:24}${RED}${logo1:24:19}${WHITE}${logo1:43:14}${GREEN}${logo1:57}${NC}"
echo -e "${BLUE}${logo2:0:24}${RED}${logo2:24:19}${WHITE}${logo2:43:14}${GREEN}${logo2:57}${NC}"
echo -e "${BLUE}${logo3:0:24}${RED}${logo3:24:19}${WHITE}${logo3:43:14}${GREEN}${logo3:57}${NC}"
echo -e "${BLUE}${logo4:0:24}${RED}${logo4:24:19}${WHITE}${logo4:43:14}${GREEN}${logo4:57}${NC}"
echo -e "${BLUE}${logo5:0:24}${RED}${logo5:24:19}${WHITE}${logo5:43:14}${GREEN}${logo5:57}${NC}"
echo -e "${BLUE}${logo6:0:24}${RED}${logo6:24:19}${WHITE}${logo6:43:14}${GREEN}${logo6:57}${NC}"
echo -e "${BLUE}${logo7:0:24}${RED}${logo7:24:19}${WHITE}${logo7:43:14}${GREEN}${logo7:57}${NC}"
}

spin() {
    SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for i in $(seq 1 30); do
        c=${SPINNER:i%${#SPINNER}:1}
        echo -ne "${RED}${c}${NC}"
        sleep 0.1
        echo -ne "\b"
    done
}

fix_dns() {
    clear
    title="DNS Replacement"
    logo
    echo && echo -e "${MAGENTA}$title${NC}"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n"
    interface_name=$(ip -o link show | awk '/state UP/ {print $2}' | sed 's/:$//')
    if [ -z "$interface_name" ]; then
        echo && echo -e "${RED}Error: Could not determine network interface.${NC}"
        return 1
    fi
    echo && echo -e "${YELLOW}Select DNS provider:${NC}"
    echo -e "$RED 1. $CYAN Google Public DNS (8.8.8.8, 8.8.4.4)${NC}"
    echo -e "$RED 2. $CYAN Cloudflare DNS (1.1.1.1, 1.1.1.2)${NC}"
    echo -e "$RED 3. $CYAN Quad9 DNS (9.9.9.9, 149.112.112.112)${NC}"
    echo -e "$RED 4. $CYAN 403 online DNS (Iranians anti tahrim) (10.202.10.202, 10.202.10.102)${NC}"
    echo && read -p "Enter your choice (1-4): " choice
    case $choice in
        1)
            dns_servers="nameserver 8.8.8.8\nnameserver 8.8.4.4"
            ;;
        2)
            dns_servers="nameserver 1.1.1.1\nnameserver 1.1.1.2"
            ;;
        3)
            dns_servers="nameserver 9.9.9.9\nnameserver 149.112.112.112"
            ;;
        4)
            dns_servers="nameserver 10.202.10.202\nnameserver 10.202.10.102"
            ;;
        *)
            echo && echo -e "${RED}Invalid choice.${NC}"
            return 1
            ;;
    esac
    if ! command -v resolvconf >/dev/null 2>&1; then
        echo && echo -e "${YELLOW}resolvconf not found, attempting to install...${NC}"
        if ! apt-get install -y resolvconf; then
            echo && echo -e "${RED}Error installing resolvconf.${NC}"
            return 1
        fi
    fi
    if command -v resolvconf >/dev/null 2>&1; then
        echo && echo -e "${YELLOW}Using resolvconf to configure DNS...${NC}"
        echo "$dns_servers" | resolvconf -a "$interface_name"
    else
        echo && echo -e "${YELLOW}resolvconf not found, using /etc/resolv.conf...${NC}"
        rm -rf /etc/resolv.conf && touch /etc/resolv.conf
        echo "$dns_servers" > /etc/resolv.conf
    fi
    spin & SPIN_PID=$!
    wait $SPIN_PID
    echo && echo -e "${GREEN}System DNS Optimized.${NC}"
    sleep 1
    press_enter
}

complete_update() {
    clear
    title="Update and upgrade packages"
    logo
    echo && echo -e "${CYAN}$title ${NC}"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n" 
    echo && echo -e "${RED}Please wait, it might take a couple of minutes${NC}" && echo
    
    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    if ! apt-get upgrade -y; then
        log_error "Failed to upgrade packages"
        return 1
    fi
    
    apt-get autoremove -y 2>/dev/null || true
    apt-get clean -y 2>/dev/null || true
    
    echo && echo -e "${GREEN}System update & upgrade completed.${NC}"
    sleep 1
    press_enter
}
installations() {
    clear
    title="Install necessary packages"
    logo
    echo && echo -e "${MAGENTA}$title ${NC}"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n"
    echo && echo -e "${YELLOW}Please wait, it might take a while${NC}"
    apt-get install jq nload nethogs autossh ssh iperf software-properties-common apt-transport-https \
                    lsb-release ca-certificates gnupg2 bash-completion curl git unzip \
                    zip wget locales nano python3 net-tools haveged htop dnsutils iputils-ping -y
    echo && echo -e "${GREEN}Installation of useful and necessary packages completed.${NC}"
    sleep 1
    press_enter
}
swap_maker() {
    clear
    title="Setup and Configure Swap File to Boost Performance"
    logo
    echo && echo -e "${MAGENTA}$title${NC}"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n"
    
    existing_swap=$(swapon -s | awk '$1 !~ /^Filename/ {print $1}')
    if [[ -n "$existing_swap" ]]; then
        echo -e "${YELLOW}Removing existing swap files...${NC}"
        for swap_file in $existing_swap; do
            swapoff "$swap_file" || {
                echo -e "${RED}Error turning off swap: $swap_file. Skipping.${NC}"
            }
            rm -f "$swap_file" || {
                echo -e "${RED}Error removing swap file: $swap_file. Skipping.${NC}"
            }
        done
    fi
    
    while true; do
        echo && echo -e "$RED TIP! $NC"
        echo -e "$CYAN It is just a suggestion, choose 2 GB if you have enough space and 512MB < RAM < 2GB $NC"
        echo && echo -e "${YELLOW}Please select the swap file size (depends on your disk space and RAM):${NC}"
        echo -e "${RED}1.${NC} 512MB"
        echo -e "${RED}2.${NC} 1GB"
        echo -e "${RED}3.${NC} 2GB"
        echo -e "${RED}4.${NC} 4GB"
        echo -e "${RED}5.${NC} Manually enter value (e.g., 300M, 1G)"
        echo -e "${RED}6.${NC} No Swap"
        echo && read -r choice

        case $choice in
            1) swap_size="512M" ;;
            2) swap_size="1G" ;;
            3) swap_size="2G" ;;
            4) swap_size="4G" ;;
            5)
                echo -ne "${YELLOW}Please enter the swap file size (e.g., 300M for MB, 1G for GB): ${NC}" 
                read swap_size
                ;;
            6)
                echo && echo -e "${RED}No swap file will be created. Exiting...${NC}"
                return 0
                ;;
            *) 
                echo && echo -e "${RED}Invalid choice. Please try again.${NC}" 
                continue
                ;;
        esac

        if [[ "$swap_size" =~ ([0-9]+)(M|G) ]]; then
            size=${BASH_REMATCH[1]}
            unit=${BASH_REMATCH[2]}
            if [[ "$unit" == "G" ]]; then
                count=$((size * 1024))  # Convert GB to MB
            elif [[ "$unit" == "M" ]]; then
                count=$size  # Already in MB
            fi
        else
            echo -e "${RED}Invalid swap size format. Exiting...${NC}"
            return 1
        fi

        echo "Calculated swap size: $swap_size"
        echo "Calculated count in MB: $count"

        if [[ -z "$count" || $count -le 0 ]]; then
            echo -e "${RED}Invalid swap size calculated. Exiting...${NC}"
            return 1
        fi
        
        swap_file="/swapfile"
        
        # Create the swap file
        dd if=/dev/zero of="$swap_file" bs=1M count="$count" status=progress 2>&1 || {
            echo && echo -e "${RED}Error creating swap file: $swap_file. Exiting...${NC}"
            return 1
        }
        
        chmod 600 "$swap_file" || {
            echo && echo -e "${RED}Error setting permissions on swap file. Exiting...${NC}"
            return 1
        }
        
        mkswap "$swap_file" || {
            echo && echo -e "${RED}Error setting up swap space. Exiting...${NC}"
            return 1
        }
        
        swapon "$swap_file" || {
            echo && echo -e "${RED}Error enabling swap file. Exiting...${NC}"
            return 1
        }
        
        echo "$swap_file none swap sw 0 0" >> /etc/fstab || {
            echo && echo -e "${RED}Error adding swap to fstab. Manual addition required.${NC}"
        }
        
        echo && echo -e "${BLUE}Modifying swap usage threshold (vm.swappiness)...${NC}"
        echo && printf "\e[93m+-------------------------------------+\e[0m\n"
        
        swap_value=10
        sed -i "/^vm\.swappiness=/c vm.swappiness=$swap_value" /etc/sysctl.conf || {
            echo && echo -e "${RED}Error setting swappiness. Manual modification required.${NC}"
        }
        sysctl -p
        
        echo && echo -e "${GREEN}Swap file created and vm.swappiness set to ${RED}$swap_value${NC}."
        break
    done
    
    sleep 1
    press_enter
}
swap_maker_1() {
    remove_all_swap() {
    for item in $swap_files $swap_partitions; do
        swapoff "$item"
        rm -f "$item"
    done
    }
    remove_all_swap
    swap_size="512M"
    chmod 600 /swap
    mkswap /swap
    swapon /swap
    echo "/swap swap swap defaults 0 0" >> /etc/fstab
    swapon -s | grep '/swap'
    swap_value=10
    if grep -q "^vm.swappiness" /etc/sysctl.conf; then
        sed -i "s/^vm.swappiness=.*/vm.swappiness=$swap_value/" /etc/sysctl.conf
    else
        echo "vm.swappiness=$swap_value" >> /etc/sysctl.conf
    fi
    sysctl -p
}
remove_old_sysctl() {
    clear
    title=" Network Optimizing "
    logo
    echo && echo -e "${MAGENTA}$title${NC}"
    echo && echo -e "\e[93m+-------------------------------------+\e[0m"
    sed -i '/1000000/d' /etc/profile
cat <<EOL > /etc/sysctl.conf
# System Configuration Settings for Improved Performance and Security

# File limits
fs.file-max = 67108864

# Network core settings
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 32768
net.core.optmem_max = 262144
net.core.somaxconn = 65536
net.core.rmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_max = 33554432
net.core.wmem_default = 1048576

# Increase IP Fragmentation Timeout
net.ipv4.ipfrag_high_thresh = 524288
net.ipv4.ipfrag_low_thresh = 446464
net.ipv4.ipfrag_time = 60

# Memory Optimization
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500

# TCP settings
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 25
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_orphans = 819200
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mem = 65536 1048576 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 0
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_syncookies = 1

# UDP settings
net.ipv4.udp_mem = 65536 1048576 33554432

# IPv6 settings
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0

# Unix domain sockets
net.unix.max_dgram_qlen = 256

# VM settings
vm.min_free_kbytes = 65536
vm.swappiness = 10
vm.vfs_cache_pressure = 100

# Packet filtering
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# ARP settings
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# Kernel settings
kernel.printk = 4 4 1 7
kernel.panic = 1
vm.swappiness = 10
vm.dirty_ratio = 15
EOL

cat <<EOL > /etc/security/limits.conf
* soft nproc 655350
* hard nproc 655350
* soft nofile 655350
* hard nofile 655350
root soft nproc 655350
root hard nproc 655350
root soft nofile 655350
root hard nofile 655350
EOL
    sysctl -p
    echo && echo -e "${GREEN}Sysctl configuration and optimization complete.${NC}"
    press_enter
}
optimize_ssh_configuration() {
    clear
    SSH_PATH="/etc/ssh/sshd_config"
    title="Improve SSH Configuration and Optimize SSHD"
    logo
    echo && echo -e "${MAGENTA}$title${NC}\n"
    echo && echo -e "\e[93m+-------------------------------------+\e[0m\n"
    
    if [ ! -f "$SSH_PATH" ]; then
        log_error "SSH configuration file not found at ${SSH_PATH}."
        return 1
    fi
    
    # Create backup
    if ! cp "$SSH_PATH" "${SSH_PATH}.bak"; then
        log_error "Failed to create backup of SSH configuration."
        return 1
    fi
    echo && echo -e "${YELLOW}Backup of the original SSH configuration created at ${SSH_PATH}.bak${NC}"
    
    # Write optimized configuration
    cat > "$SSH_PATH" <<'EOL'
# Optimized SSH configuration for improved security and performance

Protocol 2
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ssh-rsa
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
UseDNS no
MaxSessions 10
Compression no
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 3
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no
PermitRootLogin no
Banner /etc/ssh/banner
X11Forwarding no
PrintMotd no
PrintLastLog yes
MaxAuthTries 3
LoginGraceTime 1m
MaxStartups 10:30:60
EOL
    
    # Create banner
    echo "WARNING: Unauthorized access to this system is prohibited." > /etc/ssh/banner
    
    # Validate configuration
    if ! sshd -t; then
        log_error "SSH configuration validation failed. Restoring backup."
        mv "${SSH_PATH}.bak" "$SSH_PATH"
        return 1
    fi
    
    # Restart SSH service
    if systemctl restart ssh; then
        echo && echo -e "${GREEN}SSH and SSHD configuration and optimization complete.${NC}"
    else
        log_error "Failed to restart SSH service. Restoring backup."
        mv "${SSH_PATH}.bak" "$SSH_PATH"
        return 1
    fi
    press_enter
}

# Alias for backward compatibility
remove_old_ssh_conf() {
    optimize_ssh_configuration
}

grub_tuning() {
  clear
  logo
  title="CPU Optimizing and Tuning (GRUB)"
  echo && echo -e "${MAGENTA}$title${NC}"
  echo && echo -e "\e[93m+-------------------------------------+\e[0m\n"
  cp /etc/default/grub /etc/default/grub.bak
  echo && echo -e "${YELLOW}Backup of the original grub configuration created at /etc/default/grub.bak${NC}" && echo
  modify_grub_param() {
    param="$1"
    value="$2"
    sed -i "s/^\($param\)=.*/\1=$value/" /etc/default/grub || {
      echo && echo -e "${RED}Error modifying GRUB parameter: $param${NC}"
      return 1
    }
  }
  modify_grub_param "GRUB_CMDLINE_LINUX_DEFAULT" "quiet splash"
  if ! grep -q "intel_pstate" /etc/default/grub; then
    modify_grub_param "GRUB_CMDLINE_LINUX_DEFAULT" "$(grep -oP '(?<=GRUB_CMDLINE_LINUX_DEFAULT=").*(?=")' /etc/default/grub) intel_pstate=active"
  fi
  echo && echo -e "${YELLOW}Updating GRUB configuration...${NC}"
  update-grub || {
    echo && echo -e "${RED}Error updating GRUB configuration.${NC}"
    return 1
  }
  echo && echo -e "${GREEN}GRUB configuration updated successfully!${NC}"
  echo && echo -e "${YELLOW}Reboot your system to apply the changes.${NC}"
  press_enter
}
queuing() {
    while true; do
        echo && echo -e "${CYAN}Select Queuing Algorithm${NC}"
        echo && echo -e "${RED}1. ${CYAN}FQ codel${NC}"
        echo -e "${RED}2. ${CYAN}FQ${NC}"
        echo -e "${RED}3. ${CYAN}Cake${NC}"
        echo -e "${RED}4. ${CYAN}HTB${NC}"
        echo -e "${RED}5. ${CYAN}SFQ${NC}"
        echo -e "${RED}6. ${CYAN}DDR${NC}"
        echo -e "${RED}7. ${CYAN}PFIFO FAST${NC}"
        echo && echo -ne "${YELLOW}Enter your choice [1-7 or 0 to skip]: ${NC}"
        read -r choice
        case $choice in
            1) algorithm="fq_codel";;
            2) algorithm="fq";;
            3) algorithm="cake";;
            4) algorithm="htb";;
            5) algorithm="sfq";;
            6) algorithm="ddr";;
            7) algorithm="pfifo_fast";;
            0) return 0;;
            *) echo -e "${RED}Invalid choice. Enter 1-7 or 0 to skip.${NC}"; continue;;
        esac
        if check_qdisc_support "$algorithm"; then
            echo -e "${GREEN}$algorithm will be applied after reboot.${NC}"
            return 0
        else
            echo -e "${RED}$algorithm is not supported. Please select another option.${NC}"
        fi
    done
}

ask_bbr_version() {
    clear
    title="TCP Congestion Control Optimization"
    logo
    echo ""
    echo -e "${MAGENTA}${title}${NC}"
    echo ""
    echo -e "\e[93m+-------------------------------------+\e[0m"
    echo ""
    echo -e "${RED}TIP!${NC}"
    echo -e "$GREEN FQ (Fair Queuing):${NC} Allocates bandwidth fairly among flows; good for balancing latency and throughput."
    echo -e "$GREEN FQ-CoDel:${NC} Combines fair queuing with delay management, reducing buffer bloat—suitable for VPNs and general traffic."
    echo -e "$GREEN CAKE:${NC} Manages buffer bloat and bandwidth effectively for WAN links; more CPU-intensive but great for high-latency links."
    echo -e "$GREEN SFQ (Stochastic Fairness Queuing):${NC} Simple fairness-based queuing with low overhead; works well in low-latency setups."
    echo -e "$GREEN PFIFO_FAST:${NC} Simple priority-based queuing, prioritizing critical packets; suitable for basic traffic handling."
    echo -e "$GREEN DDR (Deficit Round Robin):${NC} Balances fairness across flows; good for smooth packet delivery, though less commonly used."
    echo -e "$GREEN HTB (Hierarchical Token Bucket):${NC} Allows bandwidth control with multiple classes; ideal for shaping bandwidth distribution."
    echo ""
    echo -e "${MAGENTA}My Suggestion for VPN servers:${NC} ${GREEN}Fq_codel / sfq / cake${NC}"
    echo
    echo -e "${RED}1. ${CYAN} BBR [FQ codel / FQ / cake / Sfq / ddr / htb / pfifo fast] ${NC}"
    echo -e "${RED}2. ${CYAN} BBRv3 [XanMod kernel]${NC}"
    echo -e "${RED}3. ${CYAN} HYBLA [FQ codel / FQ / cake / Sfq / ddr / htb / pfifo fast] ${NC}"
    echo ""
    echo -e "${RED}4. ${CYAN} BBR [OpenVZ] ${NC}"
    echo -e "${RED}0. ${CYAN} Without BBR ${NC}"
    echo ""
    echo -ne "${YELLOW}Enter your choice [0-4]: ${NC}"
    read -r choice

    case $choice in
        1)
            # BBR with selected queuing algorithm
            if ! cp /etc/sysctl.conf /etc/sysctl.conf.bak; then
                log_error "Failed to backup sysctl.conf"
                return 1
            fi
            queuing
            # Apply the selected queuing algorithm and BBR settings
            sed -i '/^net.core.default_qdisc/d' /etc/sysctl.conf
            echo "net.core.default_qdisc=$algorithm" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            if ! sysctl -p; then
                log_error "Failed to apply sysctl settings. Restoring backup."
                mv /etc/sysctl.conf.bak /etc/sysctl.conf
                return 1
            fi
            echo -e "${GREEN}BBR optimization applied successfully.${NC}"
            ;;
        2)
            echo -e "${YELLOW}Installing and configuring XanMod & BBRv3...${NC}"
            if grep -Ei 'ubuntu|debian' /etc/os-release >/dev/null; then
                if bash <(curl -s --max-time 30 https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/bbrv3.sh --ipv4); then
                    echo -e "${GREEN}XanMod & BBRv3 installation was successful.${NC}"
                else
                    log_error "XanMod & BBRv3 installation failed."
                    return 1
                fi
            else
                log_error "This script is intended for Ubuntu or Debian systems only."
                return 1
            fi
            ;;
        3)
            if ! cp /etc/sysctl.conf /etc/sysctl.conf.bak; then
                log_error "Failed to backup sysctl.conf"
                return 1
            fi
            queuing
            sed -i '/^net.core.default_qdisc/d' /etc/sysctl.conf
            echo "net.core.default_qdisc=$algorithm" >> /etc/sysctl.conf
            sed -i '/^net.ipv4.tcp_congestion_control=/c\net.ipv4.tcp_congestion_control=hybla' /etc/sysctl.conf
            if ! sysctl -p; then
                log_error "Optimization failed. Restoring original sysctl configuration."
                mv /etc/sysctl.conf.bak /etc/sysctl.conf
                return 1
            fi
            echo -e "${GREEN}Kernel parameter optimization for Hybla was successful.${NC}"
            ;;
        4)
            echo -e "${YELLOW}Optimizing kernel parameters for OpenVZ BBR...${NC}"
            if [[ -d "/proc/vz" && -e /sys/class/net/venet0 ]]; then
                if ! cp /etc/sysctl.conf /etc/sysctl.conf.bak; then
                    log_error "Failed to backup sysctl.conf"
                    return 1
                fi
                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                tc qdisc add dev venet0 root fq_codel 2>/dev/null || true
                if ! sysctl -w net.ipv4.tcp_congestion_control=bbr; then
                    log_error "Optimization failed. Restoring backup."
                    mv /etc/sysctl.conf.bak /etc/sysctl.conf
                    return 1
                fi
                sysctl -p
                echo -e "${GREEN}Kernel parameter optimization for OpenVZ was successful.${NC}"
            else
                log_warn "This system is not OpenVZ or lacks venet0 support. No changes were made."
            fi
            ;;
        0)
            echo -e "${YELLOW}No TCP congestion control selected.${NC}"
            ;;
        *)
            log_error "Invalid choice. Please enter a number between 0 and 4."
            return 1
            ;;
    esac
    press_enter
}
speedtestcli() {
    clear
    title="Speedtest CLI"
    logo
    echo && echo -e "${MAGENTA}${title}${NC}"
    echo && echo -e "\e[93m+-------------------------------------+\e[0m"
    
    if ! _exists speedtest; then
        local pkg_manager=""
        local speedtest_install_script=""
        
        if _exists dnf; then
            pkg_manager="dnf"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif _exists yum; then
            pkg_manager="yum"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif _exists apt-get; then
            pkg_manager="apt-get"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
        else
            log_error "Supported package manager not found. Please install Speedtest manually."
            return 1
        fi
        
        echo -e "${YELLOW}Installing Speedtest CLI...${NC}"
        if curl -s --max-time 30 "$speedtest_install_script" | bash; then
            echo -e "${GREEN}Speedtest repository added successfully.${NC}"
        else
            log_error "Failed to add the Speedtest repository."
            return 1
        fi
        
        if ! $pkg_manager install -y speedtest; then
            log_error "Failed to install Speedtest."
            return 1
        fi
    fi
    
    if _exists speedtest; then
        echo && echo -e "${YELLOW}Running Speedtest...${NC}"
        speedtest
    else
        log_error "Speedtest is not installed."
        return 1
    fi
    press_enter
}
benchmark() {
    clear
    title="Benchmark (Network Speed Test)"
    logo
    echo && echo -e "${MAGENTA}${title}${NC}"
    echo && echo -e "\e[93m+-------------------------------------+\e[0m"
    
    if ! _exists wget; then
        echo -e "${YELLOW}Installing wget...${NC}"
        if ! apt-get install -y wget; then
            log_error "Failed to install wget."
            return 1
        fi
    fi
    
    echo && echo -e "${MAGENTA}TIP!${NC}"
    echo -e "${YELLOW}This test takes a long time. Please be patient.${NC}"
    echo && echo -e "${GREEN}Valid Regions:${NC} ${YELLOW}na, sa, eu, au, asia, africa, middle-east, india, china, iran${NC}"
    echo && echo -ne "${YELLOW}Please type the destination region: ${NC}"
    read -r location
    
    if [[ -z "$location" ]]; then
        log_warn "No region specified. Skipping benchmark."
        return 0
    fi
    
    echo -e "${YELLOW}Starting benchmark test...${NC}"
    if wget -qO- network-speed.xyz 2>/dev/null | bash -s -- -r "$location"; then
        echo && echo -e "${GREEN}Benchmark test completed successfully.${NC}"
    else
        log_error "Failed to run the benchmark test."
        return 1
    fi
    press_enter
}
final() {
    clear
    logo
    echo && echo -e "    ${MAGENTA}Your server has been fully optimized successfully!${NC}"
    printf "\e[93m+-------------------------------------+\e[0m\n" 
    echo && echo -e "${MAGENTA}Please reboot the system to apply all changes:${NC}"
    echo -e "${GREEN}  reboot${NC}"
    echo && echo -e "${MAGENTA}For more information, visit:${NC} ${GREEN}https://t.me/OPIranCluB${NC}"
    echo && printf "\e[93m+-------------------------------------+\e[0m\n" 
    echo && ask_reboot
}
while true; do
    clear
    tg_title="https://t.me/OPIranCluB"
    yt_title="youtube.com/@opiran-institute"
    logo
    echo -e "\e[93m╔═══════════════════════════════════════════════╗\e[0m"  
    echo -e "\e[93m║            \e[94mVPS OPTIMIZER                      \e[93m║\e[0m"   
    echo -e "\e[93m╠═══════════════════════════════════════════════╣\e[0m"
    echo && echo -e "${BLUE}   ${tg_title}   ${NC}"
    echo -e "${BLUE}   ${yt_title}   ${NC}"
    echo && echo -e "\e[93m+-----------------------------------------------+\e[0m" 
    echo && printf "${GREEN} 1)${NC} Optimizer (1-click)${NC}\n"
    printf "${GREEN} 2)${NC} Optimizer (step by step)${NC}\n"
    echo && printf "${GREEN} 3)${NC} Swap Management${NC}\n"
    printf "${GREEN} 4)${NC} Grub Tuning${NC}\n"
    printf "${GREEN} 5)${NC} BBR Optimization${NC}\n"
    echo && printf "${GREEN} 6)${NC} Speedtest${NC}\n"
    printf "${GREEN} 7)${NC} Benchmark VPS${NC}\n"
    echo && echo -e "\e[93m+-----------------------------------------------+\e[0m" 
    echo && printf "${GREEN} E)${NC} Exit the menu${NC}\n"
    echo && echo -ne "${GREEN}Select an option [1-7, E]: ${NC}"
    read -r choice
    
    case "$choice" in
        1)
            clear
            fun_bar "Updating and replacing DNS nameserver" fix_dns
            fun_bar "Complete system update and upgrade" complete_update
            fun_bar "Installing useful packages" installations
            fun_bar "Creating swap file with 512MB" swap_maker_1
            fun_bar "Updating sysctl configuration" remove_old_sysctl
            fun_bar "Updating and modifying SSH configuration" remove_old_ssh_conf
            ask_bbr_version
            final
            ;;
        2)
            sourcelist
            complete_update
            installations
            fix_dns
            set_timezone
            swap_maker
            remove_old_sysctl
            grub_tuning
            remove_old_ssh_conf
            ask_bbr_version
            final
            ;;
        3)
            swap_maker
            ;;
        4)
            grub_tuning
            ;;
        5)
            ask_bbr_version
            ;;
        6)
            speedtestcli
            ;;
        7)
            benchmark
            ;;        
        E|e)
            echo && echo -e "${YELLOW}Exiting VPS Optimizer...${NC}"
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please enter a valid option (1-7 or E)."
            ;;
    esac
    
    if [[ "$choice" != "E" && "$choice" != "e" ]]; then
        echo && echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read -r
    fi
done
