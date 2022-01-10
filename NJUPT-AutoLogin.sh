#!/bin/sh

# 脚本使用格式 如bash NJUPT-AutoLogin.sh eth0.2 ctcc B21012250 12345678

# eth口
eth=$1

# 运营商 校园网为njupt，电信为ctcc，移动为cmcc
isp=$2

# 账号
name=$3

# 密码
passwd=$4

login=

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

	curl "http://10.10.244.11:801/eportal/?c=ACSetting&a=Login&protocol=http:&hostname=10.10.244.11&iTermType=1&wlanuserip=${ip}&wlanacip=10.255.252.150&wlanacname=XL-BRAS-SR8806-X&mac=00-00-00-00-00-00&ip=${ip}&enAdvert=0&queryACIP=0&loginMethod=1" \
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
	fi
# 周五
elif [ "$week" -eq 5 ]
then
	# 8：10之后
	if [ "$time" -ge 0810 ]
	then
			printf "允许时间内，开始准备登录\n"
			start
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
	fi
fi

printf "完成\n"
