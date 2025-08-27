# Raspberry Pi 2B MIDI 電子琴：系統設置總結

總共只需要安裝 **3 個主要套件**，設定 **1 個腳本** 和 **1 個 cron 任務**。

## 必要的軟體安裝

### 音頻合成相關
```bash
# FluidSynth 合成器和 SoundFont
sudo apt update
sudo apt install fluidsynth fluid-soundfont-gm

# ALSA 工具（通常已預裝）
sudo apt install alsa-utils

# MIDI 連接工具（通常已預裝）
sudo apt install alsa-utils
```

### 可選但建議安裝
```bash
# 更多 SoundFont 選擇
sudo apt install fluid-soundfont-gs

# 音頻測試工具
sudo apt install pulseaudio-utils  # 如果需要 PulseAudio 測試
```

## 系統配置設定

### 1. 音頻輸出配置
```bash
# 在 raspi-config 中選擇 PulseAudio（雖然最終使用 ALSA）
sudo raspi-config
# 選擇 Advanced Options → Audio → PulseAudio

# 手動強制 3.5mm 輸出
sudo amixer cset numid=3 1
sudo amixer set Master 80%
```

### 2. 用戶權限設定
```bash
# 確保用戶在 audio 群組中
sudo usermod -a -G audio $USER
# 需要重新登入或重開機生效
```

### 3. 建立啟動腳本
```bash
# 建立腳本檔案
sudo nano /usr/local/bin/piano-startup.sh

# 設定執行權限
sudo chmod +x /usr/local/bin/piano-startup.sh
```

### 4. 設定自動啟動
```bash
# 編輯 cron 任務
crontab -e

# 加入這行：
@reboot sleep 10 && /usr/local/bin/piano-startup.sh >> /home/$(whoami)/piano.log 2>&1
```

## 完整的啟動腳本內容

`/usr/local/bin/piano-startup.sh`：
```bash
#!/bin/bash

echo "=== $(date) Piano startup begins ==="

# 重置音頻系統
sudo systemctl restart alsa-utils 2>/dev/null || true
pulseaudio -k 2>/dev/null || true
sleep 5

# 設定 ALSA 音量和輸出
amixer cset numid=3 1
amixer set Master 80%

# 清理並啟動 FluidSynth
pkill fluidsynth 2>/dev/null || true
sleep 2

# 啟動 FluidSynth (使用 ALSA 直接輸出)
fluidsynth -a alsa -m alsa_seq -is -g 0.8 \
  -o audio.period-size=128 \
  -o audio.periods=3 \
  -o audio.alsa.device=hw:0 \
  /usr/share/sounds/sf2/FluidR3_GM.sf2 &

sleep 8

# 等待並連接 MIDI
timeout=10
while [ $timeout -gt 0 ]; do
    if aconnect -o | grep -q "FLUID Synth"; then
        break
    fi
    sleep 1
    timeout=$((timeout-1))
done

# 連接 MIDI 鍵盤到 FluidSynth
aconnect 24:0 128:0 2>/dev/null || aconnect 24:1 128:0 2>/dev/null

echo "電子琴已就緒！"

# 保持運行並監控
while true; do
    sleep 60
    if ! pgrep fluidsynth > /dev/null; then
        echo "$(date) FluidSynth 重啟..."
        fluidsynth -a alsa -m alsa_seq -is -g 0.8 \
          -o audio.period-size=128 -o audio.periods=3 \
          -o audio.alsa.device=hw:0 \
          /usr/share/sounds/sf2/FluidR3_GM.sf2 &
        sleep 5
        aconnect 24:0 128:0 2>/dev/null || aconnect 24:1 128:0 2>/dev/null
    fi
done
```

## 驗證步驟

### 檢查安裝
```bash
# 檢查 FluidSynth
fluidsynth --version

# 檢查 SoundFont
ls -la /usr/share/sounds/sf2/

# 檢查音頻設備
cat /proc/asound/cards

# 檢查 MIDI 設備
aconnect -l
```

### 測試功能
```bash
# 手動執行腳本測試
sh /usr/local/bin/piano-startup.sh

# 檢查進程
ps aux | grep fluidsynth

# 檢查 MIDI 連接
aconnect -l

# 檢查 cron 任務
crontab -l
```

## 最小化安裝清單

如果要在全新的 Raspberry Pi OS 上重建：

```bash
# 1. 更新系統
sudo apt update && sudo apt upgrade -y

# 2. 安裝必要軟體
sudo apt install fluidsynth fluid-soundfont-gm alsa-utils -y

# 3. 設定用戶權限
sudo usermod -a -G audio $USER

# 4. 建立並設定啟動腳本
sudo nano /usr/local/bin/piano-startup.sh  # 貼入腳本內容
sudo chmod +x /usr/local/bin/piano-startup.sh

# 5. 設定自動啟動
crontab -e  # 加入 @reboot 行

# 6. 重開機測試
sudo reboot
```


