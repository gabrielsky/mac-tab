#!/bin/bash
# 一次性创建代码签名用的自签名证书「MacTab Local」（10 年有效），导入登录钥匙串。
# 用固定证书签名，重新编译后辅助功能授权不会丢。证书不用设为信任，也不用输密码
# 用法：scripts/setup-cert.sh
set -euo pipefail

IDENTITY="MacTab Local"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  echo "钥匙串里已经有证书「$IDENTITY」，不用再创建"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.conf" <<CONF
[req]
distinguished_name = dn
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF

# 用系统自带的 LibreSSL：它导出的 p12 能直接导入钥匙串，OpenSSL 3 默认的加密算法导入会失败
SSL=/usr/bin/openssl
"$SSL" req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.conf" -extensions ext \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS="$("$SSL" rand -hex 16)" # 只用来包装临时的 p12 文件
"$SSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$IDENTITY" \
  -passout "pass:$PASS" -out "$TMP/cert.p12"
# -T：允许 codesign 使用私钥，签名时不弹窗
security import "$TMP/cert.p12" -P "$PASS" -T /usr/bin/codesign >/dev/null
echo "已创建证书「$IDENTITY」，有效期 10 年"
