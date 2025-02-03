---
title: "[AWS] EC2 에 EFS 마운트하기"
date: 2025-02-03T11:22:09+09:00
draft: false
categories: [guide]
tags: [AWS, EC2, EFS]
description: ""
slug: ""
series: []
series_order: 1
authors:
  - P373R
---

## 1. EFS 마운트 하기

EC2 인스턴스를 생성할때 볼륨 옵션에서 EFS를 추가하지 않고, EC2 생성한 이후에 추가적으로 마운트하기 위해서는 `efs-utils` 패키지가 필요하다. 아래 명령어로 설치가 가능하다.  

```bash
sudo apt-get -y install ./build/amazon-efs-utils*deb./build-deb.sh
cd /path/to/efs-utils
git clone https://github.com/aws/efs-utils
sudo apt-get -y install git binutils
sudo apt-get update
```

설치가 되었다면, aws 콘솔에서 efs 콘솔을 연다.  
efs 콘솔에서 **파일 시스템** 을 선택하고, 마운트할 파일 시스템을 선택하고 연결을 누르면 연결에 필요한 아래와 같은 명령어를 확인가능하다.  

아래 명령어를 연결하고자 하는 ec2에 접속해서 입력한다.  

```bash
sudo mount -t efs -o tls fs-01234567890ec1234:/ efs
```

## 2. EFS 마운트 해제하기

```bash
sudo umount -l /mnt/efs
```