# 轻量级 K8s 可观测性平台 — 运维操作手册

> **版本**：v2.0 | **环境**：本地虚拟机 K8s 集群 | **用途**：学习实践
> **原则**：可复现、可回滚、最小资源、最大稳定

---

## 目录

- [0. 架构总览](#0-架构总览)
- [1. 前置准备与校验](#1-前置准备与校验)
- [2. 部署 Prometheus（指标采集）](#2-部署-prometheus指标采集)
- [3. 部署 Loki（日志聚合）](#3-部署-loki日志聚合)
- [4. 部署 Grafana（可视化面板）](#4-部署-grafana可视化面板)
- [5. 配置 Grafana 数据源与仪表盘](#5-配置-grafana-数据源与仪表盘)
- [6. 部署 Metrics Server](#6-部署-metrics-server)
- [7. HPA 自动扩缩容](#7-hpa-自动扩缩容)
- [8. Alertmanager QQ 邮箱告警](#8-alertmanager-qq-邮箱告警)
- [9. 自定义告警规则](#9-自定义告警规则)
- [10. 全链路验证](#10-全链路验证)
- [11. 日常维护与排错](#11-日常维护与排错)
- [附录A：完整资源清单](#附录a完整资源清单)
- [附录B：回滚操作速查](#附录b回滚操作速查)

---

## 0. 架构总览

```
┌─────────────────────────────────────────────────────────┐
│                    你的应用 Pod                           │
│  (任何 Deployment / StatefulSet)                         │
└────────┬────────────┬──────────────────┬────────────────┘
         │            │                  │
         ▼            ▼                  ▼
  ┌──────────┐ ┌──────────┐ ┌──────────────────┐
  │ Node     │ │ Promtail │ │ kubelet/cAdvisor │
  │ Exporter │ │ (日志采集) │ │ (内置指标)        │
  └────┬─────┘ └────┬─────┘ └────────┬─────────┘
       │            │                │
       ▼            ▼                ▼
  ┌──────────┐ ┌──────────┐ ┌──────────────────┐
  │Prometheus│ │   Loki   │ │  Metrics Server   │
  │ (指标存储)│ │ (日志存储)│ │  (HPA 数据源)     │
  └────┬─────┘ └────┬─────┘ └────────┬─────────┘
       │            │                │
       └────────────┼────────────────┘
                    ▼
           ┌──────────────┐
           │   Grafana    │  ← 浏览器访问 :30300
           │  (可视化面板) │
           └──────┬───────┘
                  │
          ┌───────▼────────┐
          │ Alertmanager    │ → QQ 邮件告警
          └────────────────┘
```

---

## 1. 前置准备与校验

### 1.1 环境自检

在部署前，必须确认集群状态正常：

```bash
# ── 1. 节点状态 ──
kubectl get nodes -o wide
# ✅ 预期：所有节点 STATUS=Ready，VERSION 一致

# ── 2. 系统组件健康 ──
kubectl get pods -n kube-system -o wide
# ✅ 预期：coredns、kube-proxy 等核心组件 Running

# ── 3. 资源余量检查 ──
kubectl describe nodes | grep -A 3 "Allocated resources"
# ⚠️ 确保剩余内存 > 2Gi，剩余 CPU > 1 核

# ── 4. Helm 版本 ──
helm version --short
# ✅ 预期：v3.7+（输出如 v3.16.x）

# ── 5. 存储类（PVC 支持） ──
kubectl get storageclass
# ⚠️ 如果没有 StorageClass，后面 Loki 会使用 emptyDir（重启数据丢失）
#    学习环境可以接受，生产环境必须配置
```

### 1.2 准备 Helm Values 目录

```bash
# 创建独立的配置目录，所有 values 文件集中管理
mkdir -p ~/k8s-observability/values
cd ~/k8s-observability
```

> **为什么用 values 文件？**
> 命令行 `--set` 容易拼写错误、难以复现。
> values 文件可版本管理（git）、可 review、可重复执行。

---

## 2. 部署 Prometheus（指标采集）

### 2.1 添加 Helm 仓库并锁定版本

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 🔍 查看可用的 Chart 版本（选择一个稳定版本）
helm search repo prometheus-community/prometheus --versions | head -5
# 选择最新稳定版，本文以 v25.x 为例
```

### 2.2 创建 values 文件

创建 `values/prometheus.yaml`：

```yaml
# ═══════════════════════════════════════════
# Prometheus Helm Values — 轻量学习配置
# Chart: prometheus-community/prometheus
# ═══════════════════════════════════════════

# ── Prometheus Server ──
server:
  # 资源限制（requests + limits 都要设，防止 OOM）
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi        # OOM 保护上限
      cpu: 500m

  # 数据持久化（学习环境不用 PV，重启数据丢失）
  persistentVolume:
    enabled: false
    size: 8Gi

  # 指标保留时间
  retention: "3d"           # 学习环境 3 天足够

# ── Alertmanager ──
alertmanager:
  enabled: true
  resources:
    requests:
      memory: 64Mi
      cpu: 50m
    limits:
      memory: 128Mi
      cpu: 200m
  persistentVolume:
    enabled: false

# ── Node Exporter ──
nodeExporter:
  enabled: true
  resources:
    requests:
      memory: 32Mi
      cpu: 10m
    limits:
      memory: 64Mi
      cpu: 100m

# ── 以下组件学习环境不需要，禁用节能 ──
kubeStateMetrics:
  enabled: false             # kube-state-metrics（生产有用，学习可省）

pushgateway:
  enabled: false             # Pushgateway（批量任务才需要）
```

### 2.3 安装

```bash
# 🚀 安装命令（包含前置校验）
cat values/prometheus.yaml && echo "--- Values OK ---"

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --values values/prometheus.yaml \
  --atomic \                # 安装失败自动回滚
  --timeout 10m \           # 最长等待 10 分钟
  --wait                    # 等待所有 Pod Ready

# 如果失败，执行：
# helm uninstall prometheus -n monitoring && 检查错误后重试
```

### 2.4 安装后校验

```bash
# ✅ 第1关：Pod 运行状态
kubectl get pods -n monitoring -l release=prometheus
# 预期：prometheus-server-xxx, prometheus-alertmanager-xxx, prometheus-node-exporter-xxx 均 Running

# ✅ 第2关：Pod 详情（确认资源限制生效）
kubectl describe pod -n monitoring -l app=prometheus,component=server | grep -A 5 "Limits"

# ✅ 第3关：Prometheus Web UI 可达
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
curl -s http://localhost:9090/-/ready
# 预期输出：Ready
kill %1 2>/dev/null

# ✅ 第4关：指标采集正常
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
curl -s http://localhost:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'健康目标数: {sum(1 for t in d[\"data\"][\"activeTargets\"] if t[\"health\"]==\"up\")}')"
kill %1 2>/dev/null
```

> 🔄 **如果 Pod 一直 Pending**：`kubectl describe pod -n monitoring prometheus-server-xxx` 查看 Events
> ⚡ **如果 Pod CrashLoopBackOff**：`kubectl logs -n monitoring prometheus-server-xxx` 看错误日志

---

## 3. 部署 Loki（日志聚合）

### 3.1 添加仓库

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 查看版本
helm search repo grafana/loki-stack --versions | head -5
```

### 3.2 创建 values 文件

创建 `values/loki.yaml`：

```yaml
# ═══════════════════════════════════════════
# Loki Stack Helm Values — 轻量学习配置
# Chart: grafana/loki-stack
# ═══════════════════════════════════════════

# ── Loki（日志存储）──
loki:
  resources:
    requests:
      memory: 128Mi
      cpu: 50m
    limits:
      memory: 256Mi
      cpu: 200m

  # ⚠️ 单副本模式（HA 需要多副本 + memcached，学习环境不需要）
  replicas: 1

  persistence:
    enabled: false         # 学习环境不用 PV

  # 降低日志存储配置，减少磁盘和内存占用
  config:
    chunk_store_config:
      max_look_back_period: 0
    table_manager:
      retention_deletes_enabled: true
      retention_period: 72h   # 日志保留 3 天

# ── Promtail（日志采集器，DaemonSet 在每个节点运行）──
promtail:
  enabled: true
  resources:
    requests:
      memory: 64Mi
      cpu: 10m
    limits:
      memory: 128Mi
      cpu: 100m

# ── 以下组件学习环境不需要 ──
fluent-bit:
  enabled: false
```

### 3.3 安装

```bash
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values values/loki.yaml \
  --atomic \
  --timeout 10m \
  --wait
```

### 3.4 安装后校验

```bash
# ✅ Pod 状态
kubectl get pods -n monitoring | grep -E "loki|promtail"

# ✅ Loki HTTP API 可达
kubectl port-forward -n monitoring svc/loki 3100:3100 &
curl -s http://localhost:3100/ready
# 预期输出：Ready
curl -s http://localhost:3100/loki/api/v1/labels | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'标签数: {len(d[\"data\"])}')" 2>/dev/null || echo "Loki 启动中，稍后重试"
kill %1 2>/dev/null
```

---

## 4. 部署 Grafana（可视化面板）

### 4.1 创建 values 文件

创建 `values/grafana.yaml`：

```yaml
# ═══════════════════════════════════════════
# Grafana Helm Values — 轻量学习配置
# Chart: grafana/grafana
# ═══════════════════════════════════════════

# ── 管理员密码 ──
adminPassword: "admin123"

# ── 资源限制 ──
resources:
  requests:
    memory: 128Mi
    cpu: 50m
  limits:
    memory: 256Mi
    cpu: 200m

# ── 服务暴露方式 ──
service:
  type: NodePort
  nodePort: 30300
  port: 80
  targetPort: 3000

# ── 数据持久化 ──
persistence:
  enabled: false         # 学习环境：仪表盘配置不持久化
  # 如需持久化，改为 true 并配置 storageClassName

# ── 预配置数据源（启动时自动添加，省去手动步骤）──
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring:80
      access: proxy
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki.monitoring:3100
      access: proxy

# ── 预导入仪表盘（可选）──
# dashboardProviders:
#   dashboardproviders.yaml:
#     apiVersion: 1
#     providers:
#     - name: 'default'
#       orgId: 1
#       folder: ''
#       type: file
#       disableDeletion: false
#       editable: true
#       options:
#         path: /var/lib/grafana/dashboards/default
# dashboards:
#   default:
#     315:
#       gnetId: 315
#       revision: 1
#       datasource: Prometheus
```

> **✨ 亮点**：`datasources.datasources.yaml` 会在 Grafana 启动时自动添加 Prometheus 和 Loki 数据源，**无需手动登录配置**。

### 4.2 安装

```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values values/grafana.yaml \
  --atomic \
  --timeout 10m \
  --wait
```

### 4.3 安装后校验

```bash
# ✅ Pod 状态
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# ✅ Service 状态
kubectl get svc -n monitoring grafana

# ✅ 确认数据源已自动配置
kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d
# 输出密码：admin123

# 访问：http://<虚拟机IP>:30300   admin / admin123
```

---

## 5. 配置 Grafana 数据源与仪表盘

> 如果你使用了上面带 `datasources` 的 values 文件，**这一步可以跳过**。
> 否则手动操作：

```bash
# 端口转发到本地访问
kubectl port-forward -n monitoring svc/grafana 8080:80 &
```

访问 `http://localhost:8080`，admin / admin123：

**数据源验证**：
- Connections → Data sources → Prometheus → **Save & Test** → ✅ 绿色
- Connections → Data sources → Loki → **Save & Test** → ✅ 绿色

**导入仪表盘**（用 curl 自动化，不用手动点）：

```bash
# 获取 Grafana API Key
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o name)

# 导入 Kubernetes Cluster Monitoring (ID: 315)
kubectl exec -n monitoring $GRAFANA_POD -- \
  curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"dashboard":{"id":null,"title":"K8s Cluster Monitoring","gnetId":315},"overwrite":true}' \
  http://admin:admin123@localhost:3000/api/dashboards/import
```

---

## 6. 部署 Metrics Server

### 6.1 选择稳定版本并安装

```bash
# 🔒 锁定 Metrics Server 版本（v0.7.x 是稳定版）
METRICS_SERVER_VERSION="0.7.2"

kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/v${METRICS_SERVER_VERSION}/components.yaml"

# ⚠️ 等待 10 秒让资源创建
sleep 10
```

### 6.2 处理自签名证书

```bash
# 本地 K8s 集群通常使用自签名证书，必须添加 --kubelet-insecure-tls
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--kubelet-insecure-tls"
    },
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--kubelet-use-node-status-port"
    }
  ]'
```

### 6.3 等待与验证

```bash
# 等待 Pod Ready（最长等 2 分钟）
echo "⏳ 等待 Metrics Server 就绪..."
kubectl wait --for=condition=ready pod \
  -l k8s-app=metrics-server \
  -n kube-system \
  --timeout=120s

# 验证指标采集
echo "📊 节点资源："
kubectl top nodes

echo "📊 所有 Pod 资源："
kubectl top pods -A
```

> ❌ `kubectl top nodes` 无输出 → `kubectl logs -n kube-system -l k8s-app=metrics-server`
> 常见错误：`x509: certificate signed by unknown authority` → 确认 `--kubelet-insecure-tls` 已添加

---

## 7. HPA 自动扩缩容

### 7.1 前提条件

- ✅ Metrics Server 已正常运行
- ✅ `kubectl top pods` 能返回数据
- ✅ 目标 Deployment 已设置 `resources.requests`

### 7.2 创建 HPA 配置

创建 `jenkins-hpa.yaml`：

```yaml
# ═══════════════════════════════════════════
# HPA 配置 — Jenkins Deployment 自动扩缩容
# ═══════════════════════════════════════════
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jenkins-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jenkins
  minReplicas: 1          # 最小副本数（保证基础服务）
  maxReplicas: 3          # 最大副本数（学习环境 3 足够）
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60   # CPU 使用率超过 60% 触发扩容
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75   # 内存使用率超过 75% 触发扩容
```

```bash
kubectl apply -f jenkins-hpa.yaml
```

### 7.3 验证 HPA

```bash
# 查看 HPA 状态
kubectl get hpa jenkins-hpa -n default -w
# REFERENCE    TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
# jenkins      5%/60%     1         3         1          30s
# └─ 当前 CPU    └─ 阈值
#  使用率 5%       60%

# 模拟负载测试扩容
kubectl run -it --rm load-test --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://jenkins:8080 2>/dev/null; done"

# 另开终端观察 HPA
# kubectl get hpa jenkins-hpa -n default -w
```

> **HPA 不会立即扩容**：Metrics Server 每 15 秒采集一次，HPA 每 60 秒评估一次，有 1-2 分钟延迟是正常的。

---

## 8. Alertmanager QQ 邮箱告警

### 8.1 获取 QQ 邮箱授权码

> ⚠️ QQ 邮箱**不是用登录密码**，必须申请授权码：
> 1. 登录 [QQ 邮箱](https://mail.qq.com)
> 2. 设置 → 账户 → POP3/IMAP/SMTP 服务 → **开启**
> 3. 点击 **生成授权码** → 复制 16 位授权码

### 8.2 创建 Alertmanager 配置

创建 `values/alertmanager-config.yaml`：

```yaml
# ═══════════════════════════════════════════
# Alertmanager Config — QQ 邮件告警
# ═══════════════════════════════════════════
apiVersion: v1
kind: Secret                         # 用 Secret 而非 ConfigMap，避免明文暴露密码
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yml: |
    # ── 全局配置 ──
    global:
      resolve_timeout: 5m            # 告警自动恢复的超时时间
      smtp_from: "3036186400@qq.com"
      smtp_smarthost: "smtp.qq.com:465"   # QQ 邮箱 SSL 端口
      smtp_auth_username: "3036186400@qq.com"
      smtp_auth_password: "请替换为你的QQ邮箱授权码"   # ← ⚠️ 这里替换！
      smtp_require_tls: true

    # ── 路由规则 ──
    route:
      group_by: ['alertname']        # 按告警名称分组
      group_wait: 30s                # 组内等待时间（收集同类告警）
      group_interval: 5m            # 组内发送间隔
      repeat_interval: 4h           # 重复告警间隔（不频繁打扰）
      receiver: 'qq-email'          # 默认接收器

    # ── 抑制规则（避免重复告警风暴）──
    inhibit_rules:
    - source_match:
        severity: 'critical'        # critical 告警会抑制同节点的 warning
      target_match:
        severity: 'warning'
      equal: ['node']

    # ── 接收器 ──
    receivers:
    - name: 'qq-email'
      email_configs:
      - to: "3036186400@qq.com"
        send_resolved: true          # 告警恢复时也发通知
```

### 8.3 应用配置

```bash
# 创建 Secret
kubectl apply -f values/alertmanager-config.yaml

# 🔄 重启 Alertmanager 加载新配置
kubectl rollout restart deployment prometheus-alertmanager -n monitoring

# 等待重启完成
kubectl rollout status deployment prometheus-alertmanager -n monitoring

# 验证配置是否加载成功
kubectl logs -n monitoring -l app=prometheus,component=alertmanager --tail=20
# 预期：无 error 日志，看到 "completed loading of config"
```

---

## 9. 自定义告警规则

### 9.1 创建告警规则

创建 `values/prometheus-alerts.yaml`：

```yaml
# ═══════════════════════════════════════════
# Prometheus 告警规则
# ═══════════════════════════════════════════
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: monitoring
  labels:
    app: prometheus
    release: prometheus
data:
  # ── 自定义告警规则集 ──
  alerts.yml: |
    groups:
    - name: k8s-node-alerts
      interval: 30s
      rules:
      - alert: NodeHighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m                 # 持续 5 分钟才触发，避免毛刺
        labels:
          severity: warning
        annotations:
          summary: "节点 {{ $labels.node }} 内存使用率超过 85%"
          description: "当前使用率: {{ $value | humanize }}%"

      - alert: NodeDiskRunningOut
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "节点 {{ $labels.node }} 磁盘剩余不足 10%"

    - name: k8s-pod-alerts
      interval: 30s
      rules:
      - alert: PodFrequentRestart
        expr: rate(kubelet_pod_container_status_restarts_total[10m]) > 3
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} 频繁重启（10分钟内 > 3次）"

    - name: k8s-service-alerts
      interval: 30s
      rules:
      - alert: PrometheusTargetMissing
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Prometheus 采集目标 {{ $labels.job }}/{{ $labels.instance }} 不可达"
```

> ⚠️ **注意**：上面使用了 `kubelet_pod_container_status_restarts_total`（kubelet 原生指标），
> 而不是 `kube_pod_container_status_restarts_total`（kube-state-metrics 指标）。
> 因为我们禁用了 kube-state-metrics，所以必须用原生指标。

### 9.2 挂载到 Prometheus

```bash
# 应用 ConfigMap
kubectl apply -f values/prometheus-alerts.yaml

# 🔄 重启 Prometheus 加载新规则
kubectl rollout restart deployment prometheus-server -n monitoring
kubectl rollout status deployment prometheus-server -n monitoring

# 验证规则已加载
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
curl -s http://localhost:9090/api/v1/rules | python3 -c "
import sys,json
d=json.load(sys.stdin)
groups = d['data']['groups']
print(f'告警规则组数: {len(groups)}')
for g in groups:
    print(f'  └─ {g[\"name\"]}: {len(g[\"rules\"])} 条规则')
"
kill %1 2>/dev/null

# 清理端口转发
kill %1 2>/dev/null
```

---

## 10. 全链路验证

执行以下命令，逐项确认平台运行正常：

```bash
# ═══════════════════════════════════════════
# 完整验证脚本 run when you want to check everything
# ═══════════════════════════════════════════

echo "═══════════════════════════════════════"
echo "  🔍 全链路健康检查"
echo "═══════════════════════════════════════"

# 1️⃣ 命名空间
echo ""
echo "📦 [1/8] 命名空间"
kubectl get ns monitoring --no-headers 2>/dev/null \
  && echo "  ✅ monitoring 存在" \
  || echo "  ❌ monitoring 不存在"

# 2️⃣ 所有 Pod
echo ""
echo "📦 [2/8] 所有 Pod 状态"
kubectl get pods -n monitoring -o wide --no-headers 2>/dev/null \
  | awk '{printf "  %-40s %-12s %s\n", $1, $3, $6}'

# 3️⃣ Service
echo ""
echo "📦 [3/8] Service 端点"
kubectl get svc -n monitoring --no-headers 2>/dev/null \
  | awk '{printf "  %-35s %-10s %s\n", $1, $2, $4}'

# 4️⃣ Prometheus 目标健康
echo ""
echo "📦 [4/8] Prometheus Targets"
POD=$(kubectl get pods -n monitoring -l app=prometheus,component=server -o name 2>/dev/null | head -1)
if [ -n "$POD" ]; then
  kubectl exec -n monitoring $POD -- wget -q -O- http://localhost:9090/api/v1/targets 2>/dev/null \
    | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    targets=d['data']['activeTargets']
    up=sum(1 for t in targets if t['health']=='up')
    print(f'  ✅ 健康: {up}/{len(targets)}')
except:
    print('  ⚠️ 无法解析')
  " 2>/dev/null || echo "  ⚠️ 无法获取"
else
  echo "  ⚠️ Prometheus Pod 未找到"
fi

# 5️⃣ Loki
echo ""
echo "📦 [5/8] Loki Ready"
kubectl exec -n monitoring $POD -- wget -q -O- http://loki.monitoring:3100/ready 2>/dev/null \
  | grep -q "Ready" && echo "  ✅ Loki Ready" || echo "  ⚠️ Loki 未就绪"

# 6️⃣ Metrics Server
echo ""
echo "📦 [6/8] Metrics Server"
kubectl top nodes --no-headers 2>/dev/null \
  | awk '{printf "  %-20s CPU: %-6s MEM: %s\n", $1, $2, $4}' \
  || echo "  ❌ kubectl top 不可用"

# 7️⃣ HPA
echo ""
echo "📦 [7/8] HPA 状态"
kubectl get hpa -A --no-headers 2>/dev/null \
  | awk '{printf "  %-20s %-10s %s\n", $2, $5, $6}' \
  || echo "  ✅ 无 HPA 配置（正常）"

# 8️⃣ Grafana 可达
echo ""
echo "📦 [8/8] Grafana"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
echo "  🔗 http://$NODE_IP:30300"
echo "  👤 admin / admin123"

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ 检查完成"
echo "═══════════════════════════════════════"
```

---

## 11. 日常维护与排错

### 11.1 日常操作

```bash
# ── 查看所有组件状态 ──
kubectl get pods -n monitoring -o wide

# ── 查看实时日志 ──
kubectl logs -n monitoring -l app=prometheus,component=server --tail=50 -f
kubectl logs -n monitoring -l app=loki --tail=50 -f

# ── 端口转发（本地调试）──
kubectl port-forward -n monitoring svc/prometheus-server 9090:80  # Prometheus Web UI
kubectl port-forward -n monitoring svc/loki 3100:3100             # Loki API
kubectl port-forward -n monitoring svc/grafana 8080:80            # Grafana

# ── 检查告警 ──
# Prometheus Alerts: http://localhost:9090/alerts
# Alertmanager UI:   kubectl port-forward svc/prometheus-alertmanager 9093:9093 -n monitoring
#                    http://localhost:9093
```

### 11.2 组件升级

```bash
# 安全升级流程（先拉取最新 Chart，再更新）
helm repo update
helm upgrade prometheus prometheus-community/prometheus \
  -n monitoring \
  --values values/prometheus.yaml \
  --atomic \
  --timeout 10m \
  --wait

# 升级失败自动回滚（--atomic 自带回滚能力）
```

### 11.3 故障排错速查

| 症状 | 诊断命令 | 常见原因 | 解决 |
|------|---------|---------|------|
| Pod Pending | `kubectl describe pod -n monitoring <pod>` | 资源不足 | 调低 resources 或加节点 |
| Pod CrashLoopBackOff | `kubectl logs -n monitoring <pod>` | OOM / 配置错误 | 调大 limits.memory 或修正配置 |
| `kubectl top` 无数据 | `kubectl logs -n kube-system -l k8s-app=metrics-server` | 证书问题 | 确保 `--kubelet-insecure-tls` 已加 |
| Grafana 连不上 Prometheus | `kubectl exec -n monitoring deploy/grafana -- wget -q -O- http://prometheus-server.monitoring:80/-/ready` | Service DNS 不通 | 确认 Service 名称正确 |
| Loki 无日志 | `kubectl logs -n monitoring -l app=promtail` | Promtail 配置错误 | 确认 promtail 能连 Loki |
| HPA 不触发 | `kubectl describe hpa -n default <hpa-name>` | 指标未采集 | 确认 `kubectl top pods` 有数据 |
| 告警邮件收不到 | `kubectl logs -n monitoring -l app=prometheus,component=alertmanager` | 授权码错误 | 重新生成 QQ 邮箱授权码 |

### 11.4 一键清理（卸载所有组件）

```bash
# ⚠️ 谨慎执行！会删除所有数据和配置
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 附录A：完整资源清单

### 最终资源占用（全部组件启动后）

```bash
kubectl top pods -n monitoring
```

预期大致消耗：

| 组件 | 内存 (实际) | CPU | 副本 | 类型 |
|------|-----------|-----|------|------|
| prometheus-server | ~180Mi | ~10m | 1 | Deployment |
| prometheus-alertmanager | ~30Mi | ~5m | 1 | Deployment |
| prometheus-node-exporter | ~20Mi | ~5m | 每节点 1 | DaemonSet |
| loki | ~90Mi | ~8m | 1 | Deployment |
| promtail | ~40Mi | ~3m | 每节点 1 | DaemonSet |
| grafana | ~60Mi | ~5m | 1 | Deployment |
| metrics-server | ~30Mi | ~5m | 1 | Deployment |
| **合计** | **~450Mi** | **~40m** | — | — |

> 实际占用比 requests 更低，因为 Prometheus 的 TSDB 和 Loki 的存储会在运行时逐渐增加内存使用。

### Helm Chart 版本参考

| Chart | 仓库 | 推荐版本 |
|-------|------|---------|
| prometheus | prometheus-community/prometheus | 25.x+ |
| loki-stack | grafana/loki-stack | 2.9.x+ |
| grafana | grafana/grafana | 8.x+ |

---

## 附录B：回滚操作速查

```bash
# ── Helm 回滚到上一个版本 ──
helm rollback prometheus -n monitoring
helm rollback loki -n monitoring
helm rollback grafana -n monitoring

# ── 查看 Helm 发布历史 ──
helm history prometheus -n monitoring

# ── 回滚到指定版本 ──
helm rollback prometheus 1 -n monitoring   # 回滚到第 1 版

# ── 删除并重装（最彻底的恢复方式）──
helm uninstall prometheus -n monitoring
# 修正 values 文件后再重新 helm install
```

---

> **维护者**：Hermes Agent | **更新**：自动同步至 [z0r0l0/resources](https://github.com/z0r0l0/resources)
