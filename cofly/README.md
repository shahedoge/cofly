# Cofly

Cofly 是一个消息系统，愿景是提供一个可插拔的、通过公网提供服务的Claw类应用消息转发接口。

## 与官方App的不同

OpenClaw官方App主要侧重个人使用，Cofly可以配合多Agent和多workspace，方便小团队内每名成员都拥有一个Agent，同时摆脱现有channel的API rate limit，并且只暴露有限的接口到公网。

## 与OpenClaw共同使用

### 安装OpenClaw和clawdbot-feishu插件

首先安装好OpenClaw和clawdbot-feishu插件。

```bash
# 安装OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash
# 安装feishu插件
openclaw plugins install @m1heng-clawd/feishu
```

> [!IMPORTANT]
> OpenClaw现已引入官方对feishu的支持，为了避免插件撞车，可以在安装好OpenClaw之后、安装clawdbot-feishu插件之前，先通过`openclaw plugins list`，找到@openclaw-feishu官方插件的目录，然后rm -rf该目录。
> 目前只测试了在clawdbot-feishu插件上的兼容情况，仅限聊天。

然后，通过`openclaw config`配置feishu插件。在这里，`app id`和`app secret`可以随意设计，因为我们无需在飞书上实际创建机器人。

### 安装Cofly API

克隆本仓库，创建Python环境，安装依赖。

> [!NOTE]
> 接下来的内容属于“一步步安装”范畴，如果只是想快速体验，或具有丰富经验，可以跳过。

```bash
# 克隆仓库
git clone https://github.com/shahedoge/cofly.git
# 进入代码目录
cd cofly
# 创建Python环境
conda create -n cofly python=3.13
conda activate cofly
# 安装依赖
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
# 安装pm2
npm install pm2 -g
# 进入api目录
cd cofly
```

正式运行前，我们还需要修改`cofly/config.py`，将`SECRET_KEY`和`REGISTRATION_TOKEN`修改为你认为安全的值。下面我们来开启API服务。

```
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name "my_api"
# 设置开机自启动
pm2 save
pm2 startup
```

现在，在本地的8000端口已经跑起来了API服务。我们需要注册bot。修改`cofly/seed_bot.py`，将`DEFAULT_BOTS`中的`<bot app id>`和`<bot app secret>`替换为实际的bot app id和app secret，还可以修改`cofly/seed_bot.py`中的`display_name`（虽然目前暂时没什么用）。然后运行`cofly/seed_bot.py`。如果一切顺利，我们就已经注册好了bot。

为了让我们的服务在公网上可用，还需要将本地8000端口暴露出去，可以使用`ngrok`、`frp`、`cpolar`等工具。

假设你的8000端口被反向代理到了`https://cofly.cpolar.cn`，那么，我们还需要修改`~/.openclaw/openclaw.json`，将`feishu`插件的`api url`修改为`https://cofly.cpolar.cn`。示例：

```json
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_a9f1ed06c1449bc7",
      "appSecret": "9S0k4ur6Lv",
      "domain": "https://cofly.cpolar.cn",
      "groupPolicy": "open",
      "dmPolicy": "open",
      "allowFrom": [
        "*"
      ],
    }
  }
```

现在，你可以在App上连接到OpenClaw实例。在为自己注册用户时，注册码即为上面你自行设定的`REGISTRATION_TOKEN`。

## App的使用（以macOS为例）

App初始化时，会要求填入API URL、用户信息、bot信息等，保持与设定的相一致即可。在GitHub release中也能够下载到macOS dmg。

### macOS截图

![image](preview/setup.png)

![image](preview/use.png)

## 代码

代码由Claude和MiniMax共同完成。

Logo由Gemini设计。