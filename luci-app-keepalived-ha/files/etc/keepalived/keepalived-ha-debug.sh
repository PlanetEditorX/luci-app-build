#!/bin/sh

CONFIG="/etc/keepalived/keepalived.conf"
VIP=""
IFACE=""
VRID=""
PRIORITY=""
LOGTAG="keepalived-ha"

echo "🔍 [1] 检查配置文件路径: $CONFIG"
if [ ! -f "$CONFIG" ]; then
    echo "❌ 配置文件不存在: $CONFIG"
    exit 1
fi

echo "📄 [2] 提取配置参数..."
VIP=$(grep -A1 "virtual_ipaddress" "$CONFIG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
IFACE=$(grep "interface" "$CONFIG" | awk '{print $2}')
VRID=$(grep "virtual_router_id" "$CONFIG" | awk '{print $2}')
PRIORITY=$(grep "priority" "$CONFIG" | awk '{print $2}')

echo "    ➤ VIP: $VIP"
echo "    ➤ 接口: $IFACE"
echo "    ➤ VRID: $VRID"
echo "    ➤ 优先级: $PRIORITY"

echo "🔌 [3] 检查接口状态..."
ip link show "$IFACE" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 接口 $IFACE 不存在或未启用"
    exit 1
fi
echo "✅ 接口 $IFACE 正常"

echo "🌐 [4] 检查 VIP 是否已绑定..."
ip addr show dev "$IFACE" | grep "$VIP" >/dev/null
if [ $? -eq 0 ]; then
    echo "✅ VIP $VIP 已绑定在 $IFACE"
else
    echo "⚠️ VIP $VIP 未绑定"
fi

echo "🧠 [5] 检查 keepalived 进程状态..."
PID=$(pidof keepalived)
if [ -z "$PID" ]; then
    echo "❌ keepalived 未运行"
else
    echo "✅ keepalived 正在运行 (PID: $PID)"
fi

echo "📡 [6] 检查 VRRP 状态日志..."
logread | grep "VRRP_Instance" | tail -n 5

echo "📜 [7] 检查是否触发 vip_up.sh/vip_down.sh..."
logread | grep "$LOGTAG" | grep "VIP" | tail -n 5

echo "🧪 [8] 手动测试 vip_up.sh 是否可执行..."
if [ -x /etc/keepalived/vip_up.sh ]; then
    echo "✅ vip_up.sh 可执行，尝试运行..."
    sh -x /etc/keepalived/vip_up.sh
else
    echo "❌ vip_up.sh 不可执行或不存在"
fi

echo "✅ 调试完成。请根据输出检查是否进入 MASTER 状态，以及是否触发了 VIP 脚本。"
