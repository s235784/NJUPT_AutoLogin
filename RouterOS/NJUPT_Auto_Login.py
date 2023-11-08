# -*- coding: utf-8 -*-
# @Time    : 2023/11/7
# @Author  : NuoTian
# @Version : 1.0.0

# 南京邮电大学自动登录脚本
# 适用于 RouterOS v7.11.2 及以上版本
# 在 Python 3.8 上通过测试

import sys
import ssl
import json
import argparse
import datetime
import contextlib
import routeros_api
import urllib.request


def check_network(url):
    try:
        with contextlib.closing(urllib.request.urlopen(url, timeout=5)) as response:
            return response.getcode() <= 300
    except urllib.error.URLError:
        return False


def login_network(ip_, isp_, username_, password_):
    account = f",0,{username_}{isp_}"
    url = (f"https://10.10.244.11:802/eportal/portal/login?callback=dr1003&login_method=1"
           f"&user_account={account}&user_password={password_}&wlan_user_ip={ip_}"
           f"&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=")
    try:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        with contextlib.closing(urllib.request.urlopen(url, timeout=5)) as response:
            if response.getcode() == 200:
                content = response.read().decode('utf-8')
                return "成功" in content, content
            else:
                return False, None
    except urllib.error.URLError as e:
        return False, str(e)


config_path = "./config.json"
parser = argparse.ArgumentParser(description="南京邮电大学校园网自动登录脚本")
parser.add_argument("-c", "--config", type=str, help="配置文件路径")
args = parser.parse_args()
if args.config:
    config_path = args.config

print(f"配置文件路径 {config_path}")

time_flag = False

start_time = datetime.time(7, 1)
end_time = datetime.time(23, 29)

current_datetime = datetime.datetime.now()
current_weekday = current_datetime.weekday()
current_time = current_datetime.time()
if 0 <= current_weekday <= 3:  # 周一至周四
    if start_time <= current_time <= end_time:  # 7：01到23：29之间
        time_flag = True
elif current_weekday == 4:  # 周五
    if start_time <= current_time:  # 7：01之后
        time_flag = True
elif current_weekday == 5:  # 周六 全天
    time_flag = True
elif current_weekday == 6:  # 周日
    if current_time <= end_time:  # 23：29之前
        time_flag = True

with open(config_path, "r", encoding="UTF-8") as config_file:
    config_json = json.load(config_file)

    os_ip = config_json["routeros"]["ip"]
    os_username = config_json["routeros"]["username"]
    os_password = config_json["routeros"]["password"]
    connection = routeros_api.RouterOsApiPool(os_ip, username=os_username, password=os_password, plaintext_login=True)
    try:
        api = connection.get_api()
    except routeros_api.exceptions.RouterOsApiCommunicationError as e:
        print("RouterOS的账号或密码错误！", e)
        sys.exit(1)

    addresses_list = api.get_resource("/ip/address").get()
    config_login = config_json["login"]
    for login in config_login:
        for address in addresses_list:
            interface = address["interface"]
            if interface == login["ether"]:
                # 判断是否在能登录的时间内
                if login["time_limit"] and not time_flag:
                    print(f"{interface} 不在允许登录的时间段内")
                    continue

                # 检查网口网络状态
                if check_network(login["test_address"]):
                    print(f"{interface} 网络正常")
                    continue

                # 去除IP后面的掩码部分
                ether_ip = address["address"]
                slash_index = ether_ip.find("/")
                if slash_index != -1:
                    ether_ip = ether_ip[:slash_index]

                isp = ""
                if login["isp"] == "ctcc":
                    isp = "@njxy"
                elif login["isp"] == "cmcc":
                    isp = "@cmcc"

                username = login["username"]
                password = login["password"]

                flag, content = login_network(ether_ip, isp, username, password)
                if flag:
                    print(f"{interface} 成功登录")
                elif content is not None:
                    print(f"{interface} 登录失败", content)
                else:
                    print(f"{interface} 登录失败")
