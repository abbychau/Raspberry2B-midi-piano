#!/bin/bash

echo "=== $(date) Piano startup begins ==="
echo "User: $(whoami)"

echo "=== 檢查音頻設備 ==="
cat /proc/asound/cards

echo "重置音頻系統..."
sudo systemctl restart alsa-utils 2>/dev/null || true

# 停止 PulseAudio，使用 ALSA 直接輸出
pulseaudio -k 2>/dev/null || true
sleep 5

echo "設定 ALSA 音量和輸出..."
# 強制使用 3.5mm 輸出
amixer cset numid=3 1
amixer set Master 100%

echo "=== 檢查 ALSA 設定 ==="
amixer get Master

echo "清理並啟動 FluidSynth (使用 ALSA)..."
pkill fluidsynth 2>/dev/null || true
sleep 2

echo "=== 檢查 MIDI 設備 ==="
aconnect -l

# 使用 ALSA 直接輸出，避免 PulseAudio 問題
fluidsynth -a alsa -m alsa_seq -is -g 0.8 \
  -o audio.period-size=128 \
  -o audio.periods=3 \
  -o audio.alsa.device=hw:0 \
  /usr/share/sounds/sf2/FluidR3_GM.sf2 &

FLUID_PID=$!
echo "FluidSynth PID: $FLUID_PID"

echo "等待 FluidSynth 完全啟動..."
sleep 8

echo "=== 檢查 FluidSynth 是否運行 ==="
ps aux | grep fluidsynth | grep -v grep

echo "=== 檢查 MIDI 設備（FluidSynth 啟動後）==="
aconnect -l

echo "連接 MIDI..."
# 等待 FluidSynth MIDI 端口就緒
timeout=10
while [ $timeout -gt 0 ]; do
    if aconnect -o | grep -q "FLUID Synth"; then
        echo "FluidSynth MIDI 端口已就緒"
        break
    fi
    sleep 1
    timeout=$((timeout-1))
    echo "等待 FluidSynth MIDI 端口... ($timeout)"
done

if aconnect 24:0 128:0 2>/dev/null; then
    echo "✓ 連接成功 24:0 -> 128:0"
elif aconnect 24:1 128:0 2>/dev/null; then
    echo "✓ 連接成功 24:1 -> 128:0"
else
    echo "✗ MIDI 連接失敗"
fi

echo "=== 最終 MIDI 連接狀態 ==="
aconnect -l

echo "=== 測試音頻輸出 ==="
speaker-test -c 2 -t wav -l 1 -D hw:0

echo "電子琴已就緒！"

# 保持腳本運行
while true; do
    sleep 60
    # 檢查 FluidSynth 是否還在運行
    if ! pgrep fluidsynth > /dev/null; then
        echo "$(date) FluidSynth 停止，重新啟動..."
        fluidsynth -a alsa -m alsa_seq -is -g 0.8 \
          -o audio.period-size=128 \
          -o audio.periods=3 \
          -o audio.alsa.device=hw:0 \
          /usr/share/sounds/sf2/FluidR3_GM.sf2 &
        sleep 5
        aconnect 24:0 128:0 2>/dev/null || aconnect 24:1 128:0 2>/dev/null
    fi
done
