FROM jlesage/baseimage-gui:ubuntu-20.04-v4

# 构建参数，用于指定目标平台
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG APT_MIRROR_MODE=cn
ARG SOGOU_PINYIN_AMD64_URL=https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin/releases/latest/download/sogou-pinyin-amd64.deb
ARG SOGOU_PINYIN_ARM64_URL=https://github.com/xiaoheiCat/docker-wechat-sogou-pinyin/releases/latest/download/sogou-pinyin-arm64.deb
ARG WECHAT_AMD64_URL=https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb
ARG WECHAT_ARM64_URL=https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb
ENV DEBIAN_FRONTEND=noninteractive

# 确保基础系统文件存在，避免安装依赖时 useradd/adduser 失败
# 基础镜像可能缺少这些文件，需要创建完整的系统用户数据库

# 创建 /etc/passwd，包含必要的系统用户
RUN cat > /etc/passwd << 'PASSWD_EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
_apt:x:100:65534::/nonexistent:/usr/sbin/nologin
systemd-network:x:101:102:systemd Network Management,,,:/run/systemd:/usr/sbin/nologin
systemd-resolve:x:102:103:systemd Resolver,,,:/run/systemd:/usr/sbin/nologin
systemd-timesync:x:103:104:systemd Time Synchronization,,,:/run/systemd:/usr/sbin/nologin
messagebus:x:104:106::/nonexistent:/usr/sbin/nologin
PASSWD_EOF

# 创建 /etc/group，包含必要的系统组
RUN cat > /etc/group << 'GROUP_EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
dip:x:30:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
input:x:101:
systemd-journal:x:101:
systemd-timesync:x:104:
systemd-network:x:102:
systemd-resolve:x:103:
messagebus:x:106:
GROUP_EOF

# 创建假的 systemctl 和 policy-rc.d，防止任何包安装时尝试启动 systemd 服务
RUN printf '#!/bin/sh\nexit 0' > /usr/sbin/policy-rc.d && \
    chmod +x /usr/sbin/policy-rc.d && \
    printf '#!/bin/sh\nexit 0' > /usr/local/bin/systemctl && \
    chmod +x /usr/local/bin/systemctl && \
    mkdir -p /var/lib/dpkg/info && \
    dpkg-divert --local --rename --add /var/lib/dpkg/info/systemd.postinst && \
    printf '#!/bin/sh\nexit 0\n' > /var/lib/dpkg/info/systemd.postinst && \
    chmod +x /var/lib/dpkg/info/systemd.postinst

# 配置APT源。默认使用阿里云镜像，避免构建时因地理位置探测误判而切回官方源。
RUN set -eux; \
    if [ "$APT_MIRROR_MODE" = "cn" ]; then \
        sed -i 's@/archive.ubuntu.com/@/mirrors.aliyun.com/@g' /etc/apt/sources.list; \
        sed -i 's@/security.ubuntu.com/@/mirrors.aliyun.com/@g' /etc/apt/sources.list; \
        sed -i 's@/ports.ubuntu.com/ubuntu-ports/@/mirrors.aliyun.com/ubuntu-ports/@g' /etc/apt/sources.list; \
    elif [ "$APT_MIRROR_MODE" != "official" ]; then \
        echo "Unsupported APT_MIRROR_MODE: $APT_MIRROR_MODE"; \
        exit 1; \
    fi && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y curl

# 设置 locale 环境变量，避免 perl 警告
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# 安装必要依赖
RUN \
    set -eux; \
    # 创建 /run 目录，避免 systemd post-install 脚本失败
    mkdir -p /run && \
    # 生成 locale
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends locales \
    && sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && locale-gen zh_CN.UTF-8 \
    && update-locale LANG=zh_CN.UTF-8 \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends language-pack-zh-hans fonts-noto-cjk curl \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends shared-mime-info desktop-file-utils libxcb1 libxcb-icccm4 libxcb-image0 \
    libxcb-keysyms1 libxcb-randr0 libxcb-render0 libxcb-render-util0 libxcb-shape0 \
    libxcb-shm0 libxcb-sync1 libxcb-util1 libxcb-xfixes0 libxcb-xkb1 libxcb-xinerama0 \
    libxcb-xkb1 libxcb-glx0 libatk1.0-0 libatk-bridge2.0-0 libc6 libcairo2 libcups2 \
    libdbus-1-3 libfontconfig1 libgbm1 libgcc1 libgdk-pixbuf2.0-0 libglib2.0-0 \
    libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 \
    libxss1 libxtst6 libatomic1 libxcomposite1 libxrender1 libxrandr2 libxkbcommon-x11-0 \
    libfontconfig1 libdbus-1-3 libnss3 libx11-xcb1 libasound2 \
    # 强制配置所有包，忽略 systemd 的错误
    && dpkg --configure -a || true

# 多架构支持：准备搜狗输入法安装包
RUN mkdir -p /tmp/packages
COPY temp-packages/. /tmp/packages/

# 安装中文拼音输入法
RUN echo "keyboard-configuration keyboard-configuration/layoutcode string cn" | debconf-set-selections
RUN \
    set -ux; \
    { \
    # 安装 fcitx 输入法框架（使用 --no-install-recommends 避免 systemd 依赖）
    # 忽略 systemd 配置错误，它不影响实际功能
    (apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends fcitx fcitx-config-gtk fcitx-frontend-all 2>&1 || true); \
    (dpkg --configure -a 2>&1 || true); \
    # 卸载原有 ibus 输入法框架
    (apt-get purge -y ibus 2>&1 || true); \
    # 根据目标平台安装对应架构的搜狗拼音输入法
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        SOGOU_DEB=/tmp/packages/sogou-pinyin-amd64.deb; \
        SOGOU_URL="$SOGOU_PINYIN_AMD64_URL"; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        SOGOU_DEB=/tmp/packages/sogou-pinyin-arm64.deb; \
        SOGOU_URL="$SOGOU_PINYIN_ARM64_URL"; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; \
        exit 1; \
    fi; \
    if [ ! -s "$SOGOU_DEB" ]; then \
        curl -fL --retry 3 --retry-delay 2 -o "$SOGOU_DEB" "$SOGOU_URL"; \
    fi; \
    (dpkg --ignore-depends=lsb-core -i "$SOGOU_DEB" 2>&1 || apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 -f install -y --no-install-recommends 2>&1 || true); \
    (dpkg --configure -a 2>&1 || true); \
    # 解决可能缺少的依赖
    (apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends libqt5qml5 libqt5quick5 libqt5quickwidgets5 qml-module-qtquick2 2>&1 || true); \
    (dpkg --configure -a 2>&1 || true); \
    (apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends libgsettings-qt1 2>&1 || true); \
    (dpkg --configure -a 2>&1 || true); \
    # 安装 im-config（输入法配置工具，fcitx 需要它）
    (apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 --fix-missing install -y --no-install-recommends im-config 2>&1 || true); \
    (dpkg --configure -a 2>&1 || true); \
    } && \
    # 设置默认输入法为 fcitx 并将搜狗输入法设为默认配置文件
    cp /usr/share/applications/fcitx.desktop /etc/xdg/autostart/ && \
    (which im-config >/dev/null 2>&1 && im-config -n fcitx || true) && \
    mkdir -p /config/xdg/config/fcitx && \
    # 创建完整的fcitx配置文件
    echo -e "[Hotkey]\n# Trigger Input Method\nTriggerKey=ALT_SHIFT_KEY\n# Enumerate Input Method\nEnumerateForwardKeys=CTRL_SHIFT_KEY\nEnumerateBackwardKeys=SHIFT_CTRL_KEY\n# Skip the first input method\nEnumerateSkipFirst=False\n# Toggle embedded preedit\nTogglePreedit=CTRL_ALT_KEY\n# Remind Mode Input Method Switch\nRemindModeDisableKeys=ALT_SHIFT_KEY\n# Switch to first input method\nSwitchToFirstMethodKey=SHIFT_KEY\n# Switch between first and second input method\nSwitchToSecondMethodKey=CTRL_SHIFT_KEY\n\n[Program]\n# Delay in milliseconds for switching between windows\nDelayTimeBeforeFirstIMMethod=25\n# Delay in milliseconds for switching input method\nDelayTimeBeforeSwitchIM=50\n# Share Input Method State Among Windows\nShareStateAmongAllWindows=True\n# Show Input Method Hint After Input method activated\nShowInputMethodHint=True\n# Show Input Method Hint When trigger input method\nShowInputMethodHintTriggerOnly=False\n# Show Input Method Hint Delay in milliseconds\nShowInputMethodHintDelay=500\n# Show first input method indicator\nShowFirstInputMethodIndicator=True\n# Show Current Input Method Name\nShowCurrentInputMethod=True\n# Show Input Method Name When switch input method\nShowInputMethodNameWhenSwitchInFocus=False\n# Show compact input method indicator\nShowCompactInputMethodIndicator=False\n# Show emoji icon on input method indicator\nShowEmojiOnPanel=False\n# Use custom font\nUseCustomFont=False\n# Font for input method indicator\nCustomFont=\n\n[Appearance]\n# Show Input Method Preedit in Application\nShowPreeditInApplication=True\n# Show Input Method Preedit in the top of screen\nShowPreeditInTopWindow=False\n# Show input method panel when preedit is empty\nShowInputMethodPanelWhenPreeditEmpty=False\n# Show input method panel after input method changed\nShowInputMethodPanelAfterChangedOnly=True\n# Center input method panel\nCenterInputMethodPanel=False\n# Show input method panel position relative to the cursor\nShowInputMethodPanelRelativeToCursor=True\n# Show input method panel position\nShowInputMethodPanelPosition=0\n# Input method panel is always horizontal\nHorizontalInputMethodPanel=False\n# Force to show input method panel on the screen of the cursor\nShowInputMethodPanelOnFocusedScreen=True\n# Show Input Method Panel when only one input method\nShowInputMethodPanelWhenOnlyOne=False\n# Show compact input method panel\nShowCompactInputMethodPanel=False\n# Input Method Panel Margin\nInputMethodPanelMargin=0\n# Show the version of Fcitx\nShowFcitxVersion=True\n# Show first input method indicator\nShowFirstInputMethodIndicator=True\n# Show Input Method Name When switch input method\nShowInputMethodNameWhenSwitchInFocus=False\n# Show compact input method indicator\nShowCompactInputMethodIndicator=False\n\n[Behavior]\n# Active By Default\nActiveByDefault=True\n# Share Input State\nShareInputState=All\n# Show Input Method When Inactive\nShowInputMethodWhenInactive=True\n# Show Input Method After Input method activated\nShowInputMethodAfterActivated=True\n# Auto save period in seconds\nAutoSavePeriod=5\n# Show Input Method Hint After Input method activated\nShowInputMethodHint=True\n# Show Input Method Hint When trigger input method\nShowInputMethodHintTriggerOnly=False\n# Show Input Method Hint Delay in milliseconds\nShowInputMethodHintDelay=500\n# Show first input method indicator\nShowFirstInputMethodIndicator=True\n# Show Current Input Method Name\nShowCurrentInputMethod=True\n# Show Input Method Name When switch input method\nShowInputMethodNameWhenSwitchInFocus=False\n# Show compact input method indicator\nShowCompactInputMethodIndicator=False\n# Show emoji icon on input method indicator\nShowEmojiOnPanel=False\n# Use custom font\nUseCustomFont=False\n# Font for input method indicator\nCustomFont=" > /config/xdg/config/fcitx/config && \
    sed -i '1s/^-e //' /config/xdg/config/fcitx/config && \
    echo -e "[Profile]\n# Input Method List\nIMList=fcitx-keyboard-us:True,sogoupinyin:True\n# Group List\nGroups=\n# Group Name\nGroup0Name=\n# Group Input Method List\nGroup0IMList=\n# Default Input Method\nDefaultIM=sogoupinyin\n# Default Input Method for Group0\nGroup0DefaultIM=\n# Input Method Order\nIMOrder=" > /config/xdg/config/fcitx/profile && \
    sed -i '1s/^-e //' /config/xdg/config/fcitx/profile && \
    # 清理工作
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 生成微信图标
RUN APP_ICON_URL=https://res.wx.qq.com/a/wx_fed/assets/res/NTI4MWU5.ico && \
    install_app_icon.sh "$APP_ICON_URL"
    
# 设置应用名称
RUN set-cont-env APP_NAME "微信中文版"

# 根据目标平台下载并安装对应的微信安装包
RUN set -eux; \
    mkdir -p /tmp/packages; \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        WECHAT_DEB=/tmp/packages/wechat-amd64.deb; \
        WECHAT_URL="$WECHAT_AMD64_URL"; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        WECHAT_DEB=/tmp/packages/wechat-arm64.deb; \
        WECHAT_URL="$WECHAT_ARM64_URL"; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; \
        exit 1; \
    fi && \
    if [ ! -s "$WECHAT_DEB" ]; then \
        curl -fL --retry 3 --retry-delay 2 -o "$WECHAT_DEB" "$WECHAT_URL"; \
    fi && \
    if ! dpkg -i "$WECHAT_DEB" > /tmp/wechat_install.log 2>&1; then \
        apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 -f install -y >> /tmp/wechat_install.log 2>&1; \
        dpkg -i "$WECHAT_DEB" >> /tmp/wechat_install.log 2>&1; \
    fi && \
    rm -rf /tmp/packages

ENV XMODIFIERS="@im=fcitx"
ENV GTK_IM_MODULE="fcitx"
ENV QT_IM_MODULE="fcitx"
ENV XIM_PROGRAM="fcitx"
ENV XIM=fcitx

# 复制增强版启动脚本
COPY startapp-enhanced.sh /startapp-enhanced.sh
RUN chmod +x /startapp-enhanced.sh

# 创建标准启动脚本（使用增强版）
RUN echo '#!/bin/sh' > /startapp.sh && \
    echo 'exec /startapp-enhanced.sh' >> /startapp.sh && \
    chmod +x /startapp.sh

VOLUME /root/.xwechat
VOLUME /root/xwechat_files
VOLUME /root/downloads

# 配置微信版本号
RUN set-cont-env APP_VERSION "$(grep -o 'Unpacking wechat ([0-9.]*)' /tmp/wechat_install.log | sed 's/Unpacking wechat (\(.*\))/\1/')"
