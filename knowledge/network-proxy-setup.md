# 🌐 网络与代理配置指南

## 环境概述

```
Windows (Clash Verge Rev) ←→ WSL2 (Ubuntu 24.04)
        端口 7897                 通过 env 继承
```

## 代理配置

### Windows 端 (Clash Verge Rev)
1. 打开 Clash Verge Rev
2. 设置 → 允许局域网连接 ✅
3. 混合端口设置为 **7897**
4. 确保系统代理处于开启状态

### WSL 端
```bash
# 手动启用
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897

# 使用 alias（推荐）
proxy-on

# 关闭
proxy-off

# 检查状态
proxy-status
```

## DNS 配置

WSL 使用静态 DNS（不自动生成）：
```
# /etc/resolv.conf
nameserver 10.255.255.254
```

## apt 镜像

使用阿里云镜像：
```ini
# /etc/apt/sources.list.d/aliyun.sources
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

## 排错

### 代理不通
```bash
# 1. 检查代理端口
timeout 2 bash -c 'echo > /dev/tcp/127.0.0.1/7897'

# 2. 测试联网
curl -x http://127.0.0.1:7897 -s https://www.google.com

# 3. 检查 Windows 端 Clash 状态
```
