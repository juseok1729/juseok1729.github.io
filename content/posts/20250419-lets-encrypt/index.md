---
title: "SSL Without Nginx: Let's Encrypt for FastAPI"
date: 2025-04-19T20:57:51+09:00
draft: false
categories: [guide]
tags: [ssl, https, devops, lets encrypt]
description: ""
slug: ""
series: [ssl]
series_order: 1
authors:
  - P373R
---

WAS(nginx, apache)를 거치지 않는 인증 방식이 업무를 하다 보면 필요할때가 있다. SPA나 모바일 앱을 개발할 때 JWT 토큰을 쓰게 되거나, 마이크로서비스끼리 직접 통신이 필요할 때, 또는 IoT 기기처럼 가벼운 시스템을 다룰 때 말이다. 이런 상황들에서 무거운 WAS 대신 직접 인증 방식이 더 효율적인 해결책이 되기도 한다.

이 글에서는 Let's Encrypt 인증서를 nginx나 apache 없이 발급하는 방법들을 아래 정보 기준으로 설명하겠다.  
- 도메인 `test.example.com` (도메인은 구매해야한다.)
- 이메일 `test@example.com`

## 1. 인증서 발급
### 1-1. certbot standalone 방식
이 방법은 certbot이 자체적으로 임시 웹서버를 실행하여 인증한다.  

```bash
# certbot 설치 (Ubuntu/Debian 기준)
sudo apt-get update
sudo apt-get install certbot

# standalone 모드로 인증서 발급
sudo certbot certonly --standalone -d test.example.com --email test@example.com --agree-tos --no-eff-email
```

### 1-2. DNS 인증 방식
DNS 공급자의 API를 통해 TXT 레코드를 자동으로 설정하는 방법이다. DNS 제공업체에 따라 플러그인이 달라진다. 
예를 들어 `Cloudflare`를 사용한다면,  
```bash
# Cloudflare 플러그인 설치
sudo apt-get install certbot python3-certbot-dns-cloudflare

# Cloudflare API 토큰 설정 파일 생성
sudo mkdir -p /etc/letsencrypt/secrets/
sudo vi /etc/letsencrypt/secrets/cloudflare.ini

# 파일에 다음 내용 추가:
# dns_cloudflare_email = test@example.com
# dns_cloudflare_api_key = YOUR_API_KEY

# 파일 권한 설정
sudo chmod 600 /etc/letsencrypt/secrets/cloudflare.ini

# 인증서 발급
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini \
  -d test.example.com \
  --email test@example.com \
  --agree-tos --no-eff-email
```

### 1-3. 수동 DNS 인증 방식
DNS 플러그인 없이 수동으로 TXT 레코드를 설정하는 방법이다.  
```bash
sudo certbot certonly --manual --preferred-challenges dns \
  -d test.example.com \
  --email test@example.com \
  --agree-tos --no-eff-email
```
이 명령어를 실행하면 화면에 추가해야 할 TXT 레코드 정보가 표시되는데 DNS 관리 패널에서 이 레코드를 추가한 후 진행하면 된다.  

### 1-4. webroot 방식 (기존 웹서버 있을 경우)
이미 다른 웹서버가 실행 중이라면 webroot 방식을 사용할 수 있다.  
```bash
# 웹서버 루트 디렉토리를 가정 (예: /var/www/html)
sudo certbot certonly --webroot -w /var/www/html \
  -d test.example.com \
  --email test@example.com \
  --agree-tos --no-eff-email
```

### 1-5. acme.sh 사용 (certbot 대체)
certbot 외에 더 가벼운 acme.sh 클라이언트를 사용하는 방법
```bash
# acme.sh 설치
curl https://get.acme.sh | sh

# DNS API 방식 (Cloudflare 예시)
export CF_Email="test@example.com"
export CF_Key="YOUR_API_KEY"
~/.acme.sh/acme.sh --issue --dns dns_cf -d test.example.com

# 또는 standalone 방식
~/.acme.sh/acme.sh --issue --standalone -d test.example.com
```
발급된 인증서는 각 방식에 따라 다른 위치에 저장되며, certbot의 경우 보통 `/etc/letsencrypt/live/test.example.com/` 디렉토리에 저장된다. 이 인증서를 애플리케이션에서 직접 사용하면 된다.  

## 2. 방식별 인증서 파일 위치
- certbot : `/etc/letsencrypt/live/test.example.com/`
- acme.sh : `~/.acme.sh/test.example.com/`

## 3. FastAPI 애플리케이션 SSL 적용

**필요한 파일**
- `fullchain.pem` (인증서 체인)
- `privkey.pem` (개인 키)
  
```python
import uvicorn
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=443, 
        ssl_keyfile="/etc/letsencrypt/live/test.example.com/privkey.pem",
        ssl_certfile="/etc/letsencrypt/live/test.example.com/fullchain.pem"
    )
```
   
**권한 문제 해결**  
Let's Encrypt 인증서는 보통 root 권한으로 관리되기 때문에 일반 사용자 권한으로 실행되는 FastAPI 앱에서 인증서를 읽을 때 권한 문제가 발생할 수 있다.  
이를 해결하는 방법  

```bash
# 인증서 파일 복사
sudo mkdir -p $HOME/certs
sudo cp /etc/letsencrypt/live/test.example.com/fullchain.pem $HOME/certs/
sudo cp /etc/letsencrypt/live/test.example.com/privkey.pem $HOME/certs/

# 권한 변경
sudo chown $USER:$USER $HOME/certs/fullchain.pem
sudo chown $USER:$USER $HOME/certs/privkey.pem
sudo chmod 600 $HOME/certs/privkey.pem
```
  
그리고 FastAPI 코드에서 복사한 위치를 사용한다.  
```python
uvicorn.run(
    "main:app", 
    host="0.0.0.0", 
    port=443, 
    ssl_keyfile="/path/to/your/home/certs/privkey.pem",
    ssl_certfile="/path/to/your/home/certs/fullchain.pem"
)
```

**systemd 서비스로 실행 (권장)**  
애플리케이션을 systemd 서비스로 등록하면 권한 문제를 더 체계적으로 관리할 수 있다.  
```bash
# /etc/systemd/system/fastapi-app.service 파일 생성
sudo vi /etc/systemd/system/fastapi-app.service
```

다음 내용을 입력한다.  
```sh
[Unit]
Description=FastAPI Application
After=network.target

[Service]
User=user
Group=user
WorkingDirectory=/path/to/your/app
ExecStart=/path/to/your/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 443 --ssl-keyfile /etc/letsencrypt/live/test.example.com/privkey.pem --ssl-certfile /etc/letsencrypt/live/test.example.com/fullchain.pem

[Install]
WantedBy=multi-user.target
```

서비스를 활성화한다.  
```sh
sudo systemctl daemon-reload
sudo systemctl enable fastapi-app
sudo systemctl start fastapi-app
```

## 4. 인증서 자동 갱신  
### 4-1. 애플리케이션과 상관없이
#### 1. DNS 인증 방식
가장 간단한 방법은 HTTP 챌린지 대신 DNS 챌린지를 사용하는 것이다. DNS 챌린지는 80/443 포트에 접근할 필요가 없어 애플리케이션을 중단하지 않아도 된다.  
  
크론탭을 열어 다음 명령을 추가한다.  
```bash
sudo crontab -e

0 3 1,15 * * certbot renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini --quiet
```

certbot은 기본적으로 80/443 포트를 사용하지만, 다른 포트를 사용하도록 설정할 수도 있다.  
이 방법은 기존 80/443 포트를 사용하는 FastAPI 애플리케이션에 영향을 주지 않는다.  
```bash
sudo crontab -e

0 3 1,15 * * certbot renew --standalone --http-01-port 8080 --https-01-port 8443 --quiet
```

#### 2. acme.sh 방식
```bash
# API 환경변수 설정 후 DNS 방식으로 갱신
export CF_Email="test@example.com"
export CF_Key="YOUR_API_KEY"
~/.acme.sh/acme.sh --issue --dns dns_cf -d test.example.com --renew
```

#### 3. webroot 방식
FastAPI 애플리케이션이 특정 디렉토리에 파일을 제공할 수 있다면, webroot 방식을 사용할 수 있다.  
먼저, FastAPI에 정적 파일 서빙 경로를 추가한다.  
```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# 정적 파일 경로 마운트 (Let's Encrypt 인증용)
app.mount("/.well-known", StaticFiles(directory="/path/to/webroot/.well-known"), name="well-known")
```

인증서 갱신 설정을 하기위해 크론탭을 열어 명령어를 추가한다.  
```bash
sudo crontab -e

0 3 1,15 * * certbot renew --webroot -w /path/to/webroot --quiet
```

인증서가 갱신된 후 필요한 복사 작업과 권한 설정을 자동화한다.  
```bash
sudo crontab -e

0 3 1,15 * * certbot renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/secrets/cloudflare.ini --quiet && cp /etc/letsencrypt/live/test.example.com/fullchain.pem /home/user/certs/ && cp /etc/letsencrypt/live/test.example.com/privkey.pem /home/user/certs/ && chown user:user /home/user/certs/*.pem && chmod 600 /home/user/certs/privkey.pem
```

인증서를 발급받은 후, 다음과 같이 파일 시스템 권한을 통해 애플리케이션에 공유할 수 있다.  
```bash
sudo groupadd cert-users
sudo usermod -a -G cert-users www-data  # Let's Encrypt 사용자
sudo usermod -a -G cert-users fastapi-user  # FastAPI 실행 사용자
```

인증서 권한을 수정한다.  
```bash
sudo mkdir -p /etc/ssl/shared
sudo cp /etc/letsencrypt/live/test.example.com/fullchain.pem /etc/ssl/shared/
sudo cp /etc/letsencrypt/live/test.example.com/privkey.pem /etc/ssl/shared/
sudo chown -R root:cert-users /etc/ssl/shared
sudo chmod 750 /etc/ssl/shared
sudo chmod 640 /etc/ssl/shared/*.pem
```

갱신된 후 필요한 복사 작업과 권한 설정을 자동화하는 쉘 스크립트를 작성한다.  
```bash
sudo vi /etc/letsencrypt/renewal-hooks/post/copy-certs.sh
```
```bash
#!/bin/bash
cp /etc/letsencrypt/live/test.example.com/fullchain.pem /etc/ssl/shared/
cp /etc/letsencrypt/live/test.example.com/privkey.pem /etc/ssl/shared/
chown -R root:cert-users /etc/ssl/shared
chmod 750 /etc/ssl/shared
chmod 640 /etc/ssl/shared/*.pem
```

작서한 쉘 스크립트에 실행 권한을 추가한다.  
```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/copy-certs.sh
```


### 4-2. 애플리케이션과 함께
#### 1. Cron을 사용한 자동 갱신
```bash
sudo crontab -e

0 3 1,15 * * certbot renew --standalone --pre-hook "systemctl stop fastapi-app" --post-hook "systemctl start fastapi-app" --quiet
```
위 명령어는,
- 갱신 전에 FastAPI 애플리케이션을 중지(--pre-hook)
- 인증서 갱신 실행
- 갱신 후 FastAPI 애플리케이션 다시 시작(--post-hook)

#### 2. systemd timer 사용
```bash
sudo vi /etc/systemd/system/certbot-renewal.service

[Unit]
Description=Certbot Renewal Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --standalone --pre-hook "systemctl stop fastapi-app" --post-hook "systemctl start fastapi-app" --quiet
```

```bash
sudo vi /etc/systemd/system/certbot-renewal.timer

[Unit]
Description=Timer for Certbot Renewal

[Timer]
OnCalendar=*-*-01,15 03:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable certbot-renewal.timer
sudo systemctl start certbot-renewal.timer
```

#### 3. acme.sh를 사용할 경우
acme.sh는 설치 시 자동으로 cron 작업을 추가한다.  
```bash
~/.acme.sh/acme.sh --install-cert -d test.example.com \
  --key-file /path/to/privkey.pem \
  --fullchain-file /path/to/fullchain.pem \
  --reloadcmd "systemctl restart fastapi-app"
```

이렇게 설정하면 인증서 갱신 시 자동으로 FastAPI 애플리케이션을 재시작한다.  

Let's Encrypt 인증서는 보통 90일마다 만료되므로, 60일 주기로 갱신하는 것이 안전하다. 위 방법들 중 어느 것을 사용하든 갱신 스크립트가 실패하지 않도록 주기적으로 테스트하는 것이 중요하다.  