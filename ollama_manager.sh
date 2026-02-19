#!/bin/bash
# =============================================================================
#  OLLAMA MANAGER — Full-Featured LLM Download & Run Tool
#  Created by: Reza | https://t.me/Web3loverz
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# GLOBALS & CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_VERSION="2.0.0"
OLLAMA_API="http://localhost:11434"
OLLAMADB_API="https://ollamadb.dev/api/v1/models"
OLLAMA_INSTALL_URL="https://ollama.com/install.sh"
MANAGER_DIR="$HOME/.ollama_manager"
CACHE_FILE="$MANAGER_DIR/model_cache.json"
CONFIG_FILE="$MANAGER_DIR/config.conf"
CHATS_DIR="$MANAGER_DIR/chats"
CACHE_TTL=3600  # 1 hour in seconds
MODELS_PER_PAGE=15

# ─────────────────────────────────────────────────────────────────────────────
# COLORS & STYLES
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
BG_BLUE='\033[44m'
BG_CYAN='\033[46m'

# Box drawing chars
TL='╔'; TR='╗'; BL='╚'; BR='╝'
H='═'; V='║'
ML='╠'; MR='╣'
TJ='╦'; BJ='╩'; CJ='╬'

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────
init_dirs() {
    mkdir -p "$MANAGER_DIR" "$CHATS_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
DEFAULT_TEMPERATURE=0.7
DEFAULT_CONTEXT=4096
AUTO_START_OLLAMA=true
SAVE_CHAT_HISTORY=true
MODELS_PER_PAGE=15
EOF
    fi
    source "$CONFIG_FILE" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────────────────────────────────────
show_header() {
    clear
    echo -e "${CYAN}"
    echo "██████╗ ███████╗███████╗ █████╗     ███████╗██████╗ ███████╗███████╗"
    echo "██╔══██╗██╔════╝╚══███╔╝██╔══██╗    ╚════██║╚════██╗╚════██║╚════██║"
    echo "██████╔╝█████╗    ███╔╝ ███████║        ██╔╝ █████╔╝    ██╔╝    ██╔╝"
    echo "██╔══██╗██╔══╝   ███╔╝  ██╔══██║       ██╔╝ ██╔═══╝    ██╔╝    ██╔╝ "
    echo "██║  ██║███████╗███████╗██║  ██║       ██║  ███████╗   ██║     ██║  "
    echo "╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝  ╚══════╝   ╚═╝     ╚═╝  "
    echo -e "${RESET}"
    echo -e "${DIM}  created by: ${WHITE}Reza${RESET}  ${DIM}|  Join us: ${CYAN}https://t.me/Web3loverz${RESET}  ${DIM}|  v${SCRIPT_VERSION}${RESET}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────
draw_line() {
    local width="${1:-70}"
    local char="${2:-─}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

draw_box() {
    local title="$1"
    local width="${2:-70}"
    local inner=$((width - 2))
    local title_len=${#title}
    local pad_left=$(( (inner - title_len) / 2 ))
    local pad_right=$(( inner - title_len - pad_left ))
    echo -e "${CYAN}${TL}$(printf '%*s' "$inner" '' | tr ' ' "$H")${TR}${RESET}"
    echo -e "${CYAN}${V}${RESET}$(printf '%*s' "$pad_left" '')${BOLD}${WHITE}${title}${RESET}$(printf '%*s' "$pad_right" '')${CYAN}${V}${RESET}"
    echo -e "${CYAN}${ML}$(printf '%*s' "$inner" '' | tr ' ' "$H")${MR}${RESET}"
}

draw_box_bottom() {
    local width="${1:-70}"
    local inner=$((width - 2))
    echo -e "${CYAN}${BL}$(printf '%*s' "$inner" '' | tr ' ' "$H")${BR}${RESET}"
}

print_success() { echo -e " ${GREEN}✔${RESET}  $1"; }
print_error()   { echo -e " ${RED}✘${RESET}  $1"; }
print_warn()    { echo -e " ${YELLOW}⚠${RESET}  $1"; }
print_info()    { echo -e " ${CYAN}ℹ${RESET}  $1"; }
print_step()    { echo -e " ${MAGENTA}→${RESET}  $1"; }

prompt_enter() {
    echo ""
    echo -e " ${DIM}Press ${WHITE}[Enter]${RESET}${DIM} to continue...${RESET}"
    read -r
}

confirm() {
    local msg="${1:-Are you sure?}"
    echo -e " ${YELLOW}?${RESET}  ${msg} ${DIM}[y/N]${RESET}: "
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# SPINNER
# ─────────────────────────────────────────────────────────────────────────────
SPINNER_PID=""
spinner_start() {
    local msg="${1:-Loading...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    (
        local i=0
        while true; do
            printf "\r ${CYAN}${frames[$i]}${RESET}  ${msg}   "
            i=$(( (i+1) % ${#frames[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

spinner_stop() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r%80s\r" ""
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DEPENDENCY CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in curl jq zstd; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warn "Missing dependencies: ${missing[*]}"
        echo ""
        if confirm "Install missing dependencies now?"; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get install -y "${missing[@]}" -qq
            elif command -v yum &>/dev/null; then
                sudo yum install -y "${missing[@]}"
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm "${missing[@]}"
            else
                print_error "Cannot auto-install. Please install: ${missing[*]}"
                exit 1
            fi
            print_success "Dependencies installed."
        else
            print_error "Cannot continue without dependencies."
            exit 1
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# NETWORK / FIREWALL
# ─────────────────────────────────────────────────────────────────────────────
ensure_api_access() {
    local host="ollamadb.dev"
    local port=443

    # Already reachable — nothing to do
    if curl -s --max-time 5 "https://$host" &>/dev/null; then
        return 0
    fi

    print_warn "Cannot reach $host — attempting to open outbound port $port..." >&2
    echo "" >&2
    local opened=false

    # ── UFW ──────────────────────────────────────────────────────────────────
    if command -v ufw &>/dev/null; then
        if sudo ufw status 2>/dev/null | grep -q "active"; then
            if sudo ufw allow out proto tcp to any port "$port" comment 'ollama-manager' &>/dev/null; then
                print_success "UFW: allowed outbound HTTPS (port $port)" >&2
                opened=true
            fi
        fi
    fi

    # ── firewalld ────────────────────────────────────────────────────────────
    if command -v firewall-cmd &>/dev/null; then
        if firewall-cmd --state &>/dev/null; then
            if sudo firewall-cmd --permanent --add-service=https &>/dev/null && \
               sudo firewall-cmd --reload &>/dev/null; then
                print_success "firewalld: HTTPS service enabled" >&2
                opened=true
            fi
        fi
    fi

    # ── iptables (fallback) ───────────────────────────────────────────────────
    if ! $opened && command -v iptables &>/dev/null; then
        local ip
        ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
        if [[ -n "$ip" ]]; then
            if sudo iptables -I OUTPUT -d "$ip" -p tcp --dport "$port" -j ACCEPT &>/dev/null; then
                print_success "iptables: opened outbound to $host ($ip:$port)" >&2
                opened=true
            fi
        fi
    fi

    # ── Verify ───────────────────────────────────────────────────────────────
    sleep 1
    if curl -s --max-time 5 "https://$host" &>/dev/null; then
        print_success "Connection to $host established!" >&2
        return 0
    fi

    if $opened; then
        print_warn "Firewall rules updated but still blocked (likely cloud Security Group)." >&2
    else
        print_warn "Could not open firewall automatically." >&2
    fi
    print_info "To fix on cloud servers: allow outbound TCP 443 in your Security Group." >&2
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# OLLAMA ENGINE
# ─────────────────────────────────────────────────────────────────────────────
check_ollama_installed() {
    command -v ollama &>/dev/null
}

install_ollama() {
    echo ""
    draw_box "Installing Ollama" 70
    echo -e "${CYAN}${V}${RESET}"
    print_info "Downloading and installing Ollama..."
    print_info "Source: https://ollama.com/install.sh"
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70
    echo ""
    curl -fsSL "$OLLAMA_INSTALL_URL" | sh
    echo ""
    if check_ollama_installed; then
        print_success "Ollama installed successfully!"
        print_info "Version: $(ollama --version 2>/dev/null || echo 'unknown')"
    else
        print_error "Installation failed. Please install manually:"
        print_info "  curl -fsSL https://ollama.com/install.sh | sh"
        exit 1
    fi
    prompt_enter
}

check_ollama_running() {
    curl -s --max-time 2 "$OLLAMA_API/" &>/dev/null
}

start_ollama_service() {
    print_step "Starting Ollama service..."
    nohup ollama serve > "$MANAGER_DIR/ollama.log" 2>&1 &
    local attempts=0
    local max_attempts=15
    while ! check_ollama_running && [[ $attempts -lt $max_attempts ]]; do
        sleep 1
        ((attempts++))
        printf "\r ${CYAN}⠿${RESET}  Waiting for Ollama to start... ${DIM}(${attempts}s)${RESET}"
    done
    echo ""
    if check_ollama_running; then
        print_success "Ollama service is running on port 11434"
    else
        print_error "Failed to start Ollama service. Check logs: $MANAGER_DIR/ollama.log"
        return 1
    fi
}

ensure_ollama_ready() {
    if ! check_ollama_installed; then
        print_warn "Ollama is not installed."
        echo ""
        if confirm "Install Ollama now?"; then
            install_ollama
        else
            return 1
        fi
    fi

    if ! check_ollama_running; then
        print_warn "Ollama service is not running."
        if confirm "Start Ollama service now?"; then
            start_ollama_service || return 1
        else
            return 1
        fi
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM INFO
# ─────────────────────────────────────────────────────────────────────────────
get_ram_mb() {
    free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo "0"
}

get_total_ram_mb() {
    free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0"
}

get_disk_free_gb() {
    df -BG "$HOME" 2>/dev/null | awk 'NR==2{gsub("G","",$4); print $4}' || echo "0"
}

detect_gpu() {
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        local vram
        vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        echo "NVIDIA: $gpu_name (${vram}MB VRAM)"
    elif command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null 2>/dev/null; then
        echo "AMD (ROCm detected)"
    elif [[ -d /proc/driver/nvidia ]]; then
        echo "NVIDIA (driver present)"
    else
        echo "None (CPU-only mode)"
    fi
}

# Size string to MB for comparison (e.g., "4.7GB" → 4813, "500MB" → 500)
size_to_mb() {
    local size="${1:-0}"
    if [[ "$size" =~ ([0-9.]+)GB ]]; then
        echo "$(echo "${BASH_REMATCH[1]} * 1024" | bc | cut -d. -f1)"
    elif [[ "$size" =~ ([0-9.]+)MB ]]; then
        echo "${BASH_REMATCH[1]%.*}"
    else
        echo "0"
    fi
}

check_resource_warning() {
    local model_size="$1"
    local model_size_mb
    model_size_mb=$(size_to_mb "$model_size")
    local available_mb
    available_mb=$(get_ram_mb)
    local total_mb
    total_mb=$(get_total_ram_mb)
    local disk_gb
    disk_gb=$(get_disk_free_gb)

    if [[ $model_size_mb -gt 0 && $available_mb -gt 0 ]]; then
        local pct=$(( model_size_mb * 100 / total_mb ))
        if [[ $pct -gt 90 ]]; then
            print_warn "This model requires ~${model_size} but you have ${available_mb}MB RAM available!"
            print_warn "Performance may be very slow. Consider a smaller quantization."
            return 1
        elif [[ $pct -gt 70 ]]; then
            print_warn "This model requires ~${model_size}. RAM usage may be high (${pct}% of total)."
        fi
    fi

    local model_size_gb
    model_size_gb=$(echo "$model_size_mb / 1024" | bc 2>/dev/null || echo "0")
    if [[ $model_size_gb -gt $disk_gb ]]; then
        print_error "Insufficient disk space! Model: ~${model_size}, Available: ${disk_gb}GB"
        return 1
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# FETCH MODELS FROM API
# ─────────────────────────────────────────────────────────────────────────────

# Fallback model list (used when API is unreachable)
get_fallback_models() {
    cat << 'FALLBACK'
[
  {"name":"llama3.3","description":"Meta's latest Llama 3.3 model, great general-purpose 70B","parameter_size":"70B","size":"43GB","capabilities":["chat"],"pulls":3000000},
  {"name":"llama3.2","description":"Meta Llama 3.2 - fast and efficient small model","parameter_size":"3B","size":"2.0GB","capabilities":["chat"],"pulls":15000000},
  {"name":"llama3.2:1b","description":"Meta Llama 3.2 1B - ultra lightweight","parameter_size":"1B","size":"1.3GB","capabilities":["chat"],"pulls":5000000},
  {"name":"llama3.1","description":"Meta Llama 3.1 - 8B flagship model","parameter_size":"8B","size":"4.7GB","capabilities":["chat"],"pulls":20000000},
  {"name":"llama3.1:70b","description":"Meta Llama 3.1 70B - high performance","parameter_size":"70B","size":"40GB","capabilities":["chat"],"pulls":5000000},
  {"name":"mistral","description":"Mistral 7B - fast and accurate general model","parameter_size":"7B","size":"4.1GB","capabilities":["chat"],"pulls":18000000},
  {"name":"mistral-nemo","description":"Mistral NeMo 12B - excellent reasoning","parameter_size":"12B","size":"7.1GB","capabilities":["chat"],"pulls":3000000},
  {"name":"mixtral","description":"Mistral MoE 8x7B - high quality mixture of experts","parameter_size":"47B","size":"26GB","capabilities":["chat"],"pulls":4000000},
  {"name":"gemma3","description":"Google Gemma 3 - multimodal capable","parameter_size":"4B","size":"3.3GB","capabilities":["chat","vision"],"pulls":8000000},
  {"name":"gemma3:12b","description":"Google Gemma 3 12B - larger variant","parameter_size":"12B","size":"8.1GB","capabilities":["chat","vision"],"pulls":2000000},
  {"name":"gemma3:27b","description":"Google Gemma 3 27B - most powerful Gemma","parameter_size":"27B","size":"17GB","capabilities":["chat","vision"],"pulls":1000000},
  {"name":"qwen2.5","description":"Alibaba Qwen 2.5 - excellent multilingual","parameter_size":"7B","size":"4.7GB","capabilities":["chat"],"pulls":10000000},
  {"name":"qwen2.5:14b","description":"Alibaba Qwen 2.5 14B","parameter_size":"14B","size":"9.0GB","capabilities":["chat"],"pulls":4000000},
  {"name":"qwen2.5:32b","description":"Alibaba Qwen 2.5 32B - very capable","parameter_size":"32B","size":"20GB","capabilities":["chat"],"pulls":2000000},
  {"name":"qwen2.5:72b","description":"Alibaba Qwen 2.5 72B - top tier","parameter_size":"72B","size":"47GB","capabilities":["chat"],"pulls":1000000},
  {"name":"qwen2.5-coder","description":"Qwen 2.5 Coder - specialized for code","parameter_size":"7B","size":"4.7GB","capabilities":["chat","code"],"pulls":8000000},
  {"name":"qwen2.5-coder:14b","description":"Qwen 2.5 Coder 14B - advanced coding","parameter_size":"14B","size":"9.0GB","capabilities":["chat","code"],"pulls":3000000},
  {"name":"qwen2.5-coder:32b","description":"Qwen 2.5 Coder 32B - best coding model","parameter_size":"32B","size":"19GB","capabilities":["chat","code"],"pulls":1500000},
  {"name":"deepseek-r1","description":"DeepSeek R1 - strong reasoning model","parameter_size":"7B","size":"4.7GB","capabilities":["chat"],"pulls":9000000},
  {"name":"deepseek-r1:14b","description":"DeepSeek R1 14B","parameter_size":"14B","size":"9.0GB","capabilities":["chat"],"pulls":3000000},
  {"name":"deepseek-r1:32b","description":"DeepSeek R1 32B","parameter_size":"32B","size":"20GB","capabilities":["chat"],"pulls":2000000},
  {"name":"deepseek-r1:70b","description":"DeepSeek R1 70B - top reasoning","parameter_size":"70B","size":"43GB","capabilities":["chat"],"pulls":1000000},
  {"name":"deepseek-coder-v2","description":"DeepSeek Coder V2 - expert coding","parameter_size":"16B","size":"8.9GB","capabilities":["chat","code"],"pulls":5000000},
  {"name":"phi4","description":"Microsoft Phi-4 - compact yet powerful","parameter_size":"14B","size":"9.1GB","capabilities":["chat"],"pulls":5000000},
  {"name":"phi4-mini","description":"Microsoft Phi-4 Mini - very efficient","parameter_size":"3.8B","size":"2.5GB","capabilities":["chat"],"pulls":2000000},
  {"name":"phi3.5","description":"Microsoft Phi-3.5 - small but capable","parameter_size":"3.8B","size":"2.2GB","capabilities":["chat"],"pulls":3000000},
  {"name":"codellama","description":"Meta Code Llama - code generation","parameter_size":"7B","size":"3.8GB","capabilities":["chat","code"],"pulls":6000000},
  {"name":"codellama:13b","description":"Code Llama 13B","parameter_size":"13B","size":"7.4GB","capabilities":["chat","code"],"pulls":2000000},
  {"name":"codellama:34b","description":"Code Llama 34B - advanced code","parameter_size":"34B","size":"19GB","capabilities":["chat","code"],"pulls":1000000},
  {"name":"llava","description":"LLaVA - vision language model","parameter_size":"7B","size":"4.7GB","capabilities":["chat","vision"],"pulls":5000000},
  {"name":"llava:13b","description":"LLaVA 13B - larger vision model","parameter_size":"13B","size":"8.0GB","capabilities":["chat","vision"],"pulls":1500000},
  {"name":"llava:34b","description":"LLaVA 34B - highest vision quality","parameter_size":"34B","size":"20GB","capabilities":["chat","vision"],"pulls":500000},
  {"name":"nomic-embed-text","description":"Nomic text embeddings - for RAG/search","parameter_size":"137M","size":"274MB","capabilities":["embedding"],"pulls":10000000},
  {"name":"mxbai-embed-large","description":"MxBai large embeddings","parameter_size":"335M","size":"670MB","capabilities":["embedding"],"pulls":4000000},
  {"name":"all-minilm","description":"Sentence transformers - fast embeddings","parameter_size":"23M","size":"46MB","capabilities":["embedding"],"pulls":3000000},
  {"name":"starcoder2","description":"StarCoder2 - code completion model","parameter_size":"7B","size":"4.0GB","capabilities":["code"],"pulls":2000000},
  {"name":"command-r","description":"Cohere Command R - RAG optimized","parameter_size":"35B","size":"20GB","capabilities":["chat"],"pulls":1000000},
  {"name":"aya","description":"Cohere Aya - multilingual 101 languages","parameter_size":"8B","size":"4.8GB","capabilities":["chat"],"pulls":500000},
  {"name":"neural-chat","description":"Intel Neural Chat - optimized for Intel","parameter_size":"7B","size":"4.1GB","capabilities":["chat"],"pulls":1000000},
  {"name":"solar","description":"SOLAR - Korean/English excellent model","parameter_size":"10.7B","size":"6.1GB","capabilities":["chat"],"pulls":1000000}
]
FALLBACK
}

fetch_available_models() {
    # Check cache first
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    # Ensure outbound port 443 is open before fetching
    ensure_api_access >&2 || true

    # Try ollamadb.dev API
    spinner_start "Fetching model list from ollamadb.dev..." >&2
    local response
    response=$(curl -s --max-time 10 "${OLLAMADB_API}?limit=200&sort_by=pulls&order=desc" 2>/dev/null || echo "")
    spinner_stop >&2

    if echo "$response" | jq -e '.models' &>/dev/null; then
        local models
        models=$(echo "$response" | jq '.models')
        echo "$models" > "$CACHE_FILE"
        echo "$models"
        return 0
    fi

    # Fallback to embedded list
    print_warn "Could not reach ollamadb.dev — using built-in model list." >&2
    get_fallback_models | jq '.' > "$CACHE_FILE"
    get_fallback_models
}

# ─────────────────────────────────────────────────────────────────────────────
# MODEL TABLE DISPLAY
# ─────────────────────────────────────────────────────────────────────────────
format_pulls() {
    local n="$1"
    if [[ $n -ge 1000000 ]]; then
        echo "$(echo "scale=1; $n / 1000000" | bc)M"
    elif [[ $n -ge 1000 ]]; then
        echo "$(echo "scale=0; $n / 1000" | bc)K"
    else
        echo "$n"
    fi
}

format_capabilities() {
    local caps="$1"
    local result=""
    echo "$caps" | jq -r '.[]' 2>/dev/null | while read -r cap; do
        case "$cap" in
            chat)      echo -n "${GREEN}💬chat${RESET} " ;;
            vision)    echo -n "${MAGENTA}👁vision${RESET} " ;;
            code)      echo -n "${BLUE}⌨code${RESET} " ;;
            embedding) echo -n "${YELLOW}🔗embed${RESET} " ;;
            *)         echo -n "${DIM}${cap}${RESET} " ;;
        esac
    done
}

display_model_table() {
    local models_json="$1"
    local page="${2:-1}"
    local filter="${3:-all}"

    # Apply filter
    local filtered
    if [[ "$filter" == "all" ]]; then
        filtered="$models_json"
    else
        filtered=$(echo "$models_json" | jq --arg cap "$filter" \
            '[.[] | select(.capabilities != null and (.capabilities | map(. == $cap) | any))]')
    fi

    local total
    total=$(echo "$filtered" | jq 'length')
    local total_pages=$(( (total + MODELS_PER_PAGE - 1) / MODELS_PER_PAGE ))
    local offset=$(( (page - 1) * MODELS_PER_PAGE ))

    local page_models
    page_models=$(echo "$filtered" | jq --argjson off "$offset" --argjson lim "$MODELS_PER_PAGE" \
        '.[$off:$off+$lim]')

    echo ""
    echo -e "${CYAN}${TL}$(printf '%*s' 112 '' | tr ' ' "$H")${TR}${RESET}"
    printf "${CYAN}${V}${RESET}  ${BOLD}%-4s %-22s %-8s %-8s %-10s %-30s %-8s${RESET}  ${CYAN}${V}${RESET}\n" \
        "#" "Name" "Params" "Size" "Context" "Capabilities" "Pulls"
    echo -e "${CYAN}${ML}$(printf '%*s' 112 '' | tr ' ' "$H")${MR}${RESET}"

    local i=1
    while IFS= read -r model; do
        local idx=$(( offset + i ))
        local name params size caps pulls description
        name=$(echo "$model" | jq -r '.name // "unknown"')
        params=$(echo "$model" | jq -r '.parameter_size // "?"')
        size=$(echo "$model" | jq -r '.size // "?"')
        pulls=$(echo "$model" | jq -r '.pulls // 0')
        description=$(echo "$model" | jq -r '.description // ""' | cut -c1-45)

        local cap_icons=""
        local cap_arr
        cap_arr=$(echo "$model" | jq -r '.capabilities[]? // empty' 2>/dev/null)
        for cap in $cap_arr; do
            case "$cap" in
                chat)      cap_icons+="💬 " ;;
                vision)    cap_icons+="👁 " ;;
                code)      cap_icons+="⌨ " ;;
                embedding) cap_icons+="🔗 " ;;
                *)         cap_icons+="${cap} " ;;
            esac
        done
        cap_icons="${cap_icons:-  -  }"

        local pulls_fmt
        pulls_fmt=$(format_pulls "$pulls")

        # Alternate row coloring
        local row_color=""
        if (( i % 2 == 0 )); then row_color="${DIM}"; fi

        printf "${CYAN}${V}${RESET}${row_color}  %-4s ${BOLD}${CYAN}%-22s${RESET}${row_color} ${YELLOW}%-8s${RESET}${row_color} ${GREEN}%-8s${RESET}${row_color} %-10s %-20s ${WHITE}%6s${RESET}${row_color}   ${CYAN}${V}${RESET}\n" \
            "$idx" "$name" "$params" "$size" "" "$cap_icons" "$pulls_fmt"

        ((i++))
    done < <(echo "$page_models" | jq -c '.[]')

    echo -e "${CYAN}${BL}$(printf '%*s' 112 '' | tr ' ' "$H")${BR}${RESET}"
    echo -e "  ${DIM}Page ${WHITE}${page}${RESET}${DIM} of ${WHITE}${total_pages}${RESET}${DIM} | Total: ${WHITE}${total}${RESET}${DIM} models | Filter: ${WHITE}${filter}${RESET}"
    echo ""

    # Return total pages for navigation
    echo "$total_pages" > "$MANAGER_DIR/.total_pages"
    echo "$total" > "$MANAGER_DIR/.total_models"
}

# ─────────────────────────────────────────────────────────────────────────────
# DOWNLOAD SECTION
# ─────────────────────────────────────────────────────────────────────────────
download_model() {
    local model="$1"
    echo ""
    echo -e " ${BOLD}${CYAN}Downloading: ${WHITE}${model}${RESET}"
    draw_line 70 "─"
    echo ""

    if ollama pull "$model"; then
        echo ""
        print_success "Model '${model}' downloaded successfully!"
    else
        echo ""
        print_error "Failed to download '${model}'"
        return 1
    fi
}

show_quantization_menu() {
    local model_name="$1"
    echo ""
    draw_box "Select Quantization for: $model_name" 70
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Quantization options:${RESET}"
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}1${RESET}  ${WHITE}Default${RESET}       ${DIM}(Recommended - best balance)${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}2${RESET}  ${WHITE}:q4_0${RESET}         ${DIM}4-bit - smallest, fastest, lower quality${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}3${RESET}  ${WHITE}:q4_K_M${RESET}       ${DIM}4-bit medium - good balance${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}4${RESET}  ${WHITE}:q5_0${RESET}         ${DIM}5-bit - better quality${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}5${RESET}  ${WHITE}:q5_K_M${RESET}       ${DIM}5-bit medium - recommended quality${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}6${RESET}  ${WHITE}:q8_0${RESET}         ${DIM}8-bit - near full quality, larger${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}7${RESET}  ${WHITE}:f16${RESET}          ${DIM}Full float16 - highest quality, very large${RESET}"
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70
    echo ""
    printf "  Select quantization ${DIM}[1-7, default=1]${RESET}: "
    read -r q_choice

    case "${q_choice:-1}" in
        1) echo "" ;;
        2) echo ":q4_0" ;;
        3) echo ":q4_K_M" ;;
        4) echo ":q5_0" ;;
        5) echo ":q5_K_M" ;;
        6) echo ":q8_0" ;;
        7) echo ":f16" ;;
        *) echo "" ;;
    esac
}

download_setup_section() {
    show_header
    draw_box "Download & Setup Models" 70
    echo -e "${CYAN}${V}${RESET}"
    print_info "This section fetches the full Ollama model library and lets"
    print_info "you choose which models to download for offline use."
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70
    echo ""

    ensure_ollama_ready || { prompt_enter; return; }

    # Filter selection
    echo ""
    draw_box "Filter Models" 50
    echo -e "${CYAN}${V}${RESET}  ${GREEN}1${RESET}  All models"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}2${RESET}  Chat models only"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}3${RESET}  Vision models (multimodal)"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}4${RESET}  Code models"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}5${RESET}  Embedding models (for RAG)"
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 50
    printf "  Your choice ${DIM}[1-5]${RESET}: "
    read -r filter_choice

    local filter="all"
    case "${filter_choice:-1}" in
        2) filter="chat" ;;
        3) filter="vision" ;;
        4) filter="code" ;;
        5) filter="embedding" ;;
    esac

    # Fetch models
    local models_json
    models_json=$(fetch_available_models)

    local current_page=1
    local total_pages=1
    local selected_models=()

    while true; do
        show_header
        display_model_table "$models_json" "$current_page" "$filter"
        total_pages=$(cat "$MANAGER_DIR/.total_pages" 2>/dev/null || echo 1)

        echo -e "  ${BOLD}Commands:${RESET}"
        echo -e "  ${GREEN}n${RESET} = next page  ${GREEN}p${RESET} = prev page  ${GREEN}s${RESET} = search"
        echo -e "  ${GREEN}i <num>${RESET} = model info  ${GREEN}d <num>${RESET} = download now"
        echo -e "  ${GREEN}a <nums>${RESET} = add to queue (e.g. a 1 3 5)  ${GREEN}q${RESET} = download queue & exit"
        echo -e "  ${DIM}Queue: ${WHITE}${#selected_models[@]}${RESET}${DIM} selected${RESET}"
        echo ""
        printf "  Command: "
        read -r cmd args

        case "$cmd" in
            n|next)
                [[ $current_page -lt $total_pages ]] && ((current_page++)) || print_warn "Already on last page."
                ;;
            p|prev)
                [[ $current_page -gt 1 ]] && ((current_page--)) || print_warn "Already on first page."
                ;;
            s|search)
                printf "  Search term: "
                read -r search_term
                models_json=$(fetch_available_models | jq --arg q "$search_term" \
                    '[.[] | select((.name | ascii_downcase | contains($q | ascii_downcase)) or (.description | ascii_downcase | contains($q | ascii_downcase)))]')
                current_page=1
                ;;
            i|info)
                local model_num="${args:-0}"
                local offset=$(( (current_page - 1) * MODELS_PER_PAGE ))
                local model_idx=$(( model_num - 1 ))
                local model_name
                model_name=$(echo "$models_json" | jq -r --argjson idx "$model_idx" '.[$idx].name // empty')
                if [[ -n "$model_name" ]]; then
                    show_model_info_from_json "$models_json" "$model_idx"
                else
                    print_error "Invalid model number."
                fi
                prompt_enter
                ;;
            d|download)
                local model_num="${args:-0}"
                local model_idx=$(( model_num - 1 ))
                local model_name model_size
                model_name=$(echo "$models_json" | jq -r --argjson idx "$model_idx" '.[$idx].name // empty')
                model_size=$(echo "$models_json" | jq -r --argjson idx "$model_idx" '.[$idx].size // "?"')
                if [[ -n "$model_name" ]]; then
                    check_resource_warning "$model_size" || { prompt_enter; continue; }
                    local quant
                    quant=$(show_quantization_menu "$model_name")
                    download_model "${model_name}${quant}"
                else
                    print_error "Invalid model number."
                fi
                prompt_enter
                ;;
            a|add)
                for num in $args; do
                    local model_idx=$(( num - 1 ))
                    local model_name
                    model_name=$(echo "$models_json" | jq -r --argjson idx "$model_idx" '.[$idx].name // empty')
                    if [[ -n "$model_name" ]]; then
                        selected_models+=("$model_name")
                        print_success "Added '${model_name}' to download queue."
                    else
                        print_warn "Skipping invalid number: $num"
                    fi
                done
                sleep 1
                ;;
            q|queue|done)
                if [[ ${#selected_models[@]} -gt 0 ]]; then
                    echo ""
                    draw_box "Download Queue" 60
                    echo -e "${CYAN}${V}${RESET}"
                    for m in "${selected_models[@]}"; do
                        echo -e "${CYAN}${V}${RESET}  ${GREEN}•${RESET} $m"
                    done
                    echo -e "${CYAN}${V}${RESET}"
                    draw_box_bottom 60
                    echo ""
                    if confirm "Download all ${#selected_models[@]} models?"; then
                        local success=0
                        local failed=0
                        for m in "${selected_models[@]}"; do
                            local model_size
                            model_size=$(echo "$models_json" | jq -r --arg n "$m" '.[] | select(.name == $n) | .size // "?"')
                            echo ""
                            print_step "Downloading model $((success+failed+1)) of ${#selected_models[@]}: ${BOLD}${m}${RESET}"
                            check_resource_warning "$model_size" || continue
                            local quant
                            quant=$(show_quantization_menu "$m")
                            if download_model "${m}${quant}"; then
                                ((success++))
                            else
                                ((failed++))
                                if ! confirm "Download failed for '${m}'. Continue with remaining?"; then
                                    break
                                fi
                            fi
                        done
                        echo ""
                        draw_box "Download Complete" 60
                        echo -e "${CYAN}${V}${RESET}  ${GREEN}✔ Success: ${success}${RESET}"
                        [[ $failed -gt 0 ]] && echo -e "${CYAN}${V}${RESET}  ${RED}✘ Failed:  ${failed}${RESET}"
                        draw_box_bottom 60
                    fi
                    prompt_enter
                else
                    print_warn "No models in queue. Use 'a <num>' to add models."
                    sleep 1
                fi
                break
                ;;
            b|back|exit)
                break
                ;;
            *)
                print_warn "Unknown command. Use n, p, s, i <#>, d <#>, a <#>, q, b"
                sleep 1
                ;;
        esac
    done
}

show_model_info_from_json() {
    local models_json="$1"
    local idx="$2"

    local model_data
    model_data=$(echo "$models_json" | jq --argjson idx "$idx" '.[$idx]')
    local name description params size caps pulls

    name=$(echo "$model_data" | jq -r '.name')
    description=$(echo "$model_data" | jq -r '.description // "No description"')
    params=$(echo "$model_data" | jq -r '.parameter_size // "?"')
    size=$(echo "$model_data" | jq -r '.size // "?"')
    pulls=$(echo "$model_data" | jq -r '.pulls // 0')

    echo ""
    draw_box "Model Info: $name" 70
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Name:${RESET}          $name"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Description:${RESET}   $description"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Parameters:${RESET}    ${YELLOW}$params${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Size:${RESET}          ${GREEN}$size${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Total Pulls:${RESET}   $(format_pulls $pulls)"

    local caps_list
    caps_list=$(echo "$model_data" | jq -r '.capabilities[]? // empty' | tr '\n' ' ')
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Capabilities:${RESET}  $caps_list"

    # If installed locally, show extra details
    if ollama show "$name" &>/dev/null 2>&1; then
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}✔ INSTALLED LOCALLY${RESET}"
        local ctx
        ctx=$(curl -s -X POST "$OLLAMA_API/api/show" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$name\"}" 2>/dev/null | \
            jq -r '.model_info | to_entries | .[] | select(.key | contains("context")) | "\(.key): \(.value)"' \
            2>/dev/null | head -3)
        [[ -n "$ctx" ]] && echo -e "${CYAN}${V}${RESET}  ${BOLD}Context:${RESET}       $ctx"
    fi

    draw_box_bottom 70
}

# ─────────────────────────────────────────────────────────────────────────────
# RUN MODELS SECTION
# ─────────────────────────────────────────────────────────────────────────────
list_local_models() {
    curl -s "$OLLAMA_API/api/tags" 2>/dev/null | jq '.models // []'
}

show_local_models_table() {
    local models_json="$1"
    local count
    count=$(echo "$models_json" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        echo ""
        print_warn "No models installed yet. Go to 'Download & Setup' first."
        return 1
    fi

    echo ""
    echo -e "${CYAN}${TL}$(printf '%*s' 90 '' | tr ' ' "$H")${TR}${RESET}"
    printf "${CYAN}${V}${RESET}  ${BOLD}%-4s %-35s %-10s %-10s %-15s${RESET}  ${CYAN}${V}${RESET}\n" \
        "#" "Model Name" "Params" "Size" "Quantization"
    echo -e "${CYAN}${ML}$(printf '%*s' 90 '' | tr ' ' "$H")${MR}${RESET}"

    local i=1
    while IFS= read -r model; do
        local name params size quant
        name=$(echo "$model" | jq -r '.name // "unknown"')
        params=$(echo "$model" | jq -r '.details.parameter_size // "?"')
        quant=$(echo "$model" | jq -r '.details.quantization_level // "?"')
        local size_bytes
        size_bytes=$(echo "$model" | jq -r '.size // 0')
        size=$(numfmt --to=iec-i --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B")

        local row_color=""
        (( i % 2 == 0 )) && row_color="${DIM}"

        printf "${CYAN}${V}${RESET}${row_color}  %-4s ${BOLD}${CYAN}%-35s${RESET}${row_color} ${YELLOW}%-10s${RESET}${row_color} ${GREEN}%-10s${RESET}${row_color} %-15s${RESET}  ${CYAN}${V}${RESET}\n" \
            "$i" "$name" "$params" "$size" "$quant"
        ((i++))
    done < <(echo "$models_json" | jq -c '.[]')

    echo -e "${CYAN}${BL}$(printf '%*s' 90 '' | tr ' ' "$H")${BR}${RESET}"
    echo -e "  ${DIM}Total installed: ${WHITE}${count}${RESET}${DIM} models${RESET}"
}

get_system_prompts() {
    cat << 'EOF'
[
  {"name": "None (default)", "prompt": ""},
  {"name": "Persian Translator", "prompt": "You are a professional Persian (Farsi) translator. Translate all user input to Persian accurately and naturally. Preserve tone and nuance."},
  {"name": "English Translator", "prompt": "You are a professional English translator. Translate all user input to natural, fluent English."},
  {"name": "Code Reviewer", "prompt": "You are an expert code reviewer. Analyze code for bugs, security issues, performance, and style. Be specific and actionable."},
  {"name": "DevOps Assistant", "prompt": "You are a senior DevOps engineer specializing in Linux, Docker, Kubernetes, CI/CD, and cloud infrastructure. Provide practical, battle-tested solutions."},
  {"name": "Bash Script Expert", "prompt": "You are an expert bash scripter. Write clean, efficient, well-commented bash scripts. Always handle errors properly and follow best practices."},
  {"name": "Security Analyst", "prompt": "You are a cybersecurity expert. Analyze security concerns, explain vulnerabilities, and provide defensive solutions."},
  {"name": "Data Scientist", "prompt": "You are a data scientist expert in Python, pandas, numpy, scikit-learn, and visualization. Provide clear, reproducible code examples."},
  {"name": "Technical Writer", "prompt": "You are a technical writer. Create clear, concise, and comprehensive documentation, READMEs, and technical guides."},
  {"name": "Custom (type your own)", "prompt": "__custom__"}
]
EOF
}

configure_run_options() {
    local model_name="$1"
    echo ""
    draw_box "Configure Run Options: $model_name" 70
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  Leave blank to use defaults"
    echo -e "${CYAN}${V}${RESET}"

    # Temperature
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Temperature${RESET} ${DIM}[0.0-2.0, default: 0.7]${RESET}"
    printf "${CYAN}${V}${RESET}  → Temperature: "
    read -r temp_input
    local temperature="${temp_input:-0.7}"

    # Context size
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}Context Size${RESET} ${DIM}[tokens, default: model max]${RESET}"
    printf "${CYAN}${V}${RESET}  → Context (e.g. 4096, 8192, 32768): "
    read -r ctx_input
    local context="${ctx_input:-}"

    # System prompt
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}System Prompt Presets:${RESET}"
    local prompts_json
    prompts_json=$(get_system_prompts)
    local i=1
    while IFS= read -r p; do
        local pname
        pname=$(echo "$p" | jq -r '.name')
        echo -e "${CYAN}${V}${RESET}  ${GREEN}${i}${RESET}  $pname"
        ((i++))
    done < <(echo "$prompts_json" | jq -c '.[]')

    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70
    printf "  Select system prompt [1-${i}, default: 1]: "
    read -r prompt_choice
    prompt_choice="${prompt_choice:-1}"
    local prompt_idx=$(( prompt_choice - 1 ))

    local system_prompt
    system_prompt=$(echo "$prompts_json" | jq -r --argjson idx "$prompt_idx" '.[$idx].prompt // ""')

    if [[ "$system_prompt" == "__custom__" ]]; then
        echo ""
        echo "  Enter your custom system prompt (Ctrl+D when done):"
        system_prompt=$(cat)
    fi

    # Output config
    echo "$temperature|$context|$system_prompt"
}

run_model_section() {
    show_header
    draw_box "Run Downloaded Models (Offline)" 70
    echo -e "${CYAN}${V}${RESET}"
    print_info "All models run 100% locally — no internet required."
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70

    ensure_ollama_ready || { prompt_enter; return; }

    local local_models
    local_models=$(list_local_models)

    if ! show_local_models_table "$local_models"; then
        prompt_enter
        return
    fi

    echo ""
    printf "  Select model number (or 0 to cancel): "
    read -r model_choice

    [[ "$model_choice" == "0" || -z "$model_choice" ]] && return

    local model_idx=$(( model_choice - 1 ))
    local selected_name
    selected_name=$(echo "$local_models" | jq -r --argjson idx "$model_idx" '.[$idx].name // empty')

    if [[ -z "$selected_name" ]]; then
        print_error "Invalid selection."
        prompt_enter
        return
    fi

    # Run mode selection
    echo ""
    draw_box "Run Mode: $selected_name" 60
    echo -e "${CYAN}${V}${RESET}  ${GREEN}1${RESET}  Interactive Chat (terminal)"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}2${RESET}  Interactive Chat (with options)"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}3${RESET}  Start API Server only"
    echo -e "${CYAN}${V}${RESET}  ${GREEN}4${RESET}  View model details"
    draw_box_bottom 60
    printf "  Choice [1-4, default: 1]: "
    read -r run_mode
    run_mode="${run_mode:-1}"

    case "$run_mode" in
        1)
            echo ""
            print_step "Starting ${BOLD}${selected_name}${RESET} in interactive chat..."
            print_info "Type ${BOLD}/bye${RESET} to exit the chat."
            echo ""
            sleep 1
            if [[ "${SAVE_CHAT_HISTORY:-true}" == "true" ]]; then
                local chat_file="$CHATS_DIR/$(date +%Y-%m-%d_%H-%M-%S)_${selected_name//\//_}.txt"
                print_info "Chat will be saved to: $chat_file"
                echo "=== Chat Session: $selected_name | $(date) ===" > "$chat_file"
                script -q -a "$chat_file" -c "ollama run $selected_name" /dev/null
            else
                ollama run "$selected_name"
            fi
            ;;
        2)
            local opts
            opts=$(configure_run_options "$selected_name")
            local temperature context system_prompt
            IFS='|' read -r temperature context system_prompt <<< "$opts"

            # Create temporary Modelfile
            local tmp_modelfile
            tmp_modelfile=$(mktemp /tmp/Modelfile.XXXXXX)
            {
                echo "FROM $selected_name"
                [[ -n "$system_prompt" ]] && printf 'SYSTEM """%s"""\n' "$system_prompt"
                echo "PARAMETER temperature $temperature"
                [[ -n "$context" ]] && echo "PARAMETER num_ctx $context"
            } > "$tmp_modelfile"

            local custom_model_name="ollama_manager_custom_$(date +%s)"
            print_step "Creating custom model configuration..."
            ollama create "$custom_model_name" -f "$tmp_modelfile" 2>/dev/null || {
                print_warn "Could not create custom config, running with defaults."
                custom_model_name="$selected_name"
            }
            rm -f "$tmp_modelfile"

            echo ""
            print_step "Starting chat with custom configuration..."
            print_info "Temperature: ${temperature} | Context: ${context:-default}"
            [[ -n "$system_prompt" ]] && print_info "System prompt: active"
            echo ""

            if [[ "${SAVE_CHAT_HISTORY:-true}" == "true" ]]; then
                local chat_file="$CHATS_DIR/$(date +%Y-%m-%d_%H-%M-%S)_${selected_name//\//_}.txt"
                echo "=== Session: $selected_name | temp=$temperature | $(date) ===" > "$chat_file"
                script -q -a "$chat_file" -c "ollama run $custom_model_name" /dev/null
            else
                ollama run "$custom_model_name"
            fi

            # Cleanup custom model
            [[ "$custom_model_name" != "$selected_name" ]] && ollama rm "$custom_model_name" 2>/dev/null || true
            ;;
        3)
            echo ""
            print_step "Loading model into API server..."
            curl -s -X POST "$OLLAMA_API/api/generate" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$selected_name\",\"prompt\":\"\",\"stream\":false}" &>/dev/null &
            sleep 2
            echo ""
            print_success "Model is ready via API!"
            echo ""
            echo -e "  ${BOLD}API Endpoints:${RESET}"
            echo -e "  ${CYAN}Generate:${RESET} POST ${WHITE}http://localhost:11434/api/generate${RESET}"
            echo -e "  ${CYAN}Chat:${RESET}     POST ${WHITE}http://localhost:11434/api/chat${RESET}"
            echo ""
            echo -e "  ${BOLD}Example:${RESET}"
            echo -e '  curl http://localhost:11434/api/chat -d '"'"'{"model":"'"$selected_name"'","messages":[{"role":"user","content":"Hello!"}]}'"'"
            echo ""
            print_info "Use 'Model Management > Stop Running Models' to unload."
            prompt_enter
            ;;
        4)
            echo ""
            print_step "Fetching details for: $selected_name"
            local detail_json
            detail_json=$(curl -s -X POST "$OLLAMA_API/api/show" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"$selected_name\"}" 2>/dev/null)
            echo ""
            draw_box "Model Details: $selected_name" 70
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Format:${RESET}        $(echo "$detail_json" | jq -r '.details.format // "?"')"
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Family:${RESET}        $(echo "$detail_json" | jq -r '.details.family // "?"')"
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Parameters:${RESET}    $(echo "$detail_json" | jq -r '.details.parameter_size // "?"')"
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Quantization:${RESET}  $(echo "$detail_json" | jq -r '.details.quantization_level // "?"')"
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Capabilities:${RESET}  $(echo "$detail_json" | jq -r '.capabilities // [] | join(", ")')"
            echo -e "${CYAN}${V}${RESET}"

            # Context length
            local ctx_len
            ctx_len=$(echo "$detail_json" | jq -r '.model_info | to_entries | .[] | select(.key | contains("context")) | "\(.key): \(.value)"' 2>/dev/null | head -1)
            [[ -n "$ctx_len" ]] && echo -e "${CYAN}${V}${RESET}  ${BOLD}Context Length:${RESET} $ctx_len"

            echo -e "${CYAN}${V}${RESET}"
            local params_str
            params_str=$(echo "$detail_json" | jq -r '.parameters // "none"' | head -20)
            echo -e "${CYAN}${V}${RESET}  ${BOLD}Parameters:${RESET}"
            echo "$params_str" | while read -r line; do
                echo -e "${CYAN}${V}${RESET}    $line"
            done
            echo -e "${CYAN}${V}${RESET}"
            local license_str
            license_str=$(echo "$detail_json" | jq -r '.license // "unknown"' | head -3)
            echo -e "${CYAN}${V}${RESET}  ${BOLD}License:${RESET}       $license_str"
            draw_box_bottom 70
            prompt_enter
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# MODEL MANAGEMENT SECTION
# ─────────────────────────────────────────────────────────────────────────────
model_management_section() {
    while true; do
        show_header
        draw_box "Model Management" 60
        echo -e "${CYAN}${V}${RESET}  ${GREEN}1${RESET}  View installed models"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}2${RESET}  Delete a model"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}3${RESET}  Update all models (re-pull)"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}4${RESET}  Copy / rename a model"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}5${RESET}  View running models (VRAM)"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}6${RESET}  Stop a running model"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}7${RESET}  Create custom Modelfile"
        echo -e "${CYAN}${V}${RESET}  ${GREEN}0${RESET}  Back to main menu"
        echo -e "${CYAN}${V}${RESET}"
        draw_box_bottom 60
        printf "  Choice: "
        read -r choice

        case "$choice" in
            1)
                show_header
                local local_models
                local_models=$(list_local_models)
                show_local_models_table "$local_models"
                prompt_enter
                ;;
            2)
                show_header
                local local_models
                local_models=$(list_local_models)
                show_local_models_table "$local_models"
                echo ""
                printf "  Enter model number to delete (0 to cancel): "
                read -r del_choice
                [[ "$del_choice" == "0" || -z "$del_choice" ]] && continue

                local del_idx=$(( del_choice - 1 ))
                local del_name
                del_name=$(echo "$local_models" | jq -r --argjson idx "$del_idx" '.[$idx].name // empty')
                if [[ -n "$del_name" ]]; then
                    if confirm "${RED}Delete '${del_name}'?${RESET} This cannot be undone."; then
                        ollama rm "$del_name" && print_success "Deleted: $del_name" || print_error "Failed to delete."
                    else
                        print_info "Cancelled."
                    fi
                else
                    print_error "Invalid selection."
                fi
                prompt_enter
                ;;
            3)
                show_header
                ensure_ollama_ready || { prompt_enter; continue; }
                local local_models model_names
                local_models=$(list_local_models)
                model_names=$(echo "$local_models" | jq -r '.[].name')
                local count
                count=$(echo "$local_models" | jq 'length')
                echo ""
                print_info "Will update $count model(s):"
                echo "$model_names" | while read -r m; do print_step "$m"; done
                echo ""
                if confirm "Update all models?"; then
                    while read -r m; do
                        print_step "Updating: $m"
                        ollama pull "$m" && print_success "Updated: $m" || print_warn "Failed: $m"
                    done <<< "$model_names"
                fi
                prompt_enter
                ;;
            4)
                show_header
                local local_models
                local_models=$(list_local_models)
                show_local_models_table "$local_models"
                echo ""
                printf "  Source model number: "
                read -r src_num
                local src_idx=$(( src_num - 1 ))
                local src_name
                src_name=$(echo "$local_models" | jq -r --argjson idx "$src_idx" '.[$idx].name // empty')
                [[ -z "$src_name" ]] && { print_error "Invalid."; prompt_enter; continue; }
                printf "  New name for copy: "
                read -r dest_name
                [[ -z "$dest_name" ]] && { print_error "Name cannot be empty."; prompt_enter; continue; }
                ollama cp "$src_name" "$dest_name" && print_success "Copied '$src_name' → '$dest_name'" || print_error "Copy failed."
                prompt_enter
                ;;
            5)
                show_header
                print_step "Models currently in VRAM/memory:"
                echo ""
                local ps_result
                ps_result=$(curl -s "$OLLAMA_API/api/ps" 2>/dev/null)
                local running_count
                running_count=$(echo "$ps_result" | jq '.models | length' 2>/dev/null || echo 0)
                if [[ "$running_count" -eq 0 ]]; then
                    print_info "No models currently loaded in memory."
                else
                    echo -e "${CYAN}${TL}$(printf '%*s' 70 '' | tr ' ' "$H")${TR}${RESET}"
                    printf "${CYAN}${V}${RESET}  ${BOLD}%-35s %-10s %-15s${RESET}  ${CYAN}${V}${RESET}\n" "Model" "Size" "Until"
                    echo -e "${CYAN}${ML}$(printf '%*s' 70 '' | tr ' ' "$H")${MR}${RESET}"
                    echo "$ps_result" | jq -c '.models[]' | while read -r m; do
                        local mname msize mexpires
                        mname=$(echo "$m" | jq -r '.name')
                        msize=$(echo "$m" | jq -r '.size' | numfmt --to=iec-i 2>/dev/null || echo "?")
                        mexpires=$(echo "$m" | jq -r '.expires_at // "?"')
                        printf "${CYAN}${V}${RESET}  ${CYAN}%-35s${RESET} ${GREEN}%-10s${RESET} %-15s  ${CYAN}${V}${RESET}\n" \
                            "$mname" "$msize" "${mexpires:0:16}"
                    done
                    echo -e "${CYAN}${BL}$(printf '%*s' 70 '' | tr ' ' "$H")${BR}${RESET}"
                fi
                prompt_enter
                ;;
            6)
                show_header
                local ps_result
                ps_result=$(curl -s "$OLLAMA_API/api/ps" 2>/dev/null)
                local running
                running=$(echo "$ps_result" | jq -r '.models[].name' 2>/dev/null)
                if [[ -z "$running" ]]; then
                    print_info "No models currently running."
                    prompt_enter
                    continue
                fi
                echo "Running models:"
                echo "$running"
                echo ""
                printf "  Model name to stop: "
                read -r stop_name
                [[ -z "$stop_name" ]] && continue
                ollama stop "$stop_name" && print_success "Stopped: $stop_name" || print_error "Failed to stop."
                prompt_enter
                ;;
            7)
                show_header
                modelfile_generator
                prompt_enter
                ;;
            0|b|back)
                break
                ;;
        esac
    done
}

modelfile_generator() {
    draw_box "Custom Modelfile Generator" 70
    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  Create a custom model with your settings"
    echo -e "${CYAN}${V}${RESET}"
    draw_box_bottom 70

    # Select base model
    local local_models
    local_models=$(list_local_models)
    show_local_models_table "$local_models"
    echo ""
    printf "  Select base model number: "
    read -r base_num
    local base_idx=$(( base_num - 1 ))
    local base_model
    base_model=$(echo "$local_models" | jq -r --argjson idx "$base_idx" '.[$idx].name // empty')
    [[ -z "$base_model" ]] && { print_error "Invalid selection."; return; }

    printf "  New model name (e.g. my-assistant): "
    read -r new_model_name
    [[ -z "$new_model_name" ]] && { print_error "Name required."; return; }

    printf "  System prompt (Enter to skip): "
    read -r sys_prompt

    printf "  Temperature [0.0-2.0, default 0.7]: "
    read -r temp
    temp="${temp:-0.7}"

    printf "  Context size [e.g. 4096, default: skip]: "
    read -r ctx_size

    printf "  Top-p [0.0-1.0, default: skip]: "
    read -r top_p

    local modelfile_content="FROM $base_model\n"
    [[ -n "$sys_prompt" ]] && modelfile_content+="SYSTEM \"$sys_prompt\"\n"
    modelfile_content+="PARAMETER temperature $temp\n"
    [[ -n "$ctx_size" ]] && modelfile_content+="PARAMETER num_ctx $ctx_size\n"
    [[ -n "$top_p" ]] && modelfile_content+="PARAMETER top_p $top_p\n"

    echo ""
    print_info "Generated Modelfile:"
    echo ""
    echo -e "${DIM}${modelfile_content}${RESET}"
    echo ""

    if confirm "Create model '$new_model_name' with this Modelfile?"; then
        local tmp_mf
        tmp_mf=$(mktemp /tmp/Modelfile.XXXXXX)
        printf "%b" "$modelfile_content" > "$tmp_mf"
        ollama create "$new_model_name" -f "$tmp_mf" && \
            print_success "Created model: $new_model_name" || \
            print_error "Failed to create model."
        rm -f "$tmp_mf"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM INFO SECTION
# ─────────────────────────────────────────────────────────────────────────────
system_info_section() {
    show_header
    draw_box "System Info & Status" 70

    echo -e "${CYAN}${V}${RESET}"
    echo -e "${CYAN}${V}${RESET}  ${BOLD}${CYAN}── Ollama Status ──${RESET}"
    echo -e "${CYAN}${V}${RESET}"

    if check_ollama_installed; then
        local ollama_ver
        ollama_ver=$(ollama --version 2>/dev/null || echo "unknown")
        print_success "Ollama installed: $ollama_ver"
    else
        print_error "Ollama: NOT installed"
    fi

    if check_ollama_running; then
        print_success "Ollama service: RUNNING on port 11434"
    else
        print_warn "Ollama service: NOT running"
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}── Hardware ──${RESET}"
    echo ""
    local total_ram
    total_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
    local free_ram
    free_ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $7}' || echo "?")
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "?")
    local cpu_model
    cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "unknown")
    local disk_free
    disk_free=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}' || echo "?")
    local disk_total
    disk_total=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $2}' || echo "?")

    print_info "CPU: $cpu_model ($cpu_cores cores)"
    print_info "RAM: ${free_ram} available / ${total_ram} total"
    print_info "Disk: ${disk_free} free / ${disk_total} total"
    print_info "GPU: $(detect_gpu)"

    echo ""
    echo -e "  ${BOLD}${CYAN}── Ollama Models Storage ──${RESET}"
    echo ""
    if check_ollama_installed; then
        local model_count
        model_count=$(ollama list 2>/dev/null | tail -n +2 | wc -l)
        local models_dir="${HOME}/.ollama/models"
        local models_size="?"
        [[ -d "$models_dir" ]] && models_size=$(du -sh "$models_dir" 2>/dev/null | cut -f1)
        print_info "Installed models: $model_count"
        print_info "Models directory: ${models_dir} (${models_size})"
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}── Ollama Update Check ──${RESET}"
    echo ""
    spinner_start "Checking for Ollama updates..."
    local latest_version
    latest_version=$(curl -s --max-time 8 \
        "https://api.github.com/repos/ollama/ollama/releases/latest" 2>/dev/null | \
        jq -r '.tag_name // "unknown"')
    spinner_stop

    local current_version
    current_version=$(ollama --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")

    print_info "Current version: ${current_version}"
    print_info "Latest version:  ${latest_version}"

    if [[ "$latest_version" != "unknown" && "$current_version" != "unknown" ]]; then
        if [[ "$latest_version" == "v${current_version}" || "$latest_version" == "${current_version}" ]]; then
            print_success "Ollama is up to date!"
        else
            print_warn "Update available: ${latest_version}"
            print_info "Run: curl -fsSL https://ollama.com/install.sh | sh"
        fi
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}── Manager Info ──${RESET}"
    echo ""
    print_info "Script version: $SCRIPT_VERSION"
    print_info "Config dir: $MANAGER_DIR"
    local chat_count=0
    [[ -d "$CHATS_DIR" ]] && chat_count=$(ls "$CHATS_DIR" 2>/dev/null | wc -l)
    print_info "Saved chat sessions: $chat_count"

    echo ""
    draw_box_bottom 70

    echo ""
    echo -e "  ${GREEN}1${RESET}  View Ollama logs"
    echo -e "  ${GREEN}2${RESET}  View saved chat history"
    echo -e "  ${GREEN}0${RESET}  Back"
    printf "  Choice: "
    read -r sub_choice

    case "$sub_choice" in
        1)
            echo ""
            print_step "Recent Ollama logs:"
            echo ""
            if [[ -f "$MANAGER_DIR/ollama.log" ]]; then
                tail -50 "$MANAGER_DIR/ollama.log"
            else
                journalctl -u ollama --no-pager -n 50 2>/dev/null || \
                    print_info "No logs found. Log path: $MANAGER_DIR/ollama.log"
            fi
            prompt_enter
            ;;
        2)
            echo ""
            if [[ $chat_count -eq 0 ]]; then
                print_info "No saved chat sessions yet."
            else
                print_step "Saved sessions in $CHATS_DIR:"
                echo ""
                ls -lt "$CHATS_DIR" 2>/dev/null | head -20
                echo ""
                printf "  Enter filename to view (or Enter to skip): "
                read -r chat_filename
                if [[ -n "$chat_filename" && -f "$CHATS_DIR/$chat_filename" ]]; then
                    less "$CHATS_DIR/$chat_filename"
                fi
            fi
            prompt_enter
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ─────────────────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        show_header

        # Status line
        local ollama_status="${RED}✘ Not installed${RESET}"
        local service_status="${RED}✘ Offline${RESET}"
        local model_count="0"

        if check_ollama_installed; then
            ollama_status="${GREEN}✔ $(ollama --version 2>/dev/null | head -1)${RESET}"
            model_count=$(ollama list 2>/dev/null | tail -n +2 | wc -l || echo 0)
        fi
        if check_ollama_running; then
            service_status="${GREEN}✔ Running :11434${RESET}"
        fi

        echo -e "  ${DIM}Ollama: ${ollama_status}  |  Service: ${service_status}  |  Models: ${WHITE}${model_count}${RESET}${DIM} installed${RESET}"
        echo ""

        draw_box "MAIN MENU" 60
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${BG_CYAN}${WHITE}  1  ${RESET}  ${BOLD}Download & Setup Models${RESET}"
        echo -e "${CYAN}${V}${RESET}       ${DIM}Browse & download from the full Ollama library${RESET}"
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${BG_CYAN}${WHITE}  2  ${RESET}  ${BOLD}Run Downloaded Models (Offline)${RESET}"
        echo -e "${CYAN}${V}${RESET}       ${DIM}Chat with your installed models — no internet needed${RESET}"
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${BG_CYAN}${WHITE}  3  ${RESET}  ${BOLD}Model Management${RESET}"
        echo -e "${CYAN}${V}${RESET}       ${DIM}View, delete, copy, update models${RESET}"
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${BG_CYAN}${WHITE}  4  ${RESET}  ${BOLD}System Info & Status${RESET}"
        echo -e "${CYAN}${V}${RESET}       ${DIM}Hardware info, GPU, Ollama logs, update check${RESET}"
        echo -e "${CYAN}${V}${RESET}"
        echo -e "${CYAN}${V}${RESET}  ${BG_CYAN}${WHITE}  5  ${RESET}  ${BOLD}Exit${RESET}"
        echo -e "${CYAN}${V}${RESET}"
        draw_box_bottom 60
        echo ""
        printf "  ${BOLD}Your choice [1-5]${RESET}: "
        read -r main_choice

        case "$main_choice" in
            1) download_setup_section ;;
            2) run_model_section ;;
            3) model_management_section ;;
            4) system_info_section ;;
            5|q|quit|exit)
                show_header
                echo -e "  ${CYAN}Thanks for using Ollama Manager!${RESET}"
                echo -e "  ${DIM}Subscribe: https://t.me/Web3loverz${RESET}"
                echo ""
                exit 0
                ;;
            *)
                print_warn "Invalid choice. Enter 1-5."
                sleep 1
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# TRAP & CLEANUP
# ─────────────────────────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
    echo ""
    echo -e "\n  ${DIM}Goodbye! | https://t.me/Web3loverz${RESET}"
    exit 0
}
trap cleanup INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────
main() {
    init_dirs
    show_header
    print_step "Checking dependencies..."
    check_dependencies
    sleep 0.5
    main_menu
}

main "$@"
