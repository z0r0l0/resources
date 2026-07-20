# 🖥️ WSL2 环境搭建终极指南

## 1. 基础配置

### 1.1 WSL 配置文件 (`/etc/wsl.conf`)
```ini
[network]
generateResolvConf = false

[boot]
systemd = true
```

### 1.2 DNS 配置 (`/etc/resolv.conf`)
```
nameserver 10.255.255.254
```

## 2. 代理配置

### Clash Verge Rev
- Windows 端开启 "允许局域网连接"
- 混合端口：7897
- WSL 中执行 `proxy-on` 启用

### 解决代理问题
```bash
# 检查代理是否可达
timeout 2 bash -c 'echo > /dev/tcp/127.0.0.1/7897'

# 通过代理下载
https_proxy=http://127.0.0.1:7897 curl ...
```

## 3. 磁盘挂载

| Windows 路径 | WSL 路径 |
|-------------|----------|
| `C:\` | `/mnt/c/` |
| `D:\` | `/mnt/d/` |
| `C:\Users\张\Desktop` | `/mnt/c/Users/张/Desktop` |
| `C:\Users\张\Documents` | `/mnt/c/Users/张/Documents` |
| `C:\Users\张\Downloads` | `/mnt/c/Users/张/Downloads` |

## 4. 常用 WSL 命令

```bash
# 终端内
wsl --status
wsl --shutdown       # 重启 WSL 内核
wsl --list --verbose # 查看所有发行版

# 或在 Windows CMD/PowerShell
wsl -d Ubuntu-24.04  # 指定发行版进入
```

## 5. 性能优化

- WSL2 内存限制：在 `%UserProfile%\.wslconfig` 中配置
```ini
[wsl2]
memory=4GB
processors=8
```

- WSL 与 Windows 文件互访：**Linux 文件放 WSL 内**，Windows 文件通过 `/mnt/c/` 访问，性能最佳
