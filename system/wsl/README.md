# 🖥️ WSL 配置

## 当前环境

- **发行版：** Ubuntu 24.04 LTS (Noble Numbat)
- **WSL 版本：** WSL2
- **内核：** 6.6.114.1-microsoft-standard-WSL2
- **systemd：** ✅ 已启用

## 文件说明

| 文件 | 说明 |
|------|------|
| `wsl.conf` | WSL 全局配置（network/boot/user） |
| `resolv.conf` | DNS 配置（静态） |
| `setup-guide.md` | 新机 WSL 环境搭建指南 |

## 关键配置

```ini
# /etc/wsl.conf
[network]
generateResolvConf = false   # 手动管理 DNS

[boot]
systemd = true               # 启用 systemd
```

## 常用命令

```bash
# WSL 管理
wsl --status                 # 查看状态
wsl --shutdown               # 重启 WSL

# DNS 查看
resolvectl status

# 内存/资源
free -h
nproc                        # CPU 核心数
```
