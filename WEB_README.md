# WRAP · 星际远征 v0.9.0 - Web 浏览器畅玩指南

本游戏已成功逆向分析并改造为支持在 **现代 Web 浏览器（尤其是 Google Chrome）** 上即开即玩的 WebAssembly / WebGL2 版本！

---

## 🎮 快速开始游玩

### 方式一：一键启动脚本（推荐）
* **macOS / Linux**:
  打开终端，进入本目录运行：
  ```bash
  ./start_web.sh
  ```
  脚本会自动检测环境并启动本地服务，直接调用 Chrome 浏览器打开游戏页面。

* **Windows**:
  直接双击运行：
  ```cmd
  start_web.bat
  ```

### 方式二：手动启动本地服务
在当前目录运行以下任意一种服务即可：

* **Node.js（推荐，性能最高）**：
  ```bash
  node server.js
  ```
* **Python 3**：
  ```bash
  python3 server.py
  ```

随后在 **Google Chrome**（或 Edge / Firefox / Safari）中访问：
👉 **`http://localhost:8080`**

---

## 🌟 改造亮点与核心技术实现

1. **引擎逆向与精准匹配**：
   - 深入逆向分析原版 Windows 64位二进制文件 `WRAP.exe` 与 `WRAP.pck`。
   - 提取出其核心引擎版本为 **Godot Engine v4.7.2.stable**，渲染器为 **GL Compatibility (WebGL 2)**。
   - 解析 Godot 4 的 GDPC 数据包格式（4字节对齐路径、0x70基础偏移、ZSTD压缩字节码）。

2. **跨平台 WebAssembly 运行时移植**：
   - 匹配并整合了官方 Godot 4.7.2 WebAssembly 运行时（`wasm32`）。
   - 采用免多线程（`nothreads`）架构，无需复杂的跨域隔离头，在任何标准浏览器环境下均可稳定秒开。

3. **数据持久化与自动读写**：
   - 游戏内部 `user://` 虚拟文件系统已无缝挂载至浏览器的 **IndexedDB (`/userfs`)**。
   - 玩家的远征进度（`savegame-scifi.json`）、卡组构筑（`decks.json`）、个性化设置（`settings.json`）在刷新或重启浏览器后均自动保存，与原生客户端体验完全一致。

4. **精致的 Web 交互与全屏支持**：
   - 适配 Chrome 音频自动播放策略（AudioContext 自动无缝解锁）。
   - 内置响应式加载进度条（显示精确百分比及已加载 MB 数）。
   - 页面右下角贴心集成一键全屏切换按钮。

---

## 🚀 线上部署与托管

`web_build/` 文件夹为完整的静态网站产物，支持直接部署到任何静态网站托管服务：

* **GitHub Pages** / **Cloudflare Pages** / **Vercel**
* **Nginx** / **Caddy** / **Apache**
* **局域网分享**：服务默认监听 `0.0.0.0:8080`，局域网内的手机、平板、电脑只需输入主机局域网 IP（例如 `http://192.168.1.x:8080`）即可同局游玩！
