#!/bin/sh

install_awg_packages() {
    # Получение pkgarch с наибольшим приоритетом
    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')

    TARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 1)
    SUBTARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 2)
    VERSION=$(ubus call system board | jsonfilter -e '@.release.version')
    PKGPOSTFIX="_v${VERSION}_${PKGARCH}_${TARGET}_${SUBTARGET}.ipk"
    BASE_URL="https://github.com/Slava-Shchipunov/awg-openwrt/releases/download/"

    AWG_DIR="/tmp/amneziawg"
    mkdir -p "$AWG_DIR"
    
    if opkg list-installed | grep -q kmod-amneziawg; then
        echo "kmod-amneziawg already installed"
    else
        KMOD_AMNEZIAWG_FILENAME="kmod-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${KMOD_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "kmod-amneziawg file downloaded successfully"
        else
            echo "Error downloading kmod-amneziawg. Please, install kmod-amneziawg manually and run the script again"
            exit 1
        fi
        
        opkg install "$AWG_DIR/$KMOD_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "kmod-amneziawg file downloaded successfully"
        else
            echo "Error installing kmod-amneziawg. Please, install kmod-amneziawg manually and run the script again"
            exit 1
        fi
    fi

    if opkg list-installed | grep -q amneziawg-tools; then
        echo "amneziawg-tools already installed"
    else
        AMNEZIAWG_TOOLS_FILENAME="amneziawg-tools${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${AMNEZIAWG_TOOLS_FILENAME}"
        wget -O "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "amneziawg-tools file downloaded successfully"
        else
            echo "Error downloading amneziawg-tools. Please, install amneziawg-tools manually and run the script again"
            exit 1
        fi

        opkg install "$AWG_DIR/$AMNEZIAWG_TOOLS_FILENAME"

        if [ $? -eq 0 ]; then
            echo "amneziawg-tools file downloaded successfully"
        else
            echo "Error installing amneziawg-tools. Please, install amneziawg-tools manually and run the script again"
            exit 1
        fi
    fi
    
    if opkg list-installed | grep -q luci-app-amneziawg; then
        echo "luci-app-amneziawg already installed"
    else
        LUCI_APP_AMNEZIAWG_FILENAME="luci-app-amneziawg${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${LUCI_APP_AMNEZIAWG_FILENAME}"
        wget -O "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME" "$DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "luci-app-amneziawg file downloaded successfully"
        else
            echo "Error downloading luci-app-amneziawg. Please, install luci-app-amneziawg manually and run the script again"
            exit 1
        fi

        opkg install "$AWG_DIR/$LUCI_APP_AMNEZIAWG_FILENAME"

        if [ $? -eq 0 ]; then
            echo "luci-app-amneziawg file downloaded successfully"
        else
            echo "Error installing luci-app-amneziawg. Please, install luci-app-amneziawg manually and run the script again"
            exit 1
        fi
    fi

    rm -rf "$AWG_DIR"
}

manage_package() {
    local name="$1"
    local autostart="$2"
    local process="$3"

    # Проверка, установлен ли пакет
    if opkg list-installed | grep -q "^$name"; then
        
        # Проверка, включен ли автозапуск
        if /etc/init.d/$name enabled; then
            if [ "$autostart" = "disable" ]; then
                /etc/init.d/$name disable
            fi
        else
            if [ "$autostart" = "enable" ]; then
                /etc/init.d/$name enable
            fi
        fi

        # Проверка, запущен ли процесс
        if pidof $name > /dev/null; then
            if [ "$process" = "stop" ]; then
                /etc/init.d/$name stop
            fi
        else
            if [ "$process" = "start" ]; then
                /etc/init.d/$name start
            fi
        fi
    fi
}

echo "opkg update"
opkg update

#проверка и установка пакетов AmneziaWG
install_awg_packages

#проверяем установлени ли библиотека jq
if opkg list-installed | grep -q jq; then
    echo "jq already installed..."
else
	echo "jq not installed. Installed jq..."
	opkg install jq
	if [ $? -eq 0 ]; then
		echo "jq file downloaded successfully"
	else
		echo "Error installing jq. Please, install jq manually and run the script again"
		exit 1
	fi
fi

#проверяем установлени ли пакет dnsmasq-full
if opkg list-installed | grep -q dnsmasq-full; then
	echo "dnsmasq-full already installed..."
else
	echo "Installed dnsmasq-full..."
	cd /tmp/ && opkg download dnsmasq-full
	opkg remove dnsmasq && opkg install dnsmasq-full --cache /tmp/

	[ -f /etc/config/dhcp-opkg ] && cp /etc/config/dhcp /etc/config/dhcp-old && mv /etc/config/dhcp-opkg /etc/config/dhcp
fi

#проверяем установлени ли пакет coreutils-base64
if opkg list-installed | grep -q coreutils-base64; then
	echo "coreutils-base64 already installed..."
else
	echo "Installed coreutils-base64"
	opkg install coreutils-base64
	if [ $? -eq 0 ]; then
		echo "coreutils-base64 file downloaded successfully"
	else
		echo "Error installing coreutils-base64. Please, install coreutils-base64 manually and run the script again"
		exit 1
	fi
fi

DIR="/etc/config"
DIR_BACKUP="/root/backup2"
config_files="network
firewall"

if [ ! -d "$DIR_BACKUP" ]
then
    echo "Backup files..."
    mkdir -p $DIR_BACKUP
    for file in $config_files
    do
        cp -f "$DIR/$file" "$DIR_BACKUP/$file"  
    done
fi

#запрос конфигурации WARP
result=$(curl 'https://warp.llimonix.pw/api/warp' \
  -H 'Accept: */*' \
  -H 'Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://warp.llimonix.pw' \
  -H 'Referer: https://warp.llimonix.pw/' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36' \
  -H 'sec-ch-ua: "Not(A:Brand";v="99", "Google Chrome";v="133", "Chromium";v="133")' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  --data-raw '{"selectedServices":[],"siteMode":"all","deviceType":"computer"}')


#парсим результат запроса конфигурации WARP
content=$(echo $result | jq '.content')
configBase64=$(echo $content | jq -r '.configBase64')
#echo "$result"
warp_config=$(echo "$configBase64" | base64 -d)
#echo "$warp_config"
while IFS=' = ' read -r line; do
    if echo "$line" | grep -q "="; then
        # Разделяем строку по первому вхождению "="
        key=$(echo "$line" | cut -d'=' -f1 | xargs)  # Убираем пробелы
        value=$(echo "$line" | cut -d'=' -f2- | xargs)  # Убираем пробелы
        eval "$key=\"$value\""
	fi
done < <(echo "$warp_config")

#вытаскиваем нужные нам данные из распарсинного ответа
Address=$(echo "$Address" | cut -d',' -f1)
DNS=$(echo "$DNS" | cut -d',' -f1)
AllowedIPs=$(echo "$AllowedIPs" | cut -d',' -f1)
EndpointIP=$(echo "$Endpoint" | cut -d':' -f1)
EndpointPort=$(echo "$Endpoint" | cut -d':' -f2)

printf "\033[32;1mCreate and configure tunnel AmneziaWG WARP...\033[0m\n"

#задаём имя интерфейса
INTERFACE_NAME="awg10"
CONFIG_NAME="amneziawg_awg10"
PROTO="amneziawg"
ZONE_NAME="awg"

uci set network.${INTERFACE_NAME}=interface
uci set network.${INTERFACE_NAME}.proto=$PROTO
if ! uci show network | grep -q ${CONFIG_NAME}; then
	uci add network ${CONFIG_NAME}
fi
uci set network.${INTERFACE_NAME}.private_key=$PrivateKey
uci add_list network.${INTERFACE_NAME}.addresses=$Address
uci set network.${INTERFACE_NAME}.mtu=$MTU
uci set network.${INTERFACE_NAME}.awg_jc=$Jc
uci set network.${INTERFACE_NAME}.awg_jmin=$Jmin
uci set network.${INTERFACE_NAME}.awg_jmax=$Jmax
uci set network.${INTERFACE_NAME}.awg_s1=$S1
uci set network.${INTERFACE_NAME}.awg_s2=$S2
uci set network.${INTERFACE_NAME}.awg_h1=$H1
uci set network.${INTERFACE_NAME}.awg_h2=$H2
uci set network.${INTERFACE_NAME}.awg_h3=$H3
uci set network.${INTERFACE_NAME}.awg_h4=$H4
uci set network.@${CONFIG_NAME}[-1].description="${INTERFACE_NAME}_peer"
uci set network.@${CONFIG_NAME}[-1].public_key=$PublicKey
uci set network.@${CONFIG_NAME}[-1].endpoint_host=$EndpointIP
uci set network.@${CONFIG_NAME}[-1].endpoint_port=$EndpointPort
uci set network.@${CONFIG_NAME}[-1].persistent_keepalive='25'
uci set network.@${CONFIG_NAME}[-1].allowed_ips='0.0.0.0/0'
uci set network.@${CONFIG_NAME}[-1].route_allowed_ips='0'
uci commit network

if ! uci show firewall | grep -q "@zone.*name='${ZONE_NAME}'"; then
	printf "\033[32;1mZone Create\033[0m\n"
	uci add firewall zone
	uci set firewall.@zone[-1].name=$ZONE_NAME
	uci set firewall.@zone[-1].network=$INTERFACE_NAME
	uci set firewall.@zone[-1].forward='REJECT'
	uci set firewall.@zone[-1].output='ACCEPT'
	uci set firewall.@zone[-1].input='REJECT'
	uci set firewall.@zone[-1].masq='1'
	uci set firewall.@zone[-1].mtu_fix='1'
	uci set firewall.@zone[-1].family='ipv4'
	uci commit firewall
fi

if ! uci show firewall | grep -q "@forwarding.*name='${ZONE_NAME}'"; then
	printf "\033[32;1mConfigured forwarding\033[0m\n"
	uci add firewall forwarding
	uci set firewall.@forwarding[-1]=forwarding
	uci set firewall.@forwarding[-1].name="${ZONE_NAME}"
	uci set firewall.@forwarding[-1].dest=${ZONE_NAME}
	uci set firewall.@forwarding[-1].src='lan'
	uci set firewall.@forwarding[-1].family='ipv4'
	uci commit firewall
fi

# Получаем список всех зон
ZONES=$(uci show firewall | grep "zone$" | cut -d'=' -f1)
#echo $ZONES
# Циклически проходим по всем зонам
for zone in $ZONES; do
  # Получаем имя зоны
  CURR_ZONE_NAME=$(uci get $zone.name)
  #echo $CURR_ZONE_NAME
  # Проверяем, является ли это зона с именем "$ZONE_NAME"
  if [ "$CURR_ZONE_NAME" = "$ZONE_NAME" ]; then
    # Проверяем, существует ли интерфейс в зоне
    if ! uci get $zone.network | grep -q "$INTERFACE_NAME"; then
      # Добавляем интерфейс в зону
      uci add_list $zone.network="$INTERFACE_NAME"
      uci commit firewall
      #echo "Интерфейс '$INTERFACE_NAME' добавлен в зону '$ZONE_NAME'"
    fi
  fi
done

path_podkop_config="/etc/config/podkop"
path_podkop_config_backup="/root/podkop"
URL="https://raw.githubusercontent.com/routerich/RouterichAX3000_configs/refs/heads/main"

if [ -f "/etc/init.d/podkop" ]; then
	printf "Podkop installed. Reconfigured on AWG WARP? (y/n): \n"
	is_reconfig_podkop="y"
	read is_reconfig_podkop
	if [ "$is_reconfig_podkop" = "y" ] || [ "$is_reconfig_podkop" = "Y" ]; then
		cp -f "$path_podkop_config" "$path_podkop_config_backup"
		wget -O "$path_podkop_config" "$URL/config_files/podkop" 
		echo "Backup of your config in path '$path_podkop_config_backup'"
		echo "Podkop reconfigured..."
	fi
else
	printf "\033[32;1mInstall and configure PODKOP (a tool for point routing of traffic)?? (y/n): \033[0m\n"
	is_install_podkop="y"
	read is_install_podkop

	if [ "$is_install_podkop" = "y" ] || [ "$is_install_podkop" = "Y" ]; then
		DOWNLOAD_DIR="/tmp/podkop"
		mkdir -p "$DOWNLOAD_DIR"
		podkop_files="podkop_0.2.5-1_all.ipk
			luci-app-podkop_0.2.5_all.ipk
			luci-i18n-podkop-ru_0.2.5.ipk"
		for file in $podkop_files
		do
			echo "Download $file..."
			wget -q -O "$DOWNLOAD_DIR/$file" "$URL/podkop_packets/$file"
		done
		opkg install $DOWNLOAD_DIR/podkop*.ipk
		opkg install $DOWNLOAD_DIR/luci-app-podkop*.ipk
		opkg install $DOWNLOAD_DIR/luci-i18n-podkop-ru*.ipk
		rm -f $DOWNLOAD_DIR/podkop*.ipk $DOWNLOAD_DIR/luci-app-podkop*.ipk $DOWNLOAD_DIR/luci-i18n-podkop-ru*.ipk
		wget -O "$path_podkop_config" "$URL/config_files/podkop" 
		echo "Podkop installed.."
	fi
fi

printf  "\033[32;1mStop and disabled service 'youtubeUnblock' and 'ruantiblock'...\033[0m\n"
manage_package "youtubeUnblock" "disable" "stop"
manage_package "ruantiblock" "disable" "stop"

str=$(grep -i "0 4 \* \* \* wget -O - $URL/configure_zaprets.sh | sh" /etc/crontabs/root)
if [ ! -z "$str" ]
then
	grep -v "0 4 \* \* \* wget -O - $URL/configure_zaprets.sh | sh" /etc/crontabs/root > /etc/crontabs/temp
	cp -f "/etc/crontabs/temp" "/etc/crontabs/root"
	rm -f "/etc/crontabs/temp"
fi

printf  "\033[32;1mRestart firewall and network...\033[0m\n"
service firewall restart
#service network restart

# Отключаем интерфейс
ifdown $INTERFACE_NAME
# Ждем несколько секунд (по желанию)
sleep 2
# Включаем интерфейс
ifup $INTERFACE_NAME

printf  "\033[32;1mService Podkop restart...\033[0m\n"
service podkop restart

printf  "\033[32;1mConfigured completed...\033[0m\n"
