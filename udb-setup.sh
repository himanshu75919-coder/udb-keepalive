#!/bin/bash
# =====================================================================
#  Utility Duniya Bot — ONE-COMMAND SERVER SETUP
#  ---------------------------------------------------------------------
#  Kisi bhi FRESH Ubuntu / Debian / Oracle Linux server par chalao —
#  bot 24x7 auto-restart ke saath chal jayega. Koi coding nahi chahiye.
#
#  Chalane ka tareeka (server ke terminal me):
#      bash udb-setup.sh
#
#  Script khud hi:
#     1) Python + git install karta hai
#     2) Aapka settings file (.env) leta hai  [paste karna hai]
#     3) Bot ka code GitHub se laata hai
#     4) systemd service banata hai (crash = auto restart, reboot = auto start)
#     5) Telegram webhook hata ke polling ON karta hai
#     6) Bot start karke health check dikhata hai
# =====================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; CYA='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $*${NC}"; }
bad()  { echo -e "${RED}❌ $*${NC}"; }
warn() { echo -e "${YEL}⚠️  $*${NC}"; }
info() { echo -e "${CYA}➡️  $*${NC}"; }
sec() { echo; echo -e "${CYA}=============================================================${NC}"; echo -e "${CYA}  $*${NC}"; echo -e "${CYA}=============================================================${NC}"; }

APP_DIR="/opt/utility-duniya-bot"
SERVICE="utility-duniya-bot"
REPO="utility-duniya-bot"

sec "Utility Duniya Bot — SERVER SETUP (1 command)"

# ---------- 0. root check ----------
if [ "$(id -u)" != "0" ]; then
  bad "Ye script ROOT ke roop me chalana hai."
  echo "   Chalao:  sudo bash $0"
  exit 1
fi
ok "Root access mil gaya"

# ---------- 1. package manager ----------
if command -v apt-get >/dev/null 2>&1; then
  PKG="apt-get"
elif command -v dnf >/dev/null 2>&1; then
  PKG="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG="yum"
else
  bad "Ye Linux distro support nahi (apt/dnf/yum nahi mila)."
  exit 1
fi
info "Package manager: $PKG"

sec "STEP 1/6 — Python + Git install (2-3 minute)"
if [ "$PKG" = "apt-get" ]; then
  export DEBIAN_FRONTEND=noninteractive
  $PKG update -y -qq >/dev/null 2>&1 || warn "update me chhoti dikkat (aage badh rahe hain)"
  $PKG install -y -qq python3 python3-venv python3-pip git curl ca-certificates openssl >/dev/null 2>&1
else
  $PKG install -y -q python3 python3-pip git curl ca-certificates openssl >/dev/null 2>&1
fi
if ! command -v python3 >/dev/null 2>&1; then bad "Python install nahi hua — dobara chalao."; exit 1; fi
ok "$(python3 --version) install ho gaya"

# ---------- 2. .env maango ----------
sec "STEP 2/6 — Settings file (.env) do"
echo "   Aap 'udb.env' file me sab kuch pehle se rakha hua hai."
echo "   1) Us file ko kholo, poora text copy karo (Ctrl+A, Ctrl+C)"
echo "   2) Yahan terminal me paste karo (Ctrl+Shift+V ya right-click)"
echo "   3) Paste hone ke baad ek nayi line me likho:  __END__   phir Enter"
echo
mkdir -p "$APP_DIR"
ENV_FILE="$APP_DIR/.env"
> "$ENV_FILE"
while IFS= read -r line; do
  [ "$line" = "__END__" ] && break
  printf '%s\n' "$line" >> "$ENV_FILE"
done

if ! grep -q "^BOT_TOKEN=" "$ENV_FILE"; then
  bad "BOT_TOKEN nahi mila — .env theek se paste nahi hua."
  echo "   File kholo: nano $ENV_FILE   (apna BOT_TOKEN daalo + Ctrl+O, Enter, Ctrl+X)"
  exit 1
fi
CHK_TOKEN="$(grep -m1 '^BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2- | tr -d ' \r\n')"
[ -z "$CHK_TOKEN" ] && { bad "BOT_TOKEN khaali hai."; exit 1; }
ok "BOT_TOKEN mil gaya (${#CHK_TOKEN} characters)"

# ---------- 3. polling mode ----------
sec "STEP 3/6 — Bot ko POLLING mode me set kar raha hoon"
# Server par public HTTPS domain nahi hota, isliye webhook nahi chalega.
# Polling me bot khud Telegram se poochta rehta hai — 24x7 bina cold start.
sed -i '/^WEBHOOK_URL=/d'  "$ENV_FILE"
sed -i '/^WEBHOOK_MODE=/d' "$ENV_FILE"
sed -i '/^BOT_SELF_URL=/d' "$ENV_FILE"
{
  echo "WEBHOOK_MODE=off"
  echo "KEEPALIVE_ENABLED=0"
} >> "$ENV_FILE"
ok "Polling ON (webhook OFF) — cold start khatam"

# ---------- 4. code laao ----------
sec "STEP 4/6 — Bot ka code GitHub se laa raha hoon"
GH_TOKEN="$(grep -m1 '^VAULT_GITHUB_TOKEN=' "$ENV_FILE" | cut -d= -f2- | tr -d ' \r\n')"
if [ -d "$APP_DIR/.git" ]; then
  info "Code pehle se hai — latest update laa raha hoon"
  git -C "$APP_DIR" fetch --all -q && git -C "$APP_DIR" reset --hard origin/main -q && ok "Code update ho gaya"
elif [ -n "$GH_TOKEN" ]; then
  if git clone -q "https://${GH_TOKEN}@github.com/himanshu75919-coder/${REPO}.git" "$APP_DIR.code" 2>/dev/null; then
    cp -r "$APP_DIR.code/." "$APP_DIR/" && rm -rf "$APP_DIR.code"
    ok "Private repo clone ho gaya"
  else
    warn "Clone nahi hua (token purana ho sakta hai) — public backup se koshish"
    git clone -q "https://github.com/himanshu75919-coder/${REPO}.git" "$APP_DIR.code" 2>/dev/null && \
      cp -r "$APP_DIR.code/." "$APP_DIR/" && rm -rf "$APP_DIR.code" && ok "Code aa gaya"
  fi
else
  bad "VAULT_GITHUB_TOKEN nahi mila aur code bhi nahi hai."
  exit 1
fi
[ -f "$APP_DIR/bot.py" ] || { bad "bot.py nahi mila. Code theek se nahi aaya."; exit 1; }
ok "bot.py mil gaya ($(wc -l < "$APP_DIR/bot.py") lines)"

# Python libraries
sec "STEP 5/6 — Bot ki libraries install (2-3 minute)"
cd "$APP_DIR"
python3 -m venv venv >/dev/null 2>&1 || python3 -m venv --without-pip venv >/dev/null 2>&1
"$APP_DIR/venv/bin/python" -m pip install -q --upgrade pip >/dev/null 2>&1
if ! "$APP_DIR/venv/bin/python" -m pip install -q -r requirements.txt 2>/tmp/piperr.log; then
  warn "pip me dikkat — venv ke bina system python se try kar raha hoon"
  python3 -m pip install -q --break-system-packages -r requirements.txt 2>/dev/null \
    || pip3 install -q -r requirements.txt 2>/dev/null \
    || { bad "Libraries install nahi hui:"; tail -5 /tmp/piperr.log; exit 1; }
  PYEXEC="/usr/bin/python3"
else
  PYEXEC="$APP_DIR/venv/bin/python"
fi
ok "Libraries install ho gayi ($PYEXEC)"

# ---------- 6. systemd service ----------
sec "STEP 6/6 — Auto-restart service bana raha hoon"
cat > "/etc/systemd/system/${SERVICE}.service" <<EOF
[Unit]
Description=Utility Duniya Telegram Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=${PYEXEC} ${APP_DIR}/bot.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
# crash hone par khud uth jayega, server reboot par bhi khud start hoga

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "${SERVICE}" >/dev/null 2>&1
ok "Service ban gayi + boot par auto-start ON"

# Telegram ko bolo: purana webhook hatao (warna purane server se takraav hoga)
info "Telegram webhook hata raha hoon (purane server ka takraav khatam)"
curl -s -m 25 "https://api.telegram.org/bot${CHK_TOKEN}/deleteWebhook?drop_pending_updates=false" \
  | grep -q '"ok":true' && ok "Webhook hata diya" || warn "Webhook delete me dikkat (aage badh rahe hain)"

info "Bot start kar raha hoon…"
systemctl restart "${SERVICE}"
sleep 12

# ---------- health check ----------
sec "RESULT"
if systemctl is-active --quiet "${SERVICE}"; then
  ok "BOT CHAL RAHA HAI ✅  (24x7, auto-restart ON)"
else
  warn "Bot start nahi hua — neeche error dekho:"
  journalctl -u "${SERVICE}" -n 20 --no-pager
  exit 1
fi
echo
echo "  Bot ka haal dekhne ke liye:      sudo systemctl status ${SERVICE}"
echo "  Live log dekhne ke liye:         sudo journalctl -u ${SERVICE} -f"
echo "  Bot band karne ke liye:          sudo systemctl stop ${SERVICE}"
echo "  Bot chalu karne ke liye:         sudo systemctl start ${SERVICE}"
echo "  Code update karne ke liye:       sudo bash udb-setup.sh   (dobara chalao)"
echo
echo "  Ab Telegram me jaake bot ko /start bhejo — jawab aana chahiye."
echo
warn "AAKHRI ZAROORI KAAM: purana hosting (Render) BAND/SUSPEND karo,"
echo "   warna do bot ek saath chalenge aur Telegram 'Conflict' dega."
echo "   Render dashboard → utility-duniya-bot → Settings → Suspend."
echo
echo -e "${GREEN}SETUP POORA HUA — bot ab is server par 24x7 chalega. 🚀${NC}"
