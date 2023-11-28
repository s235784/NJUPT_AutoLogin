# -*- coding: utf-8 -*-
# @Time    : 2023/11/7
# @Author  : NuoTian
# @Version : 1.0.0
# @Repo    : https://github.com/s235784/NJUPT_AutoLogin

# 南京邮电大学自动登录脚本
# 适用于 RouterOS v7.11.2 及以上版本
# 在 Python 3.8 及以上版本通过测试

import argparse
import contextlib
import datetime
import json
import logging
import ssl
import sys
import urllib.error
import urllib.request
import routeros_api.exceptions


def check_network(url):
    try:
        with contextlib.closing(urllib.request.urlopen(url, timeout=5)) as response:
            responseContent = response.read().decode("utf-8")
            return "10.10.244.11" not in responseContent
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

        with contextlib.closing(urllib.request.urlopen(url, context=ssl_context, timeout=5)) as response:
            if response.getcode() == 200:
                content_ = response.read().decode('utf-8')
                return "成功" in content_, content_
            else:
                return False, None
    except urllib.error.URLError as urlError:
        return False, str(urlError)


config_path = "./config.json"
parser = argparse.ArgumentParser(description="南京邮电大学校园网自动登录脚本")
parser.add_argument("-c", "--config", type=str, help="配置文件路径")
parser.add_argument("-l", "--level", type=str, help="日志输出等级 debug/info/error")
args = parser.parse_args()
if args.config:
    config_path = args.config

level = logging.DEBUG
if args.level:
    if args.level == "debug":
        level = logging.DEBUG
    elif args.level == "info":
        level = logging.INFO
    elif args.level == "error":
        level = logging.ERROR

logging.basicConfig(level=level, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

logger.debug(f"配置文件路径 {config_path}")

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

weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
current_weekday_text = weekdays[current_weekday]
logger.debug(f"当前时间 {current_weekday_text} {current_time}")

with open(config_path, "r", encoding="UTF-8") as config_file:
    config_json = json.load(config_file)

    os_ip = config_json["routeros"]["ip"]
    os_username = config_json["routeros"]["username"]
    os_password = config_json["routeros"]["password"]
    connection = routeros_api.RouterOsApiPool(os_ip, username=os_username, password=os_password, plaintext_login=True)
    try:
        api = connection.get_api()
    except routeros_api.exceptions.RouterOsApiCommunicationError as routerError:
        logger.error("RouterOS账号或密码错误！")
        logger.error(routerError)
        sys.exit(1)
    except routeros_api.exceptions.RouterOsApiConnectionError as routerError:
        logger.error("无法连接到RouterOS，请检查配置文件中的IP地址！")
        logger.error(routerError)
        sys.exit(1)

    addresses_list = api.get_resource("/ip/address").get()
    config_login = config_json["login"]
    for login in config_login:
        for address in addresses_list:
            interface = address["interface"]
            if interface == login["ether"]:
                # 判断是否在能登录的时间内
                if login["time_limit"] and not time_flag:
                    logger.debug(f"{interface} 不在允许登录的时间段内")
                    continue

                # 检查网口网络状态
                if "https://" in login["test_address"]:
                    logger.warning("使用HTTPS站点检测网络状态可能导致结果不准确！")
                if check_network(login["test_address"]):
                    logger.debug(f"{interface} 网络正常")
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

                logger.debug(f"{interface} 开始登录，账号：{username}, 密码：{password}，运营商：{login['isp']}")
                flag, content = login_network(ether_ip, isp, username, password)
                if flag:
                    logger.info(f"{interface} 登录成功")
                elif content is not None:
                    logger.error(f"{interface} 登录失败 {content}")
                else:
                    logger.error(f"{interface} 登录失败")
