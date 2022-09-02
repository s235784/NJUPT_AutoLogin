# NJUPT_AutoLogin
南京邮电大学 自动登录校园网脚本，适合挂在路由器上定时执行

**如果脚本不能正常运行，欢迎提交Issue和PR，一起完善这个脚本**

>  本脚本更详细的教程请移步到[我的博客](https://nuotian.furry.pro/blog/archives/204#header-id-4)中查看
>
>  **注意** 脚本会获取系统时间来判断当前是否还没断网，所以系统时间不准可能会导致不能正常触发脚本。建议在配置脚本之前先校准系统时间；且在配置完成之后路由器一直插上电，避免系统时间重置。（应该也花不了很多的电费 手动滑稽）

## 脚本参数

| 参数 | 名称                 | 默认值 | 介绍                                  |
| ---- | -------------------- | ------ | ------------------------------------- |
| -e   | eth口                | eth0.1 |                                       |
| -i   | 运营商               | njupt  | 校园网为njupt，电信为ctcc，移动为cmcc |
| -l   | 是否有时间限制       |        | 添加参数后会仅在非断网时间内执行      |
| -s   | 为三牌楼校区         |        | 三牌楼校区须加上（仙林校区不用）      |
| -d   | 忽略未插入网线的错误 |        | 配置单线多拨时须加上                  |
| -h   | 显示帮助菜单         |        |                                       |
| -o   | 退出校园网           |        |                                       |

## 用法

### 硬件准备

* 一台刷了第三方固件的路由器（如OpenWRT）

### 配置脚本

首先下载[Release](https://github.com/s235784/NJUPT_AutoLogin/releases)中的脚本，然后上传到路由器中。
进入路由器后台，记住首页出现的**IPv4 WAN 状态**中的**eth口**，如 我这里是eth0.2。

![1](https://raw.githubusercontent.com/s235784/NJUPT_AutoLogin/main/doc/1.png)

然后在路由器的计划任务中添加以下命令，并根据实际情况修改这条命令。

```
*/5 * * * * sh /xxx/NJUPT-AutoLogin.sh -e eth口 -i 运营商 (-l) (-s) 账号 密码
```

> **注意**
>
> * **/xxx/NJUPT-AutoLogin.sh** 更换成脚本实际的路径
> * **eth口** 更换成上一步中相应的值
> * **账号** 就是校园网登录界面输入的账号
> * **密码** 建议使用" "将密码括起来，避免出现奇怪的错误
> * **运营商** 请看下表
> * **-l** 可选参数，如果你的账号晚上会断网就需要加上；反之删去
> * **-s** 可选参数，如果是三牌楼校区须加上

| 运营商 | 替换成 |
| ------ | ------ |
| 校园网 | njupt  |
| 电信   | ctcc  |
| 移动   | cmcc  |

完整的命令如图（复杂的密码请用" "括起来）

![2](https://raw.githubusercontent.com/s235784/NJUPT_AutoLogin/main/doc/2.png)

确认无误后，保存。之后路由器就会每5分钟确认一次网络状态，如果在没断网的时间内没有登录校园网，路由器就会自动登录了。

## 进阶用法

- [南邮校园网单线多拨](https://nuotian.furry.pro/blog/archives/347)

## 接口分析

打开校园网的登录界面，打开浏览器调试，勾选Network选项中的Preserve log，然后正常登录校园网，就能看到在登录时浏览器向10.10.244.11:801发送了POST请求。

![3](https://raw.githubusercontent.com/s235784/NJUPT_AutoLogin/main/doc/3.png)

进一步打开Payload查看POST数据，可以明显看到DDDDD后面的参数就包含了账号，upass就是密码。

![4](https://raw.githubusercontent.com/s235784/NJUPT_AutoLogin/main/doc/4.png)

在进一步的测试中得知，DDDDD的值的格式为 ,0, + 账号 + 运营商标识，其中的运营商标识校园网为空，电信为@njxy，移动为@cmcc。
然后把得到的api写到Apifox中测试，成功登录。

![5](https://raw.githubusercontent.com/s235784/NJUPT_AutoLogin/main/doc/5.png)

## 参考

* [南京邮电大学_校园网/电信宽带/移动宽带_路由器共享WiFi+自动认证](https://github.com/kaijianyi/NJUPT_NET)
* [校园网自动登录全平台解决方案](https://zhuanlan.zhihu.com/p/364016452)

## License
``` license
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
