# NJUPT_AutoLogin RouterOS

适用于 RouterOS v7.11.2 及以上版本；在 Python 3.8 及以上版本通过测试。

目前脚本只能运行在**能访问 RouterOS 管理界面的设备**上或使用 RouterOS 的 Docker 容器插件，目前暂不支持直接运行在 RouterOS 上。

适用于 Linux/MacOS 平台的使用教程请 [移步这里](./README.md)

## 使用方法

> [!WARNING]
> 脚本会获取系统时间来判断当前时间是否是可上网时间，进而判断是否要尝试登录，所以错误的系统时间可能导致脚本无法正常运行。建议首先校准系统时间。

1. 下载 RouterOS/NJUPT_Auto_Login.py 和 RouterOS/config.json
2. 检查本地时间，设置正确的时区
```Shell
date
timedatectl set-timezone Asia/Shanghai
```
3. 创建虚拟环境，并启用
```Shell
mkdir ~/NJUPT-AutoLogin
cd ~/NJUPT-AutoLogin

python3 -m venv ./venv
source ./venv/bin/activate
```
4. 安装 Python 依赖。
```Shell
pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple routeros_api
```
5. 把 NJUPT_Auto_Login.py 和 config.json 上传到NJUPT-AutoLogin目录下
6. 修改 config.json 内的配置信息，各参数参考下方说明
7. 退出虚拟环境，并检查脚本是否能正常运行（使用绝对路径避免上下文问题）
```Shell
deactivate

/root/NJUPT-AutoLogin/venv/bin/python /root/NJUPT-AutoLogin/NJUPT_Auto_Login.py -c "/root/NJUPT-AutoLogin/config.json" -l "debug"
```
8. 添加 Crontab 定时任务
```Shell
crontab -e
```
```crontab
*/8 * * * * /root/NJUPT-AutoLogin/venv/bin/python /root/NJUPT-AutoLogin/NJUPT_Auto_Login.py -c "/root/NJUPT-AutoLogin/config.json" -l "error" >> /var/log/NJUPT-AutoLogin.log 2>&1
```

选项表：

| 选项             | 名称       | 默认值          | 备注                           |
| --------------- | ---------- | -------------- | ----------------------------- |
| `-c` `--config` | 配置文件目录 | `./config.json`|                               |
| `-l` `--level`  | 输出日志等级 | `debug`        | 可用取值`debug` `info` `error` |

配置文件：

```JSON
{
  "login": [
    {
      "test_address": "http://connect.rom.miui.com/generate_204",  // 用于检测连通性的地址，建议使用HTTP
      "ether": "eth0",  // 对应 RouterOS 的 interface 名称
      "isp": "njupt",  // 登录的运营商，可选 校园网"njupt" 电信"cmcc" 移动"ctcc"
      "username": "B01010101",  // 校园网账号
      "password": "123456789",  // 校园网密码
      "time_limit": true  // 账号是否晚上会断网
    },
    {  // 添加更多的账号以实现多播
       // ……
    }
  ],
  "routeros": {
    "ip": "192.168.0.1",  // RouterOS 管理地址
    "username": "admin",  // RouterOS 账号
    "password": ""  // RouterOS 密码
  }
}
```

## License

```license
 Copyright 2021, NuoTian

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```
