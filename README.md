# WRAP · 星际远征 v0.9.0 (Web & Android Port)

> 🚀 原生 Windows 桌面卡牌对战游戏《WRAP · 星际远征》的跨平台逆向移植与优化版本，支持全功能 Web 浏览器（Chrome / Edge / Firefox / Safari）秒开游玩与移动端/Android APK 原生运行。

---

## 🌐 在线体验

* **官方在线体验地址**：👉 **[https://wrap.tpgofighting.top](https://wrap.tpgofighting.top)**
* **加载优化**：全包经过纹理深度重压缩与 WASM Gzip 静态预压缩，整站体积从 247 MB 缩减至 **27.5 MB**，公网首屏仅需 **3.4 秒** 秒开。
* **存档持久化**：卡组配置、战役进度由浏览器 **IndexedDB (`/userfs`)** 本地自动保存。

---

## 🎮 游戏特色

* **战术构筑**：121 张特色科幻卡牌，涵盖先锋、灵能、机械、异虫等多元族群；
* **三区争夺**：Alpha、Beta、Gamma 三大战区轮番揭示与结算，考验战术能量分配与临场应变；
* **跨平台兼容**：基于 WebAssembly + WebGL 2.0 / Android OpenGLES 3.0，流畅稳定。

---

## 📁 目录结构

```
.
├── web_build/               # Web 生产运行目录 (WASM, JS, PCK, HTML)
│   ├── index.html           # 定制化加载器与响应式 UI 容器
│   ├── WRAP.wasm            # Godot 4.7.2 核心 WebAssembly 二进制 (38MB)
│   ├── WRAP.wasm.gz         # WASM Gzip 静态预压缩版 (9.58MB)
│   ├── WRAP.pck             # 深度瘦身优化后的游戏数据包 (18MB)
│   └── WRAP.js              # 引擎桥接与胶水代码
├── unpacked_pck_opt/        # 逆向解包且包含 800px 高清优化 WebP 纹理的项目工程
├── licenses/                # 第三方许可与引擎授权协议
├── server.js                # 本地 Node.js 静态 HTTP/2 & COOP/COEP 服务
├── server.py                # 本地 Python 静态服务
├── start_web.sh             # macOS / Linux 一键本地运行脚本
├── start_web.bat            # Windows 一键本地运行脚本
└── README.md
```

---

## 💻 本地运行指南

### 方法一：使用 Node.js（推荐）
```bash
node server.js
```
浏览器打开 `http://localhost:8080`。

### 方法二：使用 Python 3
```bash
python3 server.py 8080
```
浏览器打开 `http://localhost:8080`。

### 方法三：一键脚本
* **macOS / Linux**: `./start_web.sh`
* **Windows**: 双击 `start_web.bat`

---

## 🛠️ 移植与优化技术亮点

1. **引擎运行时逆向对齐**：定位原生 `WRAP.exe` 的 Godot 4.7.2 `gl_compatibility` 渲染架构，精确匹配无线程版 WebAssembly 核心；
2. **虚拟文件系统透明挂载**：将游戏内置 `user://` 文件访问无感知重定向至浏览器的 IndexedDB 虚拟存储；
3. **`.ctex` 纹理二进制重构**：逆向提取 147 张卡牌的 56 字节 `StreamTexture2D` 头部，将无损 WebP 插画重构为高保真 800px Q82 WebP，体积从 184.8MB 暴降至 5.3MB（-97.1%）；
4. **Godot 4 `GDPC` 二进制重新封包**：自研打包算法重新生成合规对齐的 18.0MB `WRAP.pck`。

---

## 📜 许可证

本项目所含原游戏代码与美术资产版权归原作者所有，移植改造脚本与配置文件遵循开源协议。
