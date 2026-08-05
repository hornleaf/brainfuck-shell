#!/usr/bin/env bash

# Brainfuck 解释器 (Bash 函数版)
#
# 标准 8 指令, 与原版 (Urban Müller, 1993) 语义一致:
#   >   指针右移一格
#   <   指针左移一格
#   +   当前单元值 +1 (8-bit 回绕: 255 -> 0)
#   -   当前单元值 -1 (8-bit 回绕: 0 -> 255)
#   .   输出当前单元值对应的字节 (0-255)
#   ,   从 stdin 读取一个字节存入当前单元 (EOF 置 0, 终端输入静默不回显)
#   [   当前单元为 0 时, 跳到匹配的 ] 之后
#   ]   当前单元非 0 时, 跳回匹配的 [ 之后
#
# 图灵完备性:
#   - 磁带双向无界: 指针移出已分配区域时自动按 128 单元扩展 (grow)
#   - 8-bit 回绕单元值, 完整括号匹配, 字节级 I/O
#   - 可模拟任意图灵机 (等价于标准 Brainfuck)
#
# 用法:
#   brainfuck                   从 stdin 读取
#   brainfuck "源代码"           直接执行代码字符串
#   brainfuck 程序.bf            执行 .bf 文件（或任何文本文件）
#   brainfuck 参数1 参数2 ...    拼接所有参数作为代码
function brainfuck {
  # ----- 配置 -----
  local -a mem=()            # 磁带 (按需双向扩展)
  local base=0               # 基址偏移 (支持指针向 0 左侧扩展)
  local ptr=0                # 数据指针
  local code=""
  local pc=0
  local -a match
  local -a stack
  local -a chunk
  local i
  for ((i=0; i<128; i++)); do chunk[i]=0; done
  # ----- 读取源代码 -----
  if [[ $# -eq 0 ]]; then
    # 从 stdin 读取 (支持多行)
    while IFS= read -r line; do
      code+="$line"
    done
  elif [[ $# -eq 1 && -f "$1" && -r "$1" ]]; then
    # 单个参数且为可读文件 → 读取文件内容
    code=$(<"$1")
  else
    # 多个参数或非文件参数 → 拼接为代码字符串
    code="$*"
  fi
  # 过滤出有效指令
  local filtered=""
  for ((i=0; i<${#code}; i++)); do
    local char="${code:i:1}"
    case "$char" in
      '>'|'<'|'+'|'-'|'.'|','|'['|']') filtered+="$char" ;;
    esac
  done
  code="$filtered"
  if [[ -z "$code" ]]; then
    [[ "${LANG:-C}" == zh_* ]] && echo "错误: 未找到有效的 Brainfuck 指令" >&2 || echo "Error: No valid Brainfuck instruction found" >&2
    return 1
  fi
  # ----- 括号匹配 -----
  local len=${#code}
  for ((i=0; i<len; i++)); do
    local char="${code:i:1}"
    if [[ "$char" == "[" ]]; then
      stack+=("$i")
    elif [[ "$char" == "]" ]]; then
      if [[ ${#stack[@]} -eq 0 ]]; then
        [[ "${LANG:-C}" == zh_* ]] && echo "错误: 多余的 ']' 在位置 $i" >&2 || echo "Error: Extra ']' at position $i" >&2
        return 1
      fi
      local last="${stack[-1]}"
      unset 'stack[-1]'
      match[$last]=$i
      match[$i]=$last
    fi
  done
  if [[ ${#stack[@]} -ne 0 ]]; then
    [[ "${LANG:-C}" == zh_* ]] && echo "错误: 未匹配的 '[' 在位置 ${stack[-1]}" >&2 || echo "Error: unmatched '[' at position ${stack[-1]}" >&2
    return 1
  fi
  # ----- 磁带扩展: 确保当前指针位置已分配, 双向无界 -----
  grow() {
    local idx=$((ptr + base))
    while (( idx < 0 )); do
      mem=( "${chunk[@]}" "${mem[@]}" )    # 向左扩展 128 单元
      ((base += 128))                      # 注意: base+=128 是字符串拼接, 必须用算术赋值
      idx=$((ptr + base))
    done
    while (( idx >= ${#mem[@]} )); do
      mem+=( "${chunk[@]}" )               # 向右扩展 128 单元
    done
  }
  # ----- 执行 -----
  grow
  while [[ $pc -lt $len ]]; do
    local char="${code:pc:1}"
    case "$char" in
      '>') ((ptr++)); grow ;;
      '<') ((ptr--)); grow ;;
      '+') ((mem[ptr+base] = (mem[ptr+base] + 1) & 255)) ;;
      '-') ((mem[ptr+base] = (mem[ptr+base] - 1) & 255)) ;;
      '.')
        # 输出当前单元字节 (八进制转义, 无 \x 位数歧义)
        printf "\\$(printf %03o "$((mem[ptr+base] & 255))")"
        ;;
      ',')
        # 原版 ',' : 从 stdin 读取一个字节 (LC_ALL=C 保证按字节), EOF 置 0
        local byte val
        if LC_ALL=C IFS= read -r -N1 byte; then
          if [[ "$byte" == "'" ]]; then
            val=39                            # 0x27 单引号特判, 避免格式串破坏
          else
            LC_ALL=C printf -v val '%d' "'$byte"
          fi
          ((mem[ptr+base] = val & 255))
        else
          ((mem[ptr+base] = 0))
        fi
        ;;
      '[')
        (( mem[ptr+base] == 0 )) && pc=${match[$pc]}
        ;;
      ']')
        (( mem[ptr+base] != 0 )) && pc=${match[$pc]}
        ;;
    esac
    ((pc++))
  done
  unset -f grow
  return 0
}

# Brain Fuck 代码生成器
# 用法: brainfuck-generate "文字"
# 输出: 类型:BF代码
function brainfuck-generate {
    local input="$1"
    [[ -z "$input" ]] && { [[ "${LANG:-C}" == zh_* ]] && echo "错误: 未提供字符串" >&2 || echo "Error: No string provided" >&2; return 1; }
    # 直接通过管道获取字节，保留末尾换行
    local bytes=()
    while IFS= read -r -d '' byte; do
        bytes+=("$byte")
    done < <(printf "%b" "$input" | od -An -v -t u1 | tr -s ' ' '\n' | grep -v '^$' | tr '\n' '\0')
    # 如果字节数组为空，返回空
    [[ ${#bytes[@]} -eq 0 ]] && { echo ""; return; }
    # 辅助函数
    repeat() {
        local s="$1" count="$2" out=""
        for (( i=0; i<count; i++ )); do out+="$s"; done
        echo -n "$out"
    }
    median_sqrt() {
        local arr=("$@")
        [[ ${#arr[@]} -eq 0 ]] && { echo 1; return; }
        IFS=$'\n' sorted=($(sort -n <<<"${arr[*]}"))
        local len=${#sorted[@]}
        local mid1=$(( (len-1)/2 ))
        local mid2=$(( len/2 ))
        local avg=$(echo "scale=2; (${sorted[mid1]} + ${sorted[mid2]}) / 2" | bc)
        local sqrt=$(echo "sqrt($avg)" | bc -l)
        printf "%.0f" "$sqrt"
    }
    find_nearest() {
        local pos="$1" target="$2"; shift 2; local values=("$@")
        local best_idx=-1 best_dist=999999
        for (( i=0; i<${#values[@]}; i++ )); do
            local val_diff=$(( values[i] - target ))
            (( val_diff < 0 )) && val_diff=$(( -val_diff ))
            local pos_diff=$(( i - pos ))
            (( pos_diff < 0 )) && pos_diff=$(( -pos_diff ))
            local dist=$(( val_diff + pos_diff ))
            if (( dist < best_dist )); then
                best_dist=$dist; best_idx=$i
            fi
        done
        echo "$best_idx $best_dist"
    }
    emit_move() {
        local sym="$1" e="$2" a="$3"
        if (( e > a )); then
            repeat "${sym:0:1}" $(( e - a ))
        elif (( a > e )); then
            repeat "${sym:1:1}" $(( a - e ))
        fi
    }
    # ---------- 构建模板 ----------
    local positions=() values=()
    local current_pos=0
    for byte in "${bytes[@]}"; do
        read idx dist <<< $(find_nearest "$current_pos" "$byte" "${values[@]}")
        local sqrt_c=$(echo "sqrt($byte)" | bc -l)
        local ceil_sqrt=$(printf "%.0f" "$sqrt_c")  # 向上取整
        local threshold=$(( byte < (ceil_sqrt + 1) ? byte : (ceil_sqrt + 1) ))
        if (( dist >= threshold )); then
            positions+=("$byte")
            values+=("$byte")
            current_pos=$(( ${#positions[@]} - 1 ))
        else
            current_pos=$idx
            values[$idx]=$byte
        fi
    done
    # ---------- 计算基准 d 和分组 f ----------
    local d=$(median_sqrt "${positions[@]}")
    [[ $d -eq 0 ]] && d=1

    local f=()
    for val in "${positions[@]}"; do
        local rounded=$(echo "scale=0; ($val / $d) + 0.5" | bc | cut -d. -f1)
        f+=("$rounded")
    done
    # 重置 values 为初始化后的实际值
    local new_values=()
    for (( i=0; i<${#f[@]}; i++ )); do
        new_values+=( $(( f[i] * d )) )
    done
    values=("${new_values[@]}")
    # ---------- 生成前缀 ----------
    local init_code=""
    init_code+=$(repeat "+" "$d")
    init_code+="["
    for (( i=0; i<${#f[@]}; i++ )); do
        init_code+=">"
        init_code+=$(repeat "+" "${f[i]}")
    done
    init_code+=$(repeat "<" "${#f[@]}")
    init_code+="-"
    init_code+="]>"
    # ---------- 生成主体 ----------
    local body_code=""
    current_pos=0
    for (( i=0; i<${#bytes[@]}; i++ )); do
        local target=${bytes[i]}
        read idx dist <<< $(find_nearest "$current_pos" "$target" "${values[@]}")
        body_code+=$(emit_move "<>" "$current_pos" "$idx")
        body_code+=$(emit_move "-+" "${values[$idx]}" "$target")
        body_code+="."
        current_pos=$idx
        values[$idx]=$target
    done
    unset -f repeat median_sqrt find_nearest emit_move
    echo "${init_code}${body_code}"
}

# ----- 如果脚本被直接执行（不是 source），则调用函数 -----
if [[ "$BASH_SOURCE" == "$0" ]]; then

  declare -a HELP_ZH=(
    "用法: [source|.] $(basename $BASH_SOURCE) [-bhiv|BFCode|String|File]"
    "Brain Fuck 解释器 & 生成器"
    ""
    "选项:"
    "     --help, -h       显示此帮助"
    "     --version, -v    显示版本信息"
    "     --build, -b      生成BF代码"
    "     --interact, -i   以交互模式启动"
    ""
  )

  declare -a HELP_EN=(
     "Usage: [source|.] $(basename $BASH_SOURCE) [-bhiv|BFCode|String|File]"
      "Brain Fuck interpreter & generator"
      ""
      "Options:"
      " --help, -h         Display this help"
      " --version, -v      Display version information"
      " --build, -b        Generate BF code"
      " --interact, -i     Start in interactive mode"
      ""
  )

  declare -a HELP_INFORMATION_EN=(
    "┌───────────────────────── BRAIN FUCK REPL HELP ───────────────────────────┐"
    "│ !   The result after execution will be executed as a Shell command again │"
    "│ #   Generate Brain Fuck code                                             │"
    "│ :   Clear the screen                                                     │"
    "│ ?   Display this help information                                        │"
    "│ ;   Exit this REPL                                                       │"
    "├────────────────────── BRIAN FUCK INSTRUCTION HELP ───────────────────────┤"
    "│ +   Add 1 to the current cell. If the cell is at 255, it wraps back to   │"
    "│     0.                                                                   │"
    "│ -   Subtract 1 from the current cell. If the cell is at 0, it wraps to   │"
    "│     255.                                                                 │"
    "│ >   Move the pointer one cell to the right.                              │"
    "│ <   Move the pointer one cell to the left.                               │"
    "│ .   Print the current cell's value as an ASCII character. For example,   │"
    "│     72 prints H, 101 prints e.                                           │"
    "│ .   Read one byte of input and store its value in the current cell.      │"
    "│ [   If the current cell is 0, skip ahead to the instruction after the    │"
    "│     matching ]. Otherwise, continue into the loop.                       │"
    "│ ]   If the current cell is not 0, jump back to the matching [. Otherwi-  │"
    "│     -se, continue past the loop.                                         │"
    "└──────────────────────────────────────────────────────────────────────────┘"
  )

  declare -a HELP_INFORMATION_ZH=(
    "┌─────────────────────── BRAIN FUCK 交互帮助 ───────────────────────┐"
    "│ !   将其 BF 代码执行后的结果作为 Shell 命令再次执行               │"
    "│ #   为输入的字符串生成 BF 代码                                    │"
    "│ :   清除屏幕                                                      │"
    "│ ?   显示此帮助                                                    │"
    "│ ;   退出此交互界面                                                │"
    "├─────────────────────── BRIAN FUCK 指令帮助 ───────────────────────┤"
    "│ +   在当前单元中加1。如果单元位于 255，则会绕回 0                 │"
    "│ -   从当前单元减去1。如果单元位于 0，则会退到 255                 │"
    "│ >   将单元指针向右移动一位                                        │"
    "│ <   将单元指针向左移动一位                                        │"
    "│ .   将当前单元的值打印为ASCII字符。例如: 72 为 H，101 为 e        │"
    "│ ,   读取一个输入字节，并将其值存储在当前单元                      │"
    "│ [   如果当前单元为 0，则跳至匹配的 ] 后的指令。否则，继续执行循环 │"
    "│ ]   如果当前单元的值不为0，则跳回匹配的 [。否则，继续执行循环     │"
    "└───────────────────────────────────────────────────────────────────┘"
  )
  
  BF_VERSION=1.0.14
  [[ "$(bash --version 2>/dev/null)" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]];   BSH_VERSION=$BASH_REMATCH
  case "$1" in
    --help|-h)
      case "${LANG:-C}" in
        zh_*) printf "%s\n" "${HELP_ZH[@]}" ;;
        *)    printf "%s\n" "${HELP_EN[@]}" ;;
      esac
      ;;
    --version|-v)
      [[ "$(bc --version 2>/dev/null)"    =~ ([0-9]+\.[0-9]+\.[0-9]+) ]];    BC_VERSION=$BASH_REMATCH
      [[ "$(date --version 2>/dev/null)"  =~ ([0-9]+\.[0-9]+)         ]];  CORE_VERSION=$BASH_REMATCH
      [[ "$(grep --version 2>/dev/null)"  =~ ([0-9]+\.[0-9]+)         ]];  GREP_VERSION=$BASH_REMATCH
      echo "Brain Fuck $BF_VERSION Bash Script Edition | Interpreter And Generater By DeepSeek"
      echo "Dependencies: GNU bash $BSH_VERSION, GNU grep ${GREP_VERSION:-None}, GNU coreutils ${CORE_VERSION:-None}, bc ${BC_VERSION:-None}"
      ;;
    --build|-b)
      if [ ! -t 0 ]; then 
        brainfuck-generate "$(cat -)"
      elif [ -f "$2" ]; then
        brainfuck-generate "$(cat "$2")" > "$2".bf
        [[ "${LANG:-C}" == zh_* ]] && echo "已生成代码文件 $2.bf" || echo "Code file $2.bf has been generated"
      elif [ "$2" ]; then
        brainfuck-generate "$2"
      else
        echo -e "\e[31mERROR\e[0m 未输入内容"
        exit 1
      fi
      ;;
    --interact|-i)
      trap "echo; exit 0" 2
      set -o emacs history
      HISTFILE="${BF_HISTFILE:="$HOME/.bf_history"}"
      echo "Brain Fuck $BF_VERSION Bash Script Edition (GNU Bash $BSH_VERSION)"
      echo 'Type "?" for more information.'
      while true; do
        history -r
        read -erp "${BF_PS1:-"> "}" line
        echo "$line" >> "$BF_HISTFILE"
        case "$line" in
          '!'*)
            cmd="$(brainfuck "$line")"
            echo "[^!] OK, cmd = $cmd"
            bash -c "$cmd"
            ;;
          '#'*)
            line="${line/'#'/}"
            [[ "${line// /}" ]] || continue
            echo "[^#] OK, Generate BFCode"
            brainfuck-generate "$line"
            ;;
          ';'*)
            line="${line/';'/}"
            line="${line//[^0-9]/}"
            code=$((line))
            echo "[^;] OK, EXIT = $code"
            exit $code
            ;;
          ':'*)
            echo "[^:] OK, Clear Screen"
            clear
            ;;
          '?'*)
            case "${LANG:-C}" in
              zh_*) printf "%s\n" "${HELP_INFORMATION_ZH[@]}" ;;
              *)    printf "%s\n" "${HELP_INFORMATION_EN[@]}" ;;
            esac
            ;;
          *)
            [[ "${line// /}" ]] || continue
            brainfuck "$line"
            ;;
        esac
      done
      ;;
    *)
      [[ "$1"  || ! -t 0 ]] || { [[ "${LANG:-C}" == zh_* ]] && echo -e "\e[31mERROR\e[0m 未输入BF代码" || echo -e "\e[31mERROR\e[0m BF code not entered"; exit 1; }
      brainfuck "$@"
      ;;
  esac
fi