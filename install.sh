#!/bin/bash
#stty erase ^H

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
    echo ""
else
    echo "脚本目前仅支持Centos7"
    exit 1
fi

judge(){
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

install_socks5(){
    mkdir -p /etc/socks5
    if [[ -f /etc/socks5/socks5 ]];then
        echo "已经下载socks5"
    else
        wget https://github.com/steamsv/Multi-IPS5/raw/main/socks5 -O /etc/socks5/socks5
        judge "下载 socks5"
        chmod +x /etc/socks5/socks5
    fi
    path=`pwd`
    read -p "请输入监听ip 不输入则监听所有:" bindip
    if [ -z "${bindip}" ];then
        bindip="0.0.0.0"
    fi
    read -p "请输入监听端口:" port
    read -p "请输入出网ip 不输入则使用默认:" sendthrough
    if [ -z "${sendthrough}" ];then
        sendthrough="0.0.0.0"
    fi
    read -p "请输入用户名 不输入则无认证:" username
    if [ -z "${username}" ];then
        auth="noauth"
        username="username"
        password="password"
    else
        auth="password"
        read -p "请输入密码:" password
    fi

read -r -d '' config <<- EOF
{
    "inbound":{
        "listen" : "${bindip}",
        "port" : ${port},
        "protocol" : "socks",
        "settings" : {
            "auth" : "${auth}",
            "accounts": [
                {
                    "user": "${username}",
                    "pass": "${password}"
                }
            ],
            "udp" : true,
            "ip" : "127.0.0.1"
        }
    },
    "outbound": {
        "sendThrough": "${sendthrough}",
        "protocol": "freedom",
        "settings": {}
    }
}
EOF

echo ${config} > /etc/socks5/config_$port.json

execstart="ExecStart=/etc/socks5/socks5 -config /etc/socks5/config_$port.json"
cat > /etc/systemd/system/socks5_$port.service << EOF                                                                                               
[Unit]
Description=socks5_$port Service
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/run/socks5_$port.pid
$execstart
Restart=on-failure
# Don't restart in the case of configuration error
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart socks5_$port
    systemctl enable socks5_$port
    sleep 1
    systemctl status socks5_$port
    echo "安装完成"

    if [ ${auth} == "noauth" ];then
        echo "配置类型:socks5 监听地址:$bindip 监听端口:$port 出口ip:$sendthrough" >> /etc/socks5/socks5_installd
    else
        echo "配置类型:socks5 监听地址:$bindip 监听端口:$port 出口ip:$sendthrough 用户名:$username 密码:$password" >> /etc/socks5/socks5_installd
    fi
}

list_socks5(){
    if [[ -f /etc/socks5/socks5_installd ]];then
        echo 
    else 
        echo "还没有安装socks5"
        exit 0
    fi
    count=`wc -l /etc/socks5/socks5_installd | awk '{print $1}'`
    echo "当前有 $count 个socks5配置"
    cat -n /etc/socks5/socks5_installd
    if [ $menu_num -eq 3 ];
    then
        read -p "请输入对应数字删除配置:" line
        uninstall_socks5
    fi
}

uninstall_socks5(){
    port=`sed -n ${line}p /etc/socks5/socks5_installd | awk '{print $3}' | cut -c 6-20`
    systemctl stop socks5_${port}
    systemctl disable socks5_${port}
    rm /etc/systemd/system/socks5_${port}.service
    rm /etc/socks5/config_${port}.json
    systemctl daemon-reload
    # rm socks5
    sed -i ${line}d /etc/socks5/socks5_installd
    echo "卸载$port完成"
}

uninstall_all_socks5(){
    read -p "清除所有socks5配置? (默认否) [Y/n] :" yn
    [ -z "${yn}" ] && yn="n"
    if [[ $yn == [Yy] ]]; then
        echo -e "清理中..."
        count=`wc -l /etc/socks5/socks5_installd | awk '{print $1}'`
        for line in `seq 1 $count`
        do
            port=`sed -n ${line}p /etc/socks5/socks5_installd | awk '{print $3}' | cut -c 6-20`
            systemctl stop socks5_${port}
            systemctl disable socks5_${port}
            rm /etc/systemd/system/socks5_${port}.service
            rm /etc/socks5/config_${port}.json
            systemctl daemon-reload
            # rm socks5
            # sed -i ${line}d socks5_installd
            echo "卸载$port完成"
        done 
        cat /dev/null > /etc/socks5/socks5_installd
    fi
    
}

menu(){
    echo -e " socks5安装管理脚本 ${Red}[${shell_version}]${Font}\n"
    echo -e "${Green}1.${Font}  新增一个socks5配置"
    echo -e "----------"
    echo -e "${Green}2.${Font}  列出所有socks5信息"
    echo -e "${Green}3.${Font}  删除socks5配置"
    echo -e "----------"
    echo -e "${Green}4.${Font}  卸载清除所有socks5配置"
    echo -e "${Green}5.${Font}  退出 \n"
    read -p "请输入数字：" menu_num
    case $menu_num in
        1)
          install_socks5
          ;;
        2)
          list_socks5
          ;;
        3)
          list_socks5
          ;;
        4)
          uninstall_all_socks5
          ;;
        5)
          exit 0
          ;;
        *)
          echo -e "${RedBG}请输入正确的数字${Font}"
          ;;
    esac
}

menu