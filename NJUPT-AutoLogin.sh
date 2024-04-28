#!/usr/bin/env bash

#     _   _     _ _   _ ____ _____
#    | \ | |   | | | | |  _ \_   _|
#    |  \| |_  | | | | | |_) || |
#    | |\  | |_| | |_| |  __/ | |
#    |_| \_|\___/ \___/|_|    |_|
#
#        _         _        _                _
#       / \  _   _| |_ ___ | |    ___   __ _(_)_ __
#      / _ \| | | | __/ _ \| |   / _ \ / _` | | '_ \
#     / ___ \ |_| | || (_) | |__| (_) | (_| | | | | |
#    /_/   \_\__,_|\__\___/|_____\___/ \__, |_|_| |_|
#                                      |___/
#
#    Example of usage:
#    bash NJUPT-AutoLogin.sh -i en0 -o ctcc -t 2 B21012250 12345678
#
#     _   _             _______  _
#    |  \| | _   _   ___  | |    _   __ _  _ __
#    | . ` || | | | / _ \ | |   | | / _` || '_ \
#    |_| \_| \__,_| \___/ |_|   |_| \__,_||_| |_|
#
#    Author: NuoTian (https://github.com/s235784)
#    Repository: https://github.com/s235784/NJUPT_AutoLogin
#    Version: 1.1.3 (Refactorized and added macOS support by BlockLune)

# ANSI color and style codes
BOLD=$(printf '\033[1m')
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
RESET=$(printf '\033[0m')

login_id=""
login_pw=""
operator="ctcc"
interface="en0"
timeout=2
time_limited_account=0
logout_flag=1

println_error() {
	local error_message="$1"
	printf "%s%sERROR%s:\t%s\n" "$BOLD" "$RED" "$RESET" "$error_message"
}

println_ok() {
	local ok_message="$1"
	printf "%s%sOKAY%s:\t%s\n" "$BOLD" "$GREEN" "$RESET" "$ok_message"
}

println_warning() {
	local warning_message="$1"
	printf "%s%sWARN%s:\t%s\n" "$BOLD" "$YELLOW" "$RESET" "$warning_message"
}
println_info() {
	local info_message="$1"
	printf "%s%sINFO%s:\t%s\n" "$BOLD" "$BLUE" "$RESET" "$info_message"
}

help() {
	printf "Auto login script for NJUPT Wi-Fi.\n"
	printf "Author: NuoTian (https://github.com/s235784)"
	printf "\n"
	printf "Usage: %s [-i interface] [-o operator] [-t timeout] [-p ipv4_addr] [-m] [-n] [-h] login_id login_password\n" "$0"
	printf "Options:\n"
	printf "\t-i interface\tSpecify the network interface. Default is '%s'.\n" "$interface"
	printf "\t-o operator\tSpecify the operator. Default is '%s'.\n" "$operator"
	printf "\t-t timeout\tSpecify the timeout for ping. Default is %d seconds.\n" "$timeout"
	printf "\t-p ipv4_addr\tSpecify the IPv4 address. By default it will be detacted automatically.\n"
	printf "\t-m\t\tSwitch to logout mode. Default is %d (0 for ON, 1 for OFF).\n" "$logout_flag"
	printf "\t-n\t\tSwitch to not time limited account. Default is %d (0 for LIMITED, 1 for NOT).\n" "$time_limited_account"
	printf "\t-h\t\tShow this help message.\n"
	printf "Arguments:\n"
	printf "\tlogin_id\tThe user ID.\n"
	printf "\tlogin_password\tThe user password.\n"
	exit 0
}

turn_on_wifi_and_connect_mac() {
	println_info "Trying to trun on Wi-Fi..."
	networksetup -setairportpower "$interface" on
	if [[ "$operator" == "ctcc" ]]; then
		println_info "Your operator is China Telecom."
		networksetup -setairportnetwork "$interface" "NJUPT-CHINANET"
	elif [[ "$operator" == "cmcc" ]]; then
		println_info "Your operator is China Mobile."
		networksetup -setairportnetwork "$interface" "NJUPT-CMCC"
	elif [[ "$operator" == "njupt" ]]; then
		println_info "Your operator is NJUPT."
		networksetup -setairportnetwork "$interface" "NJUPT"
	else
		println_error "Invalid operator. Please specify 'ctcc', 'cmcc' or 'njupt'."
		exit 1
	fi
}

turn_on_wifi_and_connect_linux() {
	println_info "Trying to trun on Wi-Fi..."
	if command -v nmcli >/dev/null 2>&1; then
		if [[ "$operator" == "ctcc" ]]; then
			println_info "Your operator is China Telecom."
			nmcli dev wifi connect "NJUPT-CHINANET"
		elif [[ "$operator" == "cmcc" ]]; then
			println_info "Your operator is China Mobile."
			nmcli dev wifi connect "NJUPT-CMCC"
		elif [[ "$operator" == "njupt" ]]; then
			println_info "Your operator is NJUPT."
			nmcli dev wifi connect "NJUPT"
		else
			println_error "Invalid operator. Please specify 'ctcc', 'cmcc' or 'njupt'."
			exit 1
		fi
	else
		println_warning "Command \`nmcli\` unavailable. Stopped trying."
	fi
}

# TODO: It's better to also check ssid
# TODO: to make sure the specific Wi-Fi is connected.
is_wifi_on() {
	local result
	if [[ "$(uname)" == "Darwin" ]]; then
		result=$(networksetup -getairportpower "$interface" | grep "On")
	elif [[ "$(uname)" == "Linux" ]]; then
		if command -v nmcli >/dev/null 2>&1; then
			result=$(nmcli radio wifi | grep "enable")
		else
			println_warning "Command \`nmcli\` unavailable. Stopped trying."
		fi
	fi
	if [[ -n $result ]]; then
		return 0
	else
		return 1
	fi
}

# the prefix `get` means you can get the value by using $()
get_ip_address() {
	local ip_type="$1"
	if [ "$ip_type" == "ipv4" ]; then
		ifconfig "$interface" | grep 'inet ' | awk '{print $2}' | head -n 1 | sed 's/addr://'
	elif [ "$ip_type" == "ipv6" ]; then
		ifconfig "$interface" | grep 'inet6 ' | grep -v 'fe80::' | awk '{print $2}' | head -n 1 | sed 's/addr://'
	else
		println_error "Invalid IP type. Please specify 'ipv4' or 'ipv6'."
		return 1
	fi
}

# the prefix `generate` means you can't get the value by using $()
# the values are stored in global variables
# TODO: This function gets both ipv4 and ipv6 addresses.
# TODO: However the login API currently only use ipv4 address.
# TODO: There is an option in the API to use ipv6 address,
# TODO: called `wlan_user_ipv6`.
# TODO: So the ipv6 address may be used in the future.
generate_ip_addresses() {
	println_info "Trying to obtain IP addresses..."

	# get ipv4 address
	ipv4_addr=$(get_ip_address "ipv4")
	if [[ -n $ipv4_addr ]]; then
		println_ok "IPv4 address ($ipv4_addr) obtain successfully!"
	else
		println_warning "IPv4 address not found on $interface!"
	fi

	# get ipv6 address
	ipv6_addr=$(get_ip_address "ipv6")
	if [[ -n $ipv6_addr ]]; then
		println_ok "IPv6 address ($ipv6_addr) obtain successfully!"
	else
		println_warning "IPv6 address not found on $interface!"
	fi

	if [[ -z $ipv4_addr ]] && [[ -z $ipv6_addr ]]; then
		println_error "No IP addresses found on $interface!"
		exit 1
	fi
}

generate_user_account() {
	println_info "Generating user_account..."
	if [[ "$operator" == "ctcc" ]]; then
		println_info "Your operator is China Telecom."
		user_account="%2C0%2C${login_id}%40njxy"
	elif [[ "$operator" == "cmcc" ]]; then
		println_info "Your operator is China Mobile."
		user_account="%2C0%2C${login_id}%40cmcc"
	elif [[ "$operator" == "njupt" ]]; then
		println_info "Your operator is NJUPT."
		user_account="%2C0%2C${login_id}"
	else
		println_error "Invalid operator. Please specify 'ctcc', 'cmcc' or 'njupt'."
		exit 1
	fi
	println_ok "user_account ($user_account) generated."
}

generate_user_password() {
	println_info "Generating user_password..."
	user_password=$login_pw
	println_ok "user_password ($user_password) generated."
}

login_the_wifi() {
	generate_user_account
	generate_user_password
	if [[ -z $ipv4_addr ]]; then
		generate_ip_addresses
	else
		println_info "Using the specified IPv4 address: $ipv4_addr"
	fi
	response=$(curl --interface "$interface" -s -k --request GET "https://10.10.244.11:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=$user_account&user_password=$user_password&wlan_user_ip=$ipv4_addr")
	if [[ "$response" =~ "成功" ]]; then
		println_ok "Login successful!"
	else
		println_error "Login failed!"
		println_info "Response: $response\n"
	fi
}

logout_the_wifi() {
	if [[ -z $ipv4_addr ]]; then
		generate_ip_addresses
	else
		println_info "Using the specified IPv4 address: $ipv4_addr"
	fi
	response=$(curl --interface "$interface" -s -k --request GET "https://10.10.244.11:802/eportal/portal/logout?callback=dr1003&login_method=1&wlan_user_ip=$ipv4_addr")

	if [[ "$response" =~ "成功" ]]; then
		println_ok "Logout successful!"
	else
		println_error "Logout failed!"
		println_info "Response: $response\n"
	fi
}

check_time() {
	local week
	week=$(date +%w)

	local time
	time=$(date +%H%M)

	# Monday to Thursday
	if [[ "$week" -ge 1 ]] && [[ "$week" -le 4 ]]; then
		# 7:01 to 23：29
		if [[ "$((10#$time))" -ge 701 ]] && [[ "$((10#$time))" -le 2329 ]]; then
			return 0
		fi
		# Friday
	elif [[ "$week" -eq 5 ]]; then
		# After 7:01
		if [[ "$((10#$time))" -ge 701 ]]; then
			return 0
		fi
		# Saturday
	elif [[ "$week" -eq 6 ]]; then
		return 0
		# Sunday
	elif [[ "$week" -eq 0 ]]; then
		# Before 23:29
		if [[ "$((10#$time))" -le 2329 ]]; then
			return 0
		fi
	fi

	return 1
}

is_internet_connectable() {
	ping -c 1 -W "$timeout" baidu.com &>/dev/null
}

is_running_on_openwrt() {
	if [[ -f "/etc/os-release" ]]; then
		# shellcheck source=/dev/null
		. /etc/os-release
		if [[ "$NAME" == "OpenWrt" ]] || [[ "$NAME" == "ImmortalWrt" ]]; then
			return 0
		fi
	fi
	return 1
}

main() {
	if [[ "$(uname)" != "Darwin" ]] && [[ "$(uname)" != "Linux" ]]; then
		println_error "This script is not running on macOS or Linux."
		exit 1
	fi

	if [[ "$(uname)" == "Darwin" ]]; then
		println_ok "This script is running on macOS."
	elif [[ "$(uname)" == "Linux" ]]; then
		println_ok "This script is running on Linux."
	fi

	if [[ $logout_flag -eq 0 ]]; then
		logout_the_wifi
		exit 0
	fi

	println_info "Parsing the options..."
	println_info "User ID: ${BOLD}$login_id${RESET}"
	println_info "User Password: ${BOLD}$login_pw${RESET}"
	println_info "Operator: ${BOLD}$operator${RESET}"
	println_info "Interface: ${BOLD}$interface${RESET}"
	if [[ -n $ipv4_addr ]]; then
		println_info "IPv4 Address: ${BOLD}$ipv4_addr${RESET}"
	fi
	if [[ $time_limited_account -eq 0 ]]; then
		println_info "Account Type: ${BOLD}LIMITED${RESET}"
	else
		println_info "Account Type: ${BOLD}NOT LIMITED${RESET}"
	fi
	if [[ $logout_flag -eq 0 ]]; then
		println_info "Logout flag: ${BOLD}ON${RESET}"
	else
		println_info "Logout flag: ${BOLD}OFF${RESET}"
	fi

	if is_running_on_openwrt; then
		println_info "Running on OpenWrt. Skipping Wi-Fi check."
	else
		if is_wifi_on; then
			println_ok "Wi-Fi is on."
		else
			println_info "Trying to turn on Wi-Fi..."
			if [[ "$(uname)" == "Darwin" ]]; then
				turn_on_wifi_and_connect_mac
			elif [[ "$(uname)" == "Linux" ]]; then
				turn_on_wifi_and_connect_linux
			fi
			is_wifi_on
			if [[ $? -eq 1 ]]; then
				println_warning "Failed to turn on Wi-Fi automatically."
			fi
		fi
	fi

	if is_internet_connectable; then
		println_ok "Successfully connected to the Internet."
	else
		if [[ $time_limited_account -eq 0 ]]; then
			println_info "Time limited account. Checking the time..."
			if check_time; then
				println_ok "Time is within the range."
			else
				println_error "Time is out of range."
				exit 1
			fi
		fi
		
		login_the_wifi
		is_internet_connectable
		if [[ $? -eq 1 ]]; then
			println_error "Failed to connect to the Internet."
		fi
	fi
}

# init options
# must be done before calling main
while getopts ':i:o:t:p:mnh' OPT; do
	case $OPT in
	i) interface="$OPTARG" ;;
	o) operator="$OPTARG" ;;
	t) timeout="$OPTARG" ;;
	p) ipv4_addr="$OPTARG" ;;
	m) logout_flag=0 ;;          # mode
	n) time_limited_account=1 ;; # not time limited
	h) help ;;
	:)
		println_error "Option -$OPTARG requires an argument."
		exit 1
		;;
	\?) help ;;
	esac
done
shift $((OPTIND - 1))
login_id=$1
login_pw=$2
if [[ -z $login_id ]] || [[ -z $login_pw ]]; then
	if [[ $logout_flag -ne 0 ]]; then
		println_error "Please specify the user ID and password."
		help
	fi
fi
main
