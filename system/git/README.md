# 🐙 Git 配置合集

## 全局配置
```bash
git config --global user.name "z0r0l0"
git config --global core.autocrlf input
```

## 常用别名
```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.lg "log --oneline --graph --decorate --all"
```

## 工作流建议
1. `main` 分支保持可部署状态
2. 功能开发在 feature 分支
3. 使用 Pull Request 进行代码审查
4. Commit 信息用英文，简洁明了
