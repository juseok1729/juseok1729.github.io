---
title: "[AWS] EC2 볼륨 증설하기"
date: 2024-10-12T10:54:52+09:00
draft: false
categories: [guide]
tags: [AWS, EC2, EBS, upscale]
description: ""
slug: ""
series: []
series_order: 1
authors:
  - P373R
---

## 기존 볼륨(스토리지) 증설하기
### 1. 파일 시스템 현재 용량 확인
`/` 경로의 용량이 83%로 조금 부족해보인다. 이부분을 증설하겠다.  
```bash
df -hT

Filesystem      Type      Size  Used Avail Use% Mounted on
/dev/root       ext4       29G   24G  5.1G  83% /
...
```

### 2. 블럭장치 목록 확인
증설을 원하는 `/` 경로는 `nvme0n1` 디스크의 첫번째 파티션에 마운트 되어있는것을 확인할 수 있다.  
```bash
lsblk

NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0          7:0    0  24.4M  1 loop /snap/amazon-ssm-agent/6312
loop1          7:1    0  55.7M  1 loop /snap/core18/2745
...
nvme0n1      259:0    0    64G  0 disk
├─nvme0n1p1  259:1    0  29.9G  0 part /
├─nvme0n1p14 259:2    0     4M  0 part
└─nvme0n1p15 259:3    0   106M  0 part /boot/efi
```

### 3. 파티션 확장
아래 커맨드로 `/` 경로의 파티션(`nvme0n1p1`)을 확장한다.  
`nvme0n1` 의 첫번째(`1`) 파티션을 확장하는 커맨드이다.  
```bash
growpart /dev/nvme0n1 1
```

### 4. 확장된 파티션 용량 확인
***29.9G*** → ***63.9G*** 로 확장된것을 확인할 수 있다.  
```bash
lsblk

NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0          7:0    0  24.4M  1 loop /snap/amazon-ssm-agent/6312
loop1          7:1    0  55.7M  1 loop /snap/core18/2745
...
nvme0n1      259:0    0    64G  0 disk
├─nvme0n1p1  259:1    0  63.9G  0 part /
├─nvme0n1p14 259:2    0     4M  0 part
└─nvme0n1p15 259:3    0   106M  0 part /boot/efi
```

### 5. 파일 시스템 확장
Linux 시스템은 파일 시스템이 파티션 크기를 자동으로 인식하지 못한다.  
아래 커맨드로 `nvme0n1p1`파티션의 파일 시스템이 확장된 현재의 파티션 크기에 맞게 확장된다.    
```bash
resize2fs /dev/nvme0n1p1

resize2fs 1.45.5 (07-Jan-2020)
Filesystem at /dev/nvme0n1p1 is mounted on /; on-line resizing required
old_desc_blocks = 4, new_desc_blocks = 8
The filesystem on /dev/nvme0n1p1 is now 16748795 (4k) blocks long.
```

### 6. 파일 시스템의 확장된 용량 확량
증설이 되었는지 확인한다.  
29G → 62G 로 늘어난것을 확인할 수 있다.  
```bash
df -h

Filesystem       Size  Used Avail Use% Mounted on
/dev/root         62G   24G   39G  39% /
...
```

## 신규 볼륨(스토리지) 추가하기
### 1. 블럭장치 목록 확인
맨아래 `nvme1n1` 디스크가 마운트되어있지 않은것을 확인할 수 있다.  
```bash
lsblk

NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
...
nvme0n1      259:0    0    64G  0 disk
├─nvme0n1p1  259:1    0  29.9G  0 part /
├─nvme0n1p14 259:2    0     4M  0 part
└─nvme0n1p15 259:3    0   106M  0 part /boot/efi
nvme1n1      259:4    0 116.4G  0 disk
```

### 2. 파일 시스템 유형 확인
해당 인스턴스의 파일시스템 유형은 `ext4` 로 확인된다.  
```bash
df -hT

Filesystem      Type      Size  Used Avail Use% Mounted on
/dev/root       ext4       29G   24G  5.1G  83% /
...
```

### 3. 포맷
마운트 할 `/nvme1n1` 디스크를 기존 디스크와 동일한 포맷(`ext4`)로 포맷한다.  
```bash
mkfs -t ext4 /dev/nvme1n1

mke2fs 1.45.5 (07-Jan-2020)
Discarding device blocks: done
Creating filesystem with 30517578 4k blocks and 7634944 inodes
Filesystem UUID: b37dde52-57c7-4422-879c-576dabe7f60c
Superblock backups stored on blocks:
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
	4096000, 7962624, 11239424, 20480000, 23887872

Allocating group tables: done
Writing inode tables: done
Creating journal (131072 blocks): done
Writing superblocks and filesystem accounting information: done
```

### 4. 마운트
아래는 일시적이고 즉각적인 마운트 방법이다. 인스턴스가 재시작되면 마운트가 해제된다.  
```bash
# 마운트 할 디렉토리 생성
mkdir /Projects

# 마운트
mount /dev/nvme1n1 /Projects
```

아래는 인스턴스가 재시작되어도 마운트가 유지되는 방법이다.  
```bash
sudo vi /etc/fstab

# 디바이스 이름    마운트위치     파일시스템   옵션
/dev/nvme1n1    /Projects    ext4    defaults,nofail    0 0
```