# 📋 项目模板

## Python 模板

```
python/
├── pyproject.toml      # 项目配置与依赖
├── src/
│   └── main.py         # 入口文件
├── tests/              # 测试目录
│   └── test_main.py
└── .gitignore
```

使用：
```bash
cp -r ~/resources/templates/python ./my-project
cd my-project
source ../scripts/dev/python-setup.sh
```

## Node.js 模板

```
node/
├── package.json
├── src/
│   └── index.js
├── tests/
└── .gitignore
```

使用：
```bash
cp -r ~/resources/templates/node ./my-project
cd my-project
source ../scripts/dev/node-setup.sh
```

## Docker 模板

```
docker/
├── Dockerfile.python   # Python 服务容器
└── Dockerfile.node     # Node.js 服务容器
```

使用：
```bash
docker build -t myapp -f templates/docker/Dockerfile.python .
```
