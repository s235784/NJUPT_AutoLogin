#!/bin/sh

#     _   _             _______  _
#    |  \| | _   _   ___  | |    _   __ _  _ __
#    | . ` || | | | / _ \ | |   | | / _` || '_ \
#    |_| \_| \__,_| \___/ |_|   |_| \__,_||_| |_|
#
#    Author: NuoTian (https://github.com/s235784)
#    Version: 1.0.3

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

help() {
  echo "登录命令："
  echo "NJUPT-AutoLogin.sh [-e eth] [-i isp] [-l] [-s] username password"
  echo "退出命令："
  echo "NJUPT-AutoLogin.sh [-e eth] [-s] -o"
  echo "参数描述："
  echo "eth，路由器ETH口"
  echo "isp，运营商 校园网为njupt，电信为ctcc，移动为cmcc"
  echo "l，仅在规定时间内尝试自动登录"
  echo "s，三牌楼校区须添加此参数"
  echo "username，账号"
  echo "password，密码"
  exit 0
}

logout() {
  ip=$(ifconfig "${eth}" | grep inet | awk '{print $2}' | tr -d "addr:")
	if [ ! "$ip" ]
	then
		printf "获取ip地址失败\n"
		exit 0
	else
		printf "当前设备的ip地址为${ip}\n"
	fi
  curl "http://10.10.244.11:801/eportal/?c=ACSetting&a=Logout&wlanuserip=${ip}&wlanacip=${wlanacip}0&wlanacname=${wlanacname}&hostname=10.10.244.11&queryACIP=0"
  printf "已退出校园网登录\n"
  exit 0
}

while getopts 'e:i:lsoh' OPT; do
    case $OPT in
        e) eth="$OPTARG";;
        i) isp="$OPTARG";;
        l) limit="true";;
        s) wlanacip="10.255.253.118"
           wlanacname="SPL-BRAS-SR8806-X";;
        o) logout;;
        h) help;;
        ?) help;;
    esac
done

shift $(($OPTIND - 1))

# 账号
name=$1

# 密码
passwd=$2

echo "eth口：$eth"
echo "运营商："$isp
echo "账号：$name"
echo "密码：$passwd"
echo "账号是否会断网：$limit"
echo ""

# 检测网络连接畅通
network()
{
  status=$(curl -s -m 2 -IL baidu.com)
  http_code=$(echo "${status}"|grep "200")
  connection=$(echo "${status}"|grep "close")

  if [ "$http_code" = "" ]
  then
    printf "网络断开了\n"
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

	ip=$(ifconfig "${eth}" | grep inet | awk '{print $2}' | tr -d "addr:")
	if [ ! "$ip" ]
	then
		printf "获取ip地址失败\n"
		exit 0
	else
		printf "当前设备的ip地址为${ip}\n"
	fi

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

	curl "http://10.10.244.11:801/eportal/?c=ACSetting&a=Login&protocol=http:&hostname=10.10.244.11&iTermType=1&wlanuserip=${ip}&wlanacip=${wlanacip}&wlanacname=${wlanacname}&mac=00-00-00-00-00-00&ip=${ip}&enAdvert=0&queryACIP=0&loginMethod=1" \
	--data "DDDDD=${login}&upass=${passwd}&R1=0&R2=0&R3=0&R6=0&para=00&0MKKey=123456&buttonClicked=&redirect_url=&err_flag=&username=&password=&user=&cmd=&Login=&v6ip="

	printf "登录成功\n"
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

checkTime() {
  week=$(date +%w)
  time=$(date +%H%M)

  # 周一至周四
  if [ "$week" -ge 1 ] && [ "$week" -le 4 ]
  then
  	# 8：10到23点之间
  	if [ "$time" -ge 0810 ] && [ "$time" -le 2300 ]
  	then
  			printf "允许时间内，开始准备登录\n"
  			start
    else
        printf "不在允许时间内\n"
  	fi
  # 周五
  elif [ "$week" -eq 5 ]
  then
  	# 8：10之后
  	if [ "$time" -ge 0810 ]
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
  	# 23点之前
  	if [ "$time" -le 2300 ]
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
