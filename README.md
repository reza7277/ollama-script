<div align="center">

```
██████╗ ███████╗███████╗ █████╗     ███████╗██████╗ ███████╗███████╗
██╔══██╗██╔════╝╚══███╔╝██╔══██╗    ╚════██║╚════██╗╚════██║╚════██║
██████╔╝█████╗    ███╔╝ ███████║        ██╔╝ █████╔╝    ██╔╝    ██╔╝
██╔══██╗██╔══╝   ███╔╝  ██╔══██║       ██╔╝ ██╔═══╝    ██╔╝    ██╔╝
██║  ██║███████╗███████╗██║  ██║       ██║  ███████╗   ██║     ██║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝  ╚══════╝   ╚═╝     ╚═╝
```

**A full-featured, interactive Bash manager for Ollama LLMs**

[![Version](https://img.shields.io/badge/version-2.0.0-cyan?style=flat-square)](https://github.com/Web3loverz/ollama-manager)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-blue?style=flat-square)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-orange?style=flat-square)](#)
[![Telegram](https://img.shields.io/badge/Telegram-Web3loverz-2CA5E0?style=flat-square&logo=telegram)](https://t.me/Web3loverz)

</div>

---

## Overview

**Ollama Manager** is a single-file Bash script that gives you a polished, menu-driven TUI (terminal UI) for managing your local LLMs through [Ollama](https://ollama.com). No Python, no Node — just `bash`, `curl`, `jq`, and `zstd`.

It lets you browse the full Ollama model library, download models with quantization control, run interactive chats, manage your model collection, and view detailed hardware/GPU status — all from one unified interface.

---

## Features

| Category | Capabilities |
|---|---|
| **Download** | Browse 200+ models from ollamadb.dev, search & filter by type, paginated table view, queue multiple downloads |
| **Quantization** | Choose from q4_0, q4_K_M, q5_0, q5_K_M, q8_0, f16, or default |
| **Chat** | Interactive terminal chat, system prompt presets, custom temperature & context size, chat history saving |
| **Model Management** | View, delete, copy/rename, update all, create custom Modelfiles |
| **API Mode** | Load any model into the REST API server and get ready-to-use `curl` examples |
| **System Info** | RAM, CPU, GPU (NVIDIA/AMD), disk usage, Ollama version & update check |
| **Smart Checks** | RAM/disk warnings before download, resource usage estimates |
| **Auto-setup** | Detects and installs missing dependencies (`curl`, `jq`, `zstd`), installs Ollama if not present |
| **Offline Fallback** | Built-in curated model list when ollamadb.dev is unreachable |
| **Caching** | Model list cached for 1 hour to minimize API calls |

### System Prompt Presets

- None (default)
- Persian / English Translator
- Code Reviewer
- DevOps Assistant
- Bash Script Expert
- Security Analyst
- Data Scientist
- Technical Writer
- Custom (type your own)

---

## Requirements

| Dependency | Purpose | Auto-installed? |
|---|---|---|
| `curl` | API calls & Ollama install | Yes (apt/yum/pacman) |
| `jq` | JSON parsing | Yes (apt/yum/pacman) |
| `zstd` | Ollama extraction | Yes (apt/yum/pacman) |
| `ollama` | LLM runtime | Yes (prompted) |

**OS:** Linux (Debian/Ubuntu, RHEL/CentOS/Fedora, Arch)

> The script also works on WSL2 (Windows Subsystem for Linux).

---

## Installation

```bash
# Clone the repository
git clone https://github.com/reza7277/ollama-script.git
cd ollama-script

# Make it executable
chmod +x ollama_manager.sh

# Run it
./ollama_manager.sh
```

Or as a one-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/reza7277/ollama-script/refs/heads/main/ollama_manager.sh)
```

---

## Usage

```
./ollama_manager.sh
```

On first launch the script will:
1. Check for `curl`, `jq`, and `zstd` — offer to install any that are missing
2. Check if Ollama is installed — offer to install it automatically
3. Check if the Ollama service is running — offer to start it

### Main Menu

```
╔══════════════════════════════════════════════════════════╗
║                       MAIN MENU                          ║
╠══════════════════════════════════════════════════════════╣
║  1   Download & Setup Models                             ║
║      Browse & download from the full Ollama library      ║
║                                                          ║
║  2   Run Downloaded Models (Offline)                     ║
║      Chat with your installed models — no internet needed║
║                                                          ║
║  3   Model Management                                    ║
║      View, delete, copy, update models                   ║
║                                                          ║
║  4   System Info & Status                                ║
║      Hardware info, GPU, Ollama logs, update check       ║
║                                                          ║
║  5   Exit                                                ║
╚══════════════════════════════════════════════════════════╝
```

### Download Section Commands

| Command | Action |
|---|---|
| `n` | Next page |
| `p` | Previous page |
| `s` | Search by name or description |
| `i <num>` | Show detailed info for model |
| `d <num>` | Download model immediately |
| `a <num> [num ...]` | Add to download queue |
| `q` | Download queued models & exit |
| `b` | Back to main menu |

### Configuration

Settings are stored in `~/.ollama_manager/config.conf`:

```bash
DEFAULT_TEMPERATURE=0.7
DEFAULT_CONTEXT=4096
AUTO_START_OLLAMA=true
SAVE_CHAT_HISTORY=true
MODELS_PER_PAGE=15
```

### Chat History

When `SAVE_CHAT_HISTORY=true`, every chat session is saved to:

```
~/.ollama_manager/chats/YYYY-MM-DD_HH-MM-SS_modelname.txt
```

You can view saved sessions from **System Info > View saved chat history**.

### API Server Mode

Select **Run > Start API Server only** to load a model and get instant copy-paste API examples:

```bash
# Generate
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.2","prompt":"Hello!"}'

# Chat
curl http://localhost:11434/api/chat \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello!"}]}'
```

---

## Model Categories

| Filter | Description |
|---|---|
| **All** | Every available model |
| **Chat** | General-purpose conversational models |
| **Vision** | Multimodal models (image + text) |
| **Code** | Code generation & review specialists |
| **Embedding** | Vector embedding models for RAG/search |

---

## Popular Models (Built-in Fallback List)

| Model | Size | Best For |
|---|---|---|
| `llama3.2` | 2.0 GB | General chat, fast |
| `llama3.1` | 4.7 GB | Balanced quality |
| `mistral` | 4.1 GB | Fast & accurate |
| `qwen2.5` | 4.7 GB | Multilingual |
| `deepseek-r1` | 4.7 GB | Reasoning |
| `qwen2.5-coder` | 4.7 GB | Code |
| `gemma3` | 3.3 GB | Multimodal |
| `nomic-embed-text` | 274 MB | Embeddings / RAG |

---

## File Structure

```
~/.ollama_manager/
├── config.conf          # User settings
├── model_cache.json     # Cached model list (1h TTL)
├── ollama.log           # Ollama service log
└── chats/               # Saved chat sessions
    └── 2026-02-19_...   # Timestamped transcripts
```

---

## Screenshots

> Coming soon — contributions welcome!

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create your branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Author

**Reza** — [@Web3loverz](https://t.me/Web3loverz)

> Join the Telegram channel for updates, tips, and community support.

---

<div align="center">
<sub>Made with ❤️ for the self-hosted AI community</sub>
</div>
