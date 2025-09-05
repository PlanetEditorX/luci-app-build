#!/bin/sh

export HOME=/root # Git 读取全局配置

# 定义 OpenClash 目录和相关路径
OPENCLASH_DIR="/etc/openclash"
OPENCLASH_INIT_SCRIPT="/etc/init.d/openclash"
LOG_FILE="/var/log/model-update.log"
GIT_DIR="/tmp/openclash"
GIT_PATH=$(uci get model-update.config.git_path 2>/dev/null)

# 函数：记录日志
log_message() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg" >> "$LOG_FILE"
    logger -t model-update "$msg"
}

if [ -z "$GIT_PATH" ]; then
    log_message "未设置 Git 仓库地址，请先配置 model-update.config.git_path"
    exit 1
fi

log_message "--- Script started ---"

# --- 检查文件大小 ---
SMART_WEIGHT_FILE="$OPENCLASH_DIR/smart_weight_data.csv"
if [ -f "$SMART_WEIGHT_FILE" ]; then
    FILE_SIZE_B=$(ls -l "$SMART_WEIGHT_FILE" | awk '{print $5}')
    log_message "File size of $SMART_WEIGHT_FILE is $FILE_SIZE_B bytes."
else
    log_message "File $SMART_WEIGHT_FILE does not exist. Exiting."
    exit 0
fi

if [ "$FILE_SIZE_B" -le 10240 ]; then
    log_message "File size is <= 10KB. No action needed. Exiting."
	log_message "--- Script finished ---"
    exit 0
fi

log_message "File size is > 10KB. Continuing with update process."


# 获取全局 Git 身份
GIT_USER=$(git config --global user.name)
GIT_EMAIL=$(git config --global user.email)

if [ -z "$GIT_USER" ] || [ -z "$GIT_EMAIL" ]; then
    echo "未配置全局 Git 身份，请使用 git config --global 设置 user.name 和 user.email" >> "$LOG_FILE"
    exit 1
fi

# --- 拉取最新镜像 ---
log_message "Pull the latest image..."
if [ -d "$GIT_DIR" ]; then
    log_message "Directory '$GIT_DIR' exists."
    cd "$GIT_DIR"
    git fetch --all >> "$LOG_FILE" 2>&1
    git reset --hard origin/main >> "$LOG_FILE" 2>&1
else
    log_message "Directory '$GIT_DIR' does not exist."
    git clone --depth 1 "$GIT_PATH" "$GIT_DIR" >> "$LOG_FILE" 2>&1
    cd "$GIT_DIR" || { log_message "Error: Cannot change directory to $GIT_DIR. Exiting."; exit 1; }
fi

# --- 提交更新 ---
log_message "Move $SMART_WEIGHT_FILE to $GIT_DIR..."
mv "$SMART_WEIGHT_FILE" "$GIT_DIR" >> "$LOG_FILE" 2>&1
ls -l "$GIT_DIR/smart_weight_data.csv" >> "$LOG_FILE" 2>&1

log_message "Adding all changes..."
git add . >> "$LOG_FILE" 2>&1
COMMIT_MESSAGE="Auto Update in $(date '+%Y-%m-%d %H:%M:%S')"
log_message "Committing local changes: $COMMIT_MESSAGE"
git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1
sleep 5

log_message "Pushing local changes to remote repository..."
git push >> "$LOG_FILE" 2>&1

# --- 再次拉取更新 ---
sleep 120
log_message "Pulling latest changes again..."
SECOND_PULL_SUCCESS=0
for i in $(seq 1 3); do
    log_message "Attempt $i of 3: Pulling latest changes again..."
    GIT_OUTPUT=$(git pull 2>&1 | tee -a "$LOG_FILE")
    if [ $? -eq 0 ]; then
        if echo "$GIT_OUTPUT" | grep -q "Already up to date"; then
            log_message "Second git pull succeeded but no updates on attempt $i. Retrying in 60 seconds..."
            sleep 60
        else
            log_message "Second git pull successful with updates on attempt $i."
            SECOND_PULL_SUCCESS=1
            break
        fi
    else
        log_message "Second git pull failed on attempt $i. Retrying in 60 seconds..."
        sleep 60
    fi
done

if [ "$SECOND_PULL_SUCCESS" -eq 0 ]; then
    log_message "Error: Second git pull failed after 3 attempts. Continuing script but be aware."
fi

sleep 10

# --- 拷贝模型 ---
log_message "Copy $GIT_DIR/Model.bin to $OPENCLASH_DIR..."
cp "$GIT_DIR/Model.bin" "$OPENCLASH_DIR" >> "$LOG_FILE" 2>&1

# --- 重启 OpenClash 服务 ---
log_message "Checking OpenClash service status..."
if pgrep -f "openclash" >/dev/null; then
    log_message "OpenClash service is running. Restarting service..."
    "$OPENCLASH_INIT_SCRIPT" restart >> "$LOG_FILE" 2>&1
else
    log_message "OpenClash service is not running. Skipping restart."
fi

log_message "--- Script finished ---"
