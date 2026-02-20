# Docker 快速使用

## 1) 构建镜像

```bash
docker compose build
```

## 2) 启动 Jupyter

```bash
docker compose up -d
docker compose logs --tail 50 handson-polyhedral
```

直接访问日志里的 URL（含 token），或用 `http://localhost:8888`。

如果需要单独查看 token：

```bash
docker compose logs --tail 200 handson-polyhedral | grep -Eo 'http://127.0.0.1:8888/lab\\?token=[^[:space:]]+' | tail -n 1
```

## 3) Notebook 内核选择

- `handson-polyhedral (py312)`：除 08-11 外
- `handson-polyhedral (py312+pet)`：08-11

## 4) 一键回归（容器内跑全部 ipynb）

```bash
docker compose exec handson-polyhedral bash -lc \
  "source /opt/venv/bin/activate && cd /workspace/handson-polyhedral && \
   python run_notebooks.py --output .nbtest_logs/docker_results.jsonl --timeout 600"
```

结果文件：`.nbtest_logs/docker_results.jsonl`

## 5) 关闭

```bash
docker compose down
```
