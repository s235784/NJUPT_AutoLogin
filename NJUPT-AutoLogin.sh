#!/bin/sh

#     _   _             _______  _
#    |  \| | _   _   ___  | |    _   __ _  _ __
#    | . ` || | | | / _ \ | |   | | / _` || '_ \
#    |_| \_| \__,_| \___/ |_|   |_| \__,_||_| |_|
#
#    Author: NuoTian (https://github.com/s235784)
#    Repository: https://github.com/s235784/NJUPT_AutoLogin
#    Version: 1.1.2

# 脚本使用格式 如bash NJUPT-AutoLogin.sh -e eth0.2 -i ctcc -l B21012250 12345678

# eth口
eth="eth0.1"

# 运营商 校园网为njupt，电信为ctcc，移动为cmcc
isp="njupt"

# 是否只能在规定时间内联网
limit="false"

# 仙林校区
wlanacip="10.255.252.150"

wlanacname="XL-BRAS-SR8806-X"

# 忽略未插入网线的错误状态
ignore_disconnet="false"

logout_flag="false"

help() {
  echo "登录命令："
  echo "NJUPT-AutoLogin.sh [-e eth] [-i isp] [-p ip] [-l] [-s] [-d] username password"
  echo "登出命令："
  echo "NJUPT-AutoLogin.sh [-e eth] [-p ip] [-s] -o"
  echo "参数描述："
  echo "eth，路由器ETH口"
  echo "isp，运营商 校园网为njupt，电信为ctcc，移动为cmcc"
  echo "ip，手动指定向登录接口发送的IP地址"
  echo "l，仅在规定时间内尝试自动登录"
  echo "s，三牌楼校区须添加此参数"
  echo "d，忽略网线未插入的错误状态"
  echo "username，账号"
  echo "password，密码"
  exit 0
}

# 获取设备IP地址
ip() {
  if [ ! "$ip" ]
	then
    ip=$(ifconfig "${eth}" | grep "inet " | awk '{print $2}' | tr -d "addr:")
    if [ ! "$ip" ]
  	then
  		printf "获取ip地址失败\n"
  		exit 0
    fi
	fi
  printf "当前设备的ip地址为${ip}\n"
}

# 退出登录
logout() {
  ip
  result=$(curl -k --request GET "https://10.10.244.11:802/eportal/portal/logout?callback=dr1003&login_method=1&user_account=drcom&user_password=123&wlan_user_ip=${ip}&&wlan_user_ipv6=&waln_vlan_id=0&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=" \
  --connect-timeout 5 \
  --interface ${eth})
  printf "\n"
  if [[ $result =~ "成功" ]]
  then
    printf "已退出校园网登录\n"
  else
    printf "接口请求错误：${result}\n如果问题持续出现，请在GitHub上提交Issue\n"
  fi
  exit 0
}

while getopts 'e:i:p:lsdoh' OPT; do
    case $OPT in
        e) eth="$OPTARG";;
        i) isp="$OPTARG";;
        p) ip="$OPTARG";;
        l) limit="true";;
        s) wlanacip="10.255.253.118"
           wlanacname="SPL-BRAS-SR8806-X";;
        d) ignore_disconnet="true";;
        o) logout_flag="true";;
        h) help;;
        ?) help;;
    esac
done

if [ "$logout_flag" = "true" ]
then
  ip
  logout
fi

shift $(($OPTIND - 1))

# 账号
name=$1

# 密码
passwd=$2

echo "eth口：$eth"
echo "运营商：$isp"
echo "账号：$name"
echo "密码：$passwd"
echo "账号是否会断网：$limit"

if [ "$ip" ]
then
  echo "指定的IP地址：$ip"
fi

echo ""

# 检测网络连接畅通
network()
{
  status=$(curl --interface ${eth} -s -m 2 -IL baidu.com)
  # 请求直接返回空
  if [ "$status" = "" ]
  then
    printf "无法判断网络状态，尝试登录\n"
    return 0
  fi

  http_code=$(echo "${status}"|grep "200")
  connection=$(echo "${status}"|grep "close")

  if [ "$http_code" = "" ]
  then
    printf "网络已断开\n"

    if [ "${ignore_disconnet}" = "true" ]
    then
      printf "已设置忽略该错误，继续登录命令\n"
      if [ "$connection" = "" ]
      then
        # 网络通畅
        return 1
      else
        # 未登录
        return 0
      fi
    fi

    exit 0
  fi

  if [ "$connection" = "" ]
  then
    # 网络通畅
    return 1
  else
    # 未登录
    return 0
  fi
}

# 登录校园网
loginNet() {
	if [ ! "$eth" ]
	then
		printf "eth不能为空\n"
		exit 0
	fi

	if [ ! "$isp" ]
	then
		printf "运营商不能为空\n"
		exit 0
	fi

	if [ ! "$name" ]
	then
		printf "用户名不能为空\n"
		exit 0
	fi

	if [ ! "$passwd" ]
	then
		printf "密码不能为空\n"
		exit 0
	fi

	ip

	if [ "$isp" = "ctcc" ]
	then
	   printf "运营商为电信\n"
		 login="%2C0%2C${name}%40njxy"
	elif [ "$isp" = "cmcc" ]
	then
	   printf "运营商为移动\n"
		 login="%2C0%2C${name}%40cmcc"
	elif [ "$isp" = "njupt" ]
	then
	   printf "运营商为校园网\n"
		 login="%2C0%2C${name}"
	 else
		 printf "无法识别运营商\n"
		 exit 0
	fi

	result=$(curl -k --request GET "https://10.10.244.11:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=${login}&user_password=${passwd}&wlan_user_ip=${ip}&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=" \
  --connect-timeout 5 \
  --interface ${eth})
  printf "\n"
  if [[ $result =~ "成功" ]]
  then
    printf "已成功登录校园网\n"
  else
    printf "接口请求错误：${result}\n如果问题持续出现，请在GitHub上提交Issue\n"
  fi
}

# 开始登录
start() {
	network
	if [ $? -eq 0 ]
	then
		loginNet
	else
		printf "网络正常，无需登录\n"
	fi
}

# 检查当前时间
checkTime() {
  week=$(date +%w)
  time=$(date +%H%M)

  # 周一至周四
  if [ "$week" -ge 1 ] && [ "$week" -le 4 ]
  then
  	# 7：01到23：29之间
  	if [ "$time" -ge 0701 ] && [ "$time" -le 2329 ]
  	then
  			printf "允许时间内，开始准备登录\n"
  			start
    else
        printf "不在允许时间内\n"
  	fi
  # 周五
  elif [ "$week" -eq 5 ]
  then
  	# 7：01之后
  	if [ "$time" -ge 0701 ]
  	then
  			printf "允许时间内，开始准备登录\n"
  			start
    else
        printf "不在允许时间内\n"
  	fi
  # 周六全天
  elif [ "$week" -eq 6 ]
  then
  	printf "允许时间内，开始准备登录\n"
  	start
  # 周日
  elif [ "$week" -eq 0 ]
  then
  	# 23：29之前
  	if [ "$time" -le 2329 ]
  	then
  			printf "允许时间内，开始准备登录\n"
  			start
    else
        printf "不在允许时间内\n"
  	fi
  fi
}

if [ "$limit" = "false" ]
then
  printf "没有时间限制，开始准备登录\n"
  start
else
  checkTime
fi

printf "完成\n"
