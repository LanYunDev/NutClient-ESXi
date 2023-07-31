#!/bin/bash

repo_url="https://github.com/LanYunDev/NutClient-ESXi.git"
local_dir="./NutClient-ESXi"
packages=("wget" "patch" "gcc" "zip" "make" "tar" "file" "git")

# 错误处理函数
handle_error() {
   echo ""
   echo '⚠️ 脚本发生错误!,请手动检查错误,2分钟后退出...'
   [[ "$(uname)" == "Darwin" ]] && osascript -e 'display notification "编译脚本" with title "⚠️脚本发生错误❌~" sound name "Glass"'
   sleep 120
   exit 1
}

# 设置错误处理函数
trap handle_error ERR

# 函数：检测Git配置是否已设置，$1为配置名
function check_git_config() {
    git config --get "$1" >/dev/null 2>&1
}

# 函数：设置Git配置，$1为配置名，$2为配置值
function set_git_config() {
    git config --global "$1" "$2"
}

# 检查是否为root用户，非root用户可能无法访问某些文件
if [[ $EUID -ne 0 ]]; then
   echo '⚠️ 请使用root权限运行此脚本!'
   exit 1
fi

# 设置一个变量来存储是否为CentOS 7，默认为false
is_centos7=false
# 设置一个变量来存储是否为最新版，默认为false
version_latest=false

# 检查是否存在centos-release文件
if [ -f /etc/centos-release ]; then
    # 读取文件内容并检查是否包含"CentOS Linux release 7"
    if grep -q "CentOS Linux release 7" /etc/centos-release; then
        echo "⚙️ 当前系统为CentOS 7."
        is_centos7=true
    fi
else
    echo "⚠️ 警告: 编译很可能会失败☹️."
    echo "🤖建议: 尝试使用CentOS 7."
    while true; do
        read -r -p "⚙️ 你是否(y/n)知晓?" flag || true
        # echo ""
        if [[ $flag == y ]]; then
            echo '⚠️ 警告: 你在使用非CentOS 7进行编译!'
            flag="" # 重置变量
            break  # 输入为"y"时，结束循环♻️
        fi
    done
fi

if ${is_centos7} ; then
   read -r -t 3 -p "⚙️ 是否(y/n)安装必须的软件包? 3秒后自动安装." flag || true
   echo ""
   if [[ $flag != n ]]; then
      # 尝试安装软件包
      yum install -y "${packages[@]}"
      while ! command -v "${packages[@]}" >/dev/null 2>&1; do
          read -r -p "有些软件包尚未安装成功，是否重试安装？(y/n): " choice
          if [[ "$choice" =~ ^[Yy]$ ]]; then
              yum install -y "${packages[@]}"
          else
              echo "退出安装程序。"
              break
          fi
      done
      echo '✅所有软件包已成功安装！'
   fi
   flag="" # 重置变量
else
    echo "⚠️ 请确保软件包都正确安装"
    echo '⚠️ 本脚本不会帮助你安装!'
    for package in "${packages[@]}"; do
        command -v "$package" &>/dev/null || (echo "⚠️ 软件包未被安装: $package" && exit 1)
    done
fi

# 检查当前目录是否为NutClient-ESXi目录
if [ "$(basename "$(pwd)")" = "NutClient-ESXi" ]; then
    echo "⚙️ 当前目录为 NutClient-ESXi 目录."
else
    # 检查当前目录下是否有名为 NutClient-ESXi 目录
    if [ -d "NutClient-ESXi" ]; then
        echo "⚙️ 当前目录下存在 NutClient-ESXi 目录."
        echo "⚙️ 进入NutClient-ESXi目录"
        cd NutClient-ESXi || exit 1
    else
        echo "⚙️ 当前目录下不存在 NutClient-ESXi 目录."
        while true; do
          read -r -p "⚙️ 是否(y/n)在当前目录拉取项目?" flag || true # 看似有的选,实际没得选.😂
          # echo ""
          if [[ $flag == y ]]; then
            while true; do
               # git clone "$repo_url" "$local_dir" #&> /dev/null
               # 检查git clone的返回值
               if git clone "$repo_url" "$local_dir"; then
                  echo "✅Git clone 拉取成功！"
                  break
               else
                  echo "❌ Git clone 拉取失败，请检查链接和网络连接。"
                  read -r -p "⚙️ 是否继续尝试拉取？(y/n): " choice || true
                  echo ""
                  if [ "$choice" != "y" ]; then
                     break
                  fi
               fi
            done
            echo "⚙️ 拉取已完成✅"
            echo "⚙️ 进入NutClient-ESXi目录"
            cd NutClient-ESXi || exit 1
            choice="" # 重置变量
            flag="" # 重置变量
            break  # 输入为"y"时，结束循环♻️
          fi
      done
    fi
fi

# 执行缓存清理,避免错误.
(echo '⚙️ 清理缓存' && make clean) || make clean

# 判断是否为Git仓库
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 ; then
    echo "⚙️ 检查更新ing"
    # 恢复原始文件
    if [ -f ./upsmon.conf.template.bak ]; then
        cp -f ./skeleton/opt/nut/etc/upsmon.conf.template ./upsmon.conf.template.tmp
        cp -f ./upsmon.conf.template.bak ./skeleton/opt/nut/etc/upsmon.conf.template
    fi
    if [ -f ./Makefile.bak ]; then
        cp -f ./Makefile ./Makefile.tmp
        cp -f ./Makefile.bak ./Makefile
        rm -f ./skeleton/opt/nut/bin/notify.sh
        # sed -i -e "s#/opt/nut/bin/notify.sh;poweroff#poweroff#g" "./skeleton/opt/nut/etc/upsmon.conf.template"
    fi
    # 获取当前分支的名称
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    # 拉取远程分支的信息，更新本地的远程分支信息
    git fetch
    # 使用 git merge-base 命令找到两个分支的最近共同祖先（base commit）
    base_commit=$(git merge-base "origin/$current_branch" "$current_branch")
    # 比较本地分支与远程分支的提交哈希值
    if [[ "$(git rev-parse "$current_branch")" != "$(git rev-parse "origin/$current_branch")" ]]; then
        echo "⚙️ 开始更新ing"
        
        # 检查是否有冲突,这里代码,我没测试过对不对,有问题可以带上日志提issue.
        if git merge-tree "$base_commit" "origin/$current_branch" "$current_branch" | grep -q 'changed in both'; then
        # if git status | grep "Unmerged paths"; then
            {
                echo '⚠️ 发现冲突!'
                echo '⚙️ 3秒后尝试自动修复' && sleep 3
                # 检测并设置Git账户身份
                if ! check_git_config "user.email" || ! check_git_config "user.name"; then
                    echo '⚠️ 发现错误! 你未设置Git账户身份'
                    read -r -t 5 -p "⚙️ 是否(y/n)自动设置Git账户身份? 5秒后自动设置." flag || true
                    echo ""
                    if [[ $flag != n ]]; then
                        set_git_config "user.email" "anonymous@example.com"
                        set_git_config "user.name" "anonymous"
                    else
                        if ! check_git_config "user.email" || ! check_git_config "user.name"; then
                            echo '⚙️ 开始手动设置Git账户身份'
                            echo '⚠️ 注: 身份设置仅用于该仓库.'
                            read -r -p "请输入您的Git邮箱地址: " email
                            [ -n "$email" ] && set_git_config "user.email" "$email"
                            check_git_config "user.email" && echo "✅email设置完成"
                            read -r -p "请输入您的Git用户名: " username
                            [ -n "$username" ] && set_git_config "user.name" "$username"
                            check_git_config "user.name" && echo "✅username设置完成"
                        fi
                    fi
                fi
                (git stash && git pull -f && git stash pop && echo "✅更新完成") || (echo '⚠️ 更新失败!☹️' && exit 1)
                if [ -f ./Makefile.tmp ]; then
                    rm -rf ./Makefile.tmp # 删除临时文件
                    rm -rf ./Makefile.bak # 删除Makefile.bak文件,重新解析.
                fi
                if [ -f ./upsmon.conf.template.tmp ]; then
                    rm -rf ./upsmon.conf.template.tmp
                    rm -rf ./upsmon.conf.template.bak
                fi
                {
                    echo '⚙️ 3秒后重新运行本脚本' && sleep 3
                    bash "$(pwd)/一键编译.sh"
                }&
                exit 0
            }&
            exit 0
        fi

        (git pull -f && echo "✅更新完成") || (echo '⚠️ 更新失败!☹️' && exit 1)
        if [ -f ./Makefile.tmp ]; then
            rm -rf ./Makefile.tmp # 删除临时文件
            rm -rf ./Makefile.bak # 删除Makefile.bak文件,重新解析.
        fi
        if [ -f ./upsmon.conf.template.tmp ]; then
            rm -rf ./upsmon.conf.template.tmp
            rm -rf ./upsmon.conf.template.bak
        fi
        {
            echo '⚙️ 3秒后重新运行本脚本' && sleep 3
            bash "$(pwd)/一键编译.sh"
        }&
        exit 0
    else
        # 恢复修改的文件
        if [ -f ./Makefile.tmp ]; then
            cp -f ./Makefile.tmp ./Makefile
            # sed -i -e "s#poweroff#/opt/nut/bin/notify.sh;poweroff#g" "./skeleton/opt/nut/etc/upsmon.conf.template"
            rm -rf ./Makefile.tmp
        fi
        if [ -f ./upsmon.conf.template.tmp ]; then
            cp -f ./upsmon.conf.template.tmp ./skeleton/opt/nut/etc/upsmon.conf.template
            rm -rf ./upsmon.conf.template.tmp
        fi
        version_latest=true
        echo "✅已是最新版"
    fi
else
    echo "⚠️ 当前目录不是一个Git项目.将不支持后续自动更新."
    echo "⚙️ 项目: https://github.com/LanYunDev/NutClient-ESXi"
    while true; do
        read -r -p "⚙️ 你是否(y/n)知晓?" flag || true
        if [[ $flag == y ]]; then
            flag="" # 重置变量
            break  # 输入为"y"时，结束循环♻️
        fi
    done
    # exit 1
fi

# 检查是否存在bak备份文件
if [ ! -f ./Makefile.bak ]; then
    # 文件不存在
    echo "⚙️ 生成Makefile备份文件📃" && cp -v ./Makefile ./Makefile.bak
    echo "⚙️ 处理Makefile文件📃"
    sed -i -e "s/payload: nut-bin smtptools-bin/payload: nut-bin/g;s/shell uname -i/shell uname -m/g; /smtp/s/^[^#]/#&/" "Makefile"
    sed -i -e "s#tar -xf nut-\$(NUT_VERSION).tar.gz#&\
     ; sed -i -e \"s/on line power/已连接电源/g;s/UPS %s on battery/UPS %s 正使用电池供电/g;s/UPS %s battery is low/UPS %s 电池电量低/g;s/UPS %s: forced shutdown in progress/UPS %s: 正在进行强制关机/g;s/Communications with UPS %s established/已建立与 UPS %s 的通信/g;s/Communications with UPS %s lost/与 UPS %s 的通信丢失/g;s/Auto logout and shutdown proceeding/自动注销并进行关机/g;s/UPS %s battery needs to be replaced/UPS %s 需要更换电池/g;s/UPS %s is unavailable/UPS %s 不可用/g;s/upsmon parent process died - shutdown impossible/upsmon 父进程已停止 - 无法进行关机/g;s/UPS %s: calibration in progress/UPS %s：正在进行校准/g\" \"./nut-\$(NUT_VERSION)/clients/upsmon.h\"#" 'Makefile'
    # sed -i -e "s#poweroff#/opt/nut/bin/notify.sh;poweroff#g" "./skeleton/opt/nut/etc/upsmon.conf.template"
else
    echo "⚙️ 检测到Makefile.bak文件📃"
    echo "⚙️ 跳过对Makefile文件的处理"
fi

echo "⚙️ 清除无用内容" && rm -rf ./patches/smtptools*

# 判断是否为本人的仓库
if git remote -v | grep -q "github.com/LanYunDev"; then
    if [[ ! -f ./shutdown.sh ]]; then
        echo "⚙️ 未检测到shutdown.sh文件📃"
        echo "⚙️ 注: 该文件可通过检查群晖CPU情况判断是否恢复供电"
        read -r -p "⚙️ 是否(y/n)需要ESXI关机前检查群晖情况? " flag || true
        if [[ $flag = y ]]; then
            echo '⚙️ 请在ESXI的命令行中输入vim-cmd vmsvc/getallvms'
            read -r -p "请输入群晖虚拟机对应的Vmid: " VM_ID
            echo "⚙️ 群晖CPU数值检测预值建议填100(默认),不修改默认值,直接回车即可."
            read -r -p "请输入群晖CPU数值检测预值: " CPU_Limit
            cp -v ./shutdown.sh.template ./shutdown.sh
            if [[ ! ${CPU_Limit} || ${CPU_Limit} = "100" ]]; then
                echo "⚙️ 群晖CPU数值检测预值为默认100MHz"
            else
                echo "⚠️ 不建议调整CPU数值检测预值,有可能导致检测未及时等问题."
                echo '⚠️ 请根据实际情况修改群晖CPU数值检测预值!'
                echo "⚙️ 群晖CPU数值检测预值将为${CPU_Limit}MHz"
                sed -i -e "s/CPU_Limit='100'/CPU_Limit='${CPU_Limit}'/g" "./shutdown.sh"
            fi
            sed -i -e "s/VM_ID=''/VM_ID='${VM_ID}'/g" "./shutdown.sh"
            (cp -f -v ./skeleton/opt/nut/etc/upsmon.conf.template ./upsmon.conf.template.bak && echo "✅upsmon.conf.template备份成功") || echo "⚠️ upsmon.conf.template备份失败☹️"
            (sed -i -e "s#poweroff#/opt/nut/bin/shutdown.sh\&\&poweroff#g" "./skeleton/opt/nut/etc/upsmon.conf.template" && echo '✅upsmon.conf.template文件处理成功') || (echo '⚠️ upsmon.conf.template文件处理失败☹️' && exit 1)
        else
            echo "⚠️ 你已跳过对shutdown.sh文件的处理"
            echo "⚠️ 若UPS恢复供电,ESXI依然会关机"
        fi
    else
        # 有shutdown.sh文件📃代表需要检查群晖CPU情况来判断恢复供电
        if grep -q "VM_ID=''" "./shutdown.sh"; then
            echo '⚙️ 请在ESXI的命令行中输入vim-cmd vmsvc/getallvms'
            read -r -p "请输入群晖虚拟机对应的Vmid: " VM_ID
            sed -i -e "s/VM_ID=''/VM_ID='${VM_ID}'/g" "./shutdown.sh"
        fi
        if [ ! -f ./upsmon.conf.template.bak ]; then
            echo "⚙️ 未检测到upsmon.conf.template.bak文件📃"
            (cp -f -v ./skeleton/opt/nut/etc/upsmon.conf.template ./upsmon.conf.template.bak && echo "✅upsmon.conf.template备份成功") || echo "⚠️ upsmon.conf.template备份失败☹️"
            (sed -i -e "s#poweroff#/opt/nut/bin/shutdown.sh\&\&poweroff#g" "./skeleton/opt/nut/etc/upsmon.conf.template" && echo '✅upsmon.conf.template文件处理成功') || (echo '⚠️ upsmon.conf.template文件处理失败☹️' && exit 1)
        else
            echo "⚙️ 检测到upsmon.conf.template.bak文件📃"
            echo "⚙️ 跳过对upsmon.conf.template文件的处理"
        fi
    fi

    if [[ ! -f ./notify.sh ]]; then
        cp -v ./notify.sh.template ./notify.sh
        read -r -p "请输入MAIL_IP变量的值: " MAIL_IP
        sed -i -e "s/MAIL_IP=\"\"/MAIL_IP=\"${MAIL_IP}\"/g" "./notify.sh"
        # echo "⚙️ 请手动修改notify.sh文件中MAIL_IP变量"
        if grep -q 'MAIL_IP=""' "./notify.sh"; then
            echo '⚠️ 未检测到MAIL_IP变量的值!'
            echo "⚠️ 若没有配置MAIL_IP变量,将只有基础(无邮件)功能."
        fi
    else
        echo "⚙️ 检测到已存在notify.sh文件📃"
        if grep -q 'MAIL_IP=""' "./notify.sh"; then
            echo '⚠️ 未检测到MAIL_IP变量的值!'
            echo "⚠️ 若没有配置MAIL_IP变量,将只有基础(无邮件)功能."
            read -r -p "请输入MAIL_IP变量的值: " MAIL_IP
            sed -i -e "s/MAIL_IP=\"\"/MAIL_IP=\"${MAIL_IP}\"/g" "./notify.sh"
        fi
        if ${version_latest} ; then
            echo "⚙️ 当前为最新版,已跳过覆盖."
        else
            echo "⚙️ 当前不是最新版,建议覆盖."
            flag=""
            while true; do
                read -r -p "⚙️ 是否(y/n)覆盖此文件?" flag || true
                if [[ $flag == y ]]; then
                    cp -v -f ./notify.sh.template ./notify.sh && echo '✅覆盖成功!'
                    echo "⚙️ 请手动修改notify.sh文件中MAIL_IP变量"
                    flag=""; break 
                fi
            done
        fi
    fi
    if [[ ! -f ./notify_extension.sh ]]; then
        cp -v ./notify_extension.sh.template ./notify_extension.sh
    else
        echo "⚙️ 检测到已存在notify_extension.sh文件📃"
        if ${version_latest} ; then
            echo "⚙️ 当前为最新版,已跳过覆盖."
        else
            echo "⚙️ 当前不是最新版,建议覆盖."
            flag=""
            while true; do
                read -r -p "⚙️ 是否(y/n)覆盖此文件? 5秒后自动覆盖" flag || true
                if [[ $flag != n ]]; then
                    cp -v -f ./notify_extension.sh.template ./notify_extension.sh && echo '✅覆盖成功!'
                    flag=""; break 
                fi
            done
        fi
    fi
else
    echo "⚠️ 警告: 检测到并非LanYunDev的仓库"
    echo "⚙️ 请手动修改./skeleton/opt/nut/bin/notify.sh文件📃"
    echo "⚠️ 若没有配置MAIL_IP变量,将只有基础(无邮件)功能."
fi

echo "⚙️ 开始处理修改"
(cp -f -v ./notify.sh ./skeleton/opt/nut/bin/notify.sh && echo "✅notify.sh覆盖成功") || echo "⚠️ notify.sh覆盖失败☹️"
(cp -f -v ./shutdown.sh ./skeleton/opt/nut/bin/shutdown.sh && echo "shutdown.sh覆盖成功") || echo "⚠️ shutdown.sh覆盖失败☹️"
(cp -f -v ./notify_extension.sh ./skeleton/opt/nut/bin/notify_extension.sh && echo "✅notify_extension.sh添加成功") || (echo "⚠️ notify_extension.sh添加失败☹️" && echo "⚠️ 请确保notify_extension.sh在目录下" && exit 1)
echo "⚙️ 修改已完成✅"

echo '⚙️ 开始编译!'
echo "⚠️ 注: 单线程编译花费时间较长"

make # 注意,经过实测,并不支持多线程编译

echo "✅编译完成"
echo "用法可见博客文章: https://lanyundev.com/posts/bf72347b.html"
echo "本人仓库链接: https://github.com/LanYunDev/NutClient-ESXi"













# Tips: 只保证本脚本通过shellcheck的检查,其他脚本懒得改了.

# echo "测试1"$flag && exit 0
# 废弃代码:

# while true; do
#     read -r -p "⚙️ 此目录是否(y/n)从我fork的项目拉取?" flag || true
#     # echo ""
#     if [[ $flag == y ]]; then
#         if [[ ! -f ./notify.sh ]]; then
#             cp -v ./notify.sh.template ./notify.sh
#             echo "⚙️ 请手动修改notify.sh文件中MAIL_IP变量"
#             echo "⚠️ 若没有配置MAIL_IP变量,将只有基础(无邮件)功能."
#         else
#             echo "⚙️ 检测到已存在notify.sh文件📃"
#             if ${version_latest} ; then
#                 echo "⚙️ 当前为最新版,已跳过覆盖."
#             else
#                 echo "⚙️ 当前不是最新版,建议覆盖."
#                 flag=""
#                 while true; do
#                     read -r -p "⚙️ 是否(y/n)覆盖此文件?" flag || true
#                     if [[ $flag == y ]]; then
#                         cp -v -f ./notify.sh.template ./notify.sh && echo '✅覆盖成功!'
#                         echo "⚙️ 请手动修改notify.sh文件中MAIL_IP变量"
#                         flag=""; break 
#                     fi
#                 done
#             fi
#         fi
#         if [[ ! -f ./notify_extension.sh ]]; then
#             cp -v ./notify_extension.sh.template ./notify_extension.sh
#         else
#             echo "⚙️ 检测到已存在notify_extension.sh文件📃"
#             if ${version_latest} ; then
#                 echo "⚙️ 当前为最新版,已跳过覆盖."
#             else
#                 echo "⚙️ 当前不是最新版,建议覆盖."
#                 flag=""
#                 while true; do
#                     read -r -p "⚙️ 是否(y/n)覆盖此文件? 5秒后自动覆盖" flag || true
#                     if [[ $flag != n ]]; then
#                         cp -v -f ./notify_extension.sh.template ./notify_extension.sh && echo '✅覆盖成功!'
#                         flag=""; break 
#                     fi
#                 done
#             fi
#         fi
#         flag="" # 重置变量
#         break   # 输入为"y"时，结束循环♻️
#     elif [[ $flag == n ]]; then
#         echo "⚙️ 请手动修改./skeleton/opt/nut/bin/notify.sh文件📃"
#         flag=""; break 
#     fi
# done

# while true; do
#     read -r -p "⚙️ 修改是否(y/n)完成?" flag || true
#     # echo ""
#     if [[ $flag == y ]]; then
#         (cp -f -v ./notify.sh ./skeleton/opt/nut/bin/notify.sh && echo "✅notify.sh覆盖成功") || echo "⚠️ notify.sh覆盖失败☹️"
#         (cp -f -v ./notify_extension.sh ./skeleton/opt/nut/bin/notify_extension.sh && echo "✅notify_extension.sh添加成功") || (echo "⚠️ notify_extension.sh添加失败☹️" && echo "⚠️ 请确保notify_extension.sh在目录下" && exit 1)
#         echo "⚙️ 修改已完成✅"
#         flag="" # 重置变量
#         break  # 输入为"y"时，结束循环♻️
#     fi
# done






