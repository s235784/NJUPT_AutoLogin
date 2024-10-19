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
#    bash NJUPT-AutoLogin.sh -i en0 -I ctcc -t 2 B21012250 12345678
#
#     _   _             _______  _
#    |  \| | _   _   ___  | |    _   __ _  _ __
#    | . ` || | | | / _ \ | |   | | / _` || '_ \
#    |_| \_| \__,_| \___/ |_|   |_| \__,_||_| |_|
#
#    Author: NuoTian (https://github.com/s235784)
#    Repository: https://github.com/s235784/NJUPT_AutoLogin
#    Version: 1.1.4
#    Refactorized and added macOS support by BlockLune
#    Experimental SSID recognition and IPv6 support added by SteveXu9102

# Terminal check for colored output
if [[ -t 1 ]]; then
  # ANSI color and style codes
  BOLD=$(printf '\033[1m')
  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  BLUE=$(printf '\033[34m')
  RESET=$(printf '\033[0m')
else
  BOLD=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
fi

sysenv="$(uname)"
verbose_mode=1
login_id=""
login_pw=""
isp="ctcc"
interface="en0"
timeout=2
time_limited_account=0
logout_flag=1
loginv6=1

print_success() {
	printf "%s%s\t ######  ##     ##  ######   ######  ########  ######   ###### %s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t##    ## ##     ## ##    ## ##    ## ##       ##    ## ##    ##%s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t##       ##     ## ##       ##       ##       ##       ##      %s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t ######  ##     ## ##       ##       ######    ######   ###### %s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t      ## ##     ## ##       ##       ##             ##       ##%s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t##    ## ##     ## ##    ## ##    ## ##       ##    ## ##    ##%s%s\n" "$BOLD" "$GREEN" "$RESET"
	printf "%s%s\t ######   #######   ######   ######  ########  ######   ###### %s%s\n" "$BOLD" "$GREEN" "$RESET"
}

print_fail() {
	printf "%s%s\t########    ###    #### ##       ######## ######## %s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t##         ## ##    ##  ##       ##       ##     ##%s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t##        ##   ##   ##  ##       ##       ##     ##%s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t######   ##     ##  ##  ##       ######   ##     ##%s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t##       #########  ##  ##       ##       ##     ##%s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t##       ##     ##  ##  ##       ##       ##     ##%s%s\n" "$BOLD" "$RED" "$RESET"
	printf "%s%s\t##       ##     ## #### ######## ######## ######## %s%s\n" "$BOLD" "$RED" "$RESET"
}

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
	printf "Auto login script for NJUPT campus network.\n"
	printf "Author: NuoTian (https://github.com/s235784)"
	printf "\n"
	printf "Usage: %s [-i interface] [-I isp] [-t timeout] [-p ipv4_addr] [-6] [-m] [-n] [-h] [-v] login_id login_password\n" "$0"
	printf "Options:\n"
	printf "\t-i interface\tSpecify the network interface. Default is '%s'.\n" "$interface"
	printf "\t-I isp\tSpecify ISP. Default is '%s'.\n" "$isp"
	printf "\t-t timeout\tSpecify the timeout for connectivity tests. Default is %d seconds.\n" "$timeout"
	printf "\t-p ipv4_addr\tSpecify the IPv4 address. By default it will be detected automatically.\n"
	printf "\t-6\t\tattempt to recover IPv6 availability using CERNET IPv6 address. Default is %d (0 for ON, 1 for OFF).\n" "$loginv6"
	printf "\t-m\t\tSwitch to logout mode. Default is %d (0 for ON, 1 for OFF).\n" "$logout_flag"
	printf "\t-n\t\tSwitch to time unlimited account. Default is %d (0 for LIMITED, 1 for NOT).\n" "$time_limited_account"
	printf "\t-h\t\tShow this help message.\n"
	printf "\t-v\t\tVerbose mode. Default is %d (0 for ON, 1 for OFF).\n" "$verbose_mode"
	printf "Arguments:\n"
	printf "\tlogin_id\tThe user ID.\n"
	printf "\tlogin_password\tThe user password.\n"
	exit 0
}

enable_wlan_and_connect_mac() {
	println_info "Trying to enable Wi-Fi..."
	networksetup -setairportpower "$interface" on
	if [[ "$isp" == "ctcc" ]]; then
		println_info "Your ISP is China Telecom."
		networksetup -setairportnetwork "$interface" "NJUPT-CHINANET"
	elif [[ "$isp" == "cmcc" ]]; then
		println_info "Your ISP is China Mobile."
		networksetup -setairportnetwork "$interface" "NJUPT-CMCC"
	elif [[ "$isp" == "njupt" ]]; then
		println_info "Your ISP is NJUPT."
		networksetup -setairportnetwork "$interface" "NJUPT"
	else
		println_error "Invalid ISP. Please specify 'ctcc', 'cmcc' or 'njupt'."
		println_error "The script will exit with no changes made."
		exit 1
	fi
}

enable_wlan_and_connect_linux() {
	println_info "Trying to enable Wi-Fi..."
	if command -v nmcli >/dev/null 2>&1; then
		if [[ "$isp" == "ctcc" ]]; then
			println_info "Your ISP is China Telecom."
			nmcli dev wifi connect "NJUPT-CHINANET"
		elif [[ "$isp" == "cmcc" ]]; then
			println_info "Your ISP is China Mobile."
			nmcli dev wifi connect "NJUPT-CMCC"
		elif [[ "$isp" == "njupt" ]]; then
			println_info "Your ISP is NJUPT."
			nmcli dev wifi connect "NJUPT"
		else
			println_error "Invalid ISP. Please specify 'ctcc', 'cmcc' or 'njupt'."
			println_error "The script will exit with no changes made."
			exit 1
		fi
	else
		println_warning "Command \`nmcli\` unavailable. Stopped trying."
	fi
}

wlan_status() {
	local result
	if [[ "$sysenv" == "Darwin" ]]; then
		result=$(networksetup -getairportpower "$interface" | grep "On")
	elif [[ "$sysenv" == "Linux" ]]; then
		if command -v nmcli >/dev/null 2>&1; then
			result=$(nmcli radio wifi | grep "enable")
			if [[ $? -eq 0 ]]; then
        		println_ok "Wi-Fi is enabled."
    		else
        		println_error "Failed to enable Wi-Fi."
    		fi
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

# Experimental SSID extraction feature
ssid_extract() {
	if [[ "$sysenv" == "Darwin" ]]; then
		ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep SSID | awk -F': ' '{print $2}' | grep 'NJUPT')
	elif [[ "$sysenv" == "Linux" ]]; then
		if command -v nmcli >/dev/null 2>&1; then
			ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '/^yes/{if($2 ~ /NJUPT/) print $2}')
		else
			println_warning "Command \`nmcli\` unavailable. Cannot get SSID."
			ssid="N/A"
		fi
	fi
	if [[ -z "$ssid" ]]; then
		println_warning "Cannot get SSID."
		ssid="N/A"
	fi
	if [[ "$ssid" == "NJUPT-CHINANET" ]]; then
		ssid="ctcc"
	fi
	if [[ "$ssid" == "NJUPT-CMCC" ]]; then
		ssid="cmcc"
	fi
	if [[ "$ssid" == "NJUPT" ]]; then
		ssid="njupt"
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
generate_ip_address() {
	println_info "Trying to obtain IP addresses..."

	# get ipv4 address
	ipv4_addr=$(get_ip_address "ipv4")
	if [[ -n $ipv4_addr ]]; then
		println_ok "IPv4 address '$ipv4_addr' obtained successfully!"
	else
		println_warning "IPv4 address not found on $interface!"
	fi

	# get ipv6 address
	ipv6_addr=$(get_ip_address "ipv6")
	if [[ "$ipv6_addr" != "" ]]; then
		println_ok "IPv6 address '$ipv6_addr' obtained successfully!"
	else
		println_warning "IPv6 address not found on $interface!"
	fi

	if [[ -z $ipv4_addr ]] && [[ -z $ipv6_addr ]]; then
		println_error "No IP addresses found on $interface!"
		println_error "The script will exit with no changes made."
		exit 1
	fi
}

generate_account_password() {
	println_info "Generating account & password parameters..."
	if [[ "$isp" == "ctcc" ]]; then
		println_info "Your ISP is China Telecom."
		user_account="%2C0%2C${login_id}%40njxy"
	elif [[ "$isp" == "cmcc" ]]; then
		println_info "Your ISP is China Mobile."
		user_account="%2C0%2C${login_id}%40cmcc"
	elif [[ "$isp" == "njupt" ]]; then
		println_info "Your ISP is NJUPT."
		user_account="%2C0%2C${login_id}"
	else
		println_error "Invalid ISP. Please specify 'ctcc', 'cmcc' or 'njupt'."
		println_error "The script will exit with no changes made."
		exit 1
	fi
	println_ok "URL account parameters: $user_account"
	user_password=$login_pw
	println_ok "URL password parameters: $user_password"
}

network_login() {
	generate_account_password
	if [[ -z $ipv4_addr ]]; then
		generate_ip_address
	else
		println_info "Using the specified IPv4 address: $ipv4_addr"
	fi
	response=$(curl --interface "$interface" -s -k --request GET "https://10.10.244.11:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=$user_account&user_password=$user_password&wlan_user_ip=$ipv4_addr")
	if [[ "$response" =~ "成功" ]]; then
		println_ok "Login successful!"
	else
		println_error "Login failed!"
		println_info "Response: $response"
	fi
}

network_logout() {
	if [[ -z $ipv4_addr ]]; then
		generate_ip_address
	else
		println_info "Using the specified IPv4 address: $ipv4_addr"
	fi
	# Line below clears the CERNET IPv6 logged-in status.
	response6=$(curl --interface "$interface" -k -s -X GET "http://192.168.168.168/F.htm" | iconv -f GB18030 -t UTF-8)
	response=$(curl --interface "$interface" -k -s --request GET "https://10.10.244.11:802/eportal/portal/logout?callback=dr1003&login_method=1&wlan_user_ip=$ipv4_addr")

	if [[ "$response" =~ "成功" ]] && [[ -n "$response6" ]]; then
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

# Modified test method:
# Using `curl` to improve accuracy.
connectivity_test() {
	local test_type="$1"
	if [[ "$test_type" == "v4" ]]; then
		if curl --interface "$interface" -k -s --max-time $timeout -X GET "ipinfo.io/ip" | grep "10.10.244.11" &>/dev/null; then
			return 1
		else
			return 0
		fi
	elif [[ "$test_type" == "v6" ]]; then
		if curl --interface "$interface" -6 -k -s --max-time $timeout -X GET "6.ipw.cn" &>/dev/null; then
			return 0
		fi
	fi
	return 1
}

check_openwrt() {
	if [[ -f "/etc/os-release" ]]; then
		# shellcheck source=/dev/null
		. /etc/os-release
		if [[ "$NAME" == "OpenWrt" ]] || [[ "$NAME" == "ImmortalWrt" ]]; then
			return 0
		fi
	fi
	return 1
}

# Temporary solution to recover IPv6 availability.
# Using CERNET IPv6 address.
ipv6_login() {
	ipv6_addr=$(ifconfig "$interface" | grep -Eo '2001:da8.+(/| )' | sed 's/\/.*//g')
	
	if [[ -n $ipv6_addr ]]; then
		println_ok "CERNET IPv6 address '$ipv6_addr' detected."

		login_attempt=$(curl --interface "$interface" -s -k -X POST -d "DDDDD=$login_id&upass=$login_pw&0MKKey=%%B5%%C7%%C2%%BC+Sign+in&v6ip=" "192.168.168.168/0.htm" | iconv -f GB18030 -t UTF-8 | grep -o "成功登录")
		# The first-time network request through IPv6 after logging in is always annoyingly
		# redirected to http://192.168.168.168/1.htm , presuming the program that initiates
		# the connection follows redirects. The 'curl -L' used here is to skip this process.
		curl --interface "$interface" -s -k -L -X GET "6.ipw.cn" &>/dev/null 
		

		if [[ "$login_attempt" == "成功登录" ]]; then
			println_ok "CERNET IPv6 login success."
			println_info "Please note that IPv6 connections established in this way ARE CHARGED SEPARATELY."
			println_info "For account balance information, please check http://192.168.168.168/1.htm ."

			if connectivity_test "v6"; then
				println_ok "IPv6 connectivity test success."
			else
				println_warning "IPv6 connectivity test failed."
			fi
			
		else
			println_warning "CERNET IPv6 login failed."
		fi

	else
		println_error "No CERNET IPv6 address found on $interface."
	fi
}

main() {
	if [[ "$verbose_mode" == 0 ]]; then
		set -x
	fi

	if [[ "$sysenv" != "Darwin" ]] && [[ "$sysenv" != "Linux" ]]; then
		println_error "This script is not running on macOS or Linux."
		println_error "The script will exit with no changes made."
		exit 1
	fi

	if [[ "$sysenv" == "Darwin" ]]; then
		println_ok "This script is running on macOS."
	elif [[ "$sysenv" == "Linux" ]]; then
		println_ok "This script is running on Linux."
	fi

	if [[ $logout_flag -eq 0 ]]; then
		network_logout
		println_info "The script will exit."
		exit 0
	fi

	println_info "Parsing the options..."
	println_info "User ID: ${BOLD}$login_id${RESET}"
	println_info "User Password: ${BOLD}$login_pw${RESET}"
	println_info "ISP: ${BOLD}$isp${RESET}"
	println_info "Interface: ${BOLD}$interface${RESET}"
	if [[ -n $ipv4_addr ]]; then
		println_info "IPv4 Address: ${BOLD}$ipv4_addr${RESET}"
	fi
	println_info "Account Type: ${BOLD}$( [ $time_limited_account -eq 0 ] && echo 'LIMITED' || echo 'UNLIMITED' )${RESET}"
	println_info "Logout flag: ${BOLD}$( [ $logout_flag -eq 0 ] && echo 'ON' || echo 'OFF' )${RESET}"
	println_info "CERNET IPv6 login: ${BOLD}$( [ $loginv6 -eq 0 ] && echo 'ON' || echo 'OFF' )${RESET}"

	if check_openwrt; then
		println_info "Running on OpenWrt. Skipping Wi-Fi check."
	else
		if wlan_status; then
			println_ok "Wi-Fi is on."
			ssid_extract
			if [[ "$ssid" != "$isp" ]] && [[ "$ssid" != "N/A" ]]; then
				println_warning "Mismatch detected between WiFi SSID and command line ISP arguments."
				println_warning "Trying to log in anyway."
			fi
		else
			println_info "Trying to enable Wi-Fi..."
			if [[ "$sysenv" == "Darwin" ]]; then
				enable_wlan_and_connect_mac
			elif [[ "$sysenv" == "Linux" ]]; then
				enable_wlan_and_connect_linux
			fi
			wlan_status
			if [[ $? -eq 1 ]]; then
				println_warning "Failed to enable Wi-Fi automatically."
			else
				ssid_extract
				if [[ "$ssid" != "$isp" ]] && [[ "$ssid" != "N/A" ]]; then
					println_warning "Mismatch detected between WiFi SSID and command line ISP arguments."
					println_warning "Trying to log in anyway."
				fi
			fi
		fi
	fi

	if connectivity_test "v4"; then
		println_ok "Successfully connected to the Internet."
		print_success
		if [[ $loginv6 -eq 0 ]]; then
			println_info "Recovering IPv6 availability..."
			ipv6_login
		fi
	else
		if [[ $time_limited_account -eq 0 ]]; then
			println_info "Time limited account. Checking the time..."
			if check_time; then
				println_ok "Time is within the range."
			else
				println_error "Time is out of range."
				println_error "The script will exit with no changes made."
				exit 1
			fi
		fi
		network_login
		
		if connectivity_test "v4"; then
			println_ok "Successfully connected to the Internet."
			print_success
			if [[ $loginv6 -eq 0 ]]; then
				println_info "Recovering IPv6 availability..."
				ipv6_login
			fi
		else
			println_error "Failed to connect to the Internet."
			print_fail
		fi
	fi
	println_info "All jobs done. The script will exit."
	set +x
	exit 0
}

# init options
# must be done before calling main
while getopts ':i:I:t:p:6mnhv' OPT; do
	case $OPT in
	i) interface="$OPTARG" ;;
	I) isp="$OPTARG" ;;
	t) timeout="$OPTARG" ;;
	p) ipv4_addr="$OPTARG" ;;
	6) loginv6=0 ;;
	m) logout_flag=0 ;;          # mode
	n) time_limited_account=1 ;; # not time limited
	h) help ;;
	v) verbose_mode=0 ;;
	:)
		println_error "Option -$OPTARG requires an argument."
		println_error "The script will exit with no changes made."
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
