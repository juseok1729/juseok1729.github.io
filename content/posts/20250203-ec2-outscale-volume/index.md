---
title: "[AWS] EC2 신규 EBS 스토리지 추가"
date: 2025-02-03T10:39:02+09:00
draft: false
categories: [guide]
tags: [AWS, EC2, EBS, out-scale]
description: ""
slug: ""
series: []
series_order: 1
authors:
  - P373R
---

## 1. 스토리지 추가
### 1-1. 블럭장치 목록 확인
맨 아래 `nvme1n1` 블럭이 마운트 되어있지 않은것을 확인할 수 있다.  

```bash
$ lsblk

NAME         MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
loop0          7:0    0  24.4M  1 loop /snap/amazon-ssm-agent/6312
loop1          7:1    0  55.7M  1 loop /snap/core18/2745
loop2          7:2    0  55.7M  1 loop /snap/core18/2785
loop3          7:3    0  63.5M  1 loop /snap/core20/1891
loop4          7:4    0  24.8M  1 loop /snap/amazon-ssm-agent/6563
loop5          7:5    0  63.5M  1 loop /snap/core20/1974
loop6          7:6    0  91.9M  1 loop /snap/lxd/24061
loop7          7:7    0  53.2M  1 loop /snap/snapd/19122
loop8          7:8    0  53.3M  1 loop /snap/snapd/19457
nvme0n1      259:0    0    64G  0 disk
├─nvme0n1p1  259:1    0  29.9G  0 part /
├─nvme0n1p14 259:2    0     4M  0 part
└─nvme0n1p15 259:3    0   106M  0 part /boot/efi
nvme1n1      259:4    0 116.4G  0 disk
```

### 1-2. 각 볼륨의 시스템 확인

루트 볼륨의 파일 시스템은 `ext4` 로 확인된다.

```bash
$ df -hT

Filesystem      Type      Size  Used Avail Use% Mounted on
/dev/root       ext4       29G   24G  5.1G  83% /
devtmpfs        devtmpfs  7.7G     0  7.7G   0% /dev
tmpfs           tmpfs     7.7G     0  7.7G   0% /dev/shm
tmpfs           tmpfs     1.6G  988K  1.6G   1% /run
tmpfs           tmpfs     5.0M     0  5.0M   0% /run/lock
tmpfs           tmpfs     7.7G     0  7.7G   0% /sys/fs/cgroup
/dev/loop0      squashfs   25M   25M     0 100% /snap/amazon-ssm-agent/6312
/dev/loop2      squashfs   56M   56M     0 100% /snap/core18/2785
/dev/loop1      squashfs   56M   56M     0 100% /snap/core18/2745
/dev/loop3      squashfs   64M   64M     0 100% /snap/core20/1891
/dev/nvme0n1p15 vfat      105M  6.1M   99M   6% /boot/efi
/dev/loop4      squashfs   25M   25M     0 100% /snap/amazon-ssm-agent/6563
/dev/loop7      squashfs   54M   54M     0 100% /snap/snapd/19122
/dev/loop5      squashfs   64M   64M     0 100% /snap/core20/1974
/dev/loop6      squashfs   92M   92M     0 100% /snap/lxd/24061
/dev/loop8      squashfs   54M   54M     0 100% /snap/snapd/19457
tmpfs           tmpfs     1.6G     0  1.6G   0% /run/user/1001
tmpfs           tmpfs     1.6G  4.0K  1.6G   1% /run/user/1000
```

### 1-3. 포맷

마운트 할 볼륨 또한 루트 볼륨과 같은 포맷인 `ext4` 로 포맷한다.

```bash
$ mkfs -t ext4 /dev/nvme1n1

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

### 1-4. 마운트

아래 방법으로 마운트하면 시스템 재시작 시 마운트가 풀린다.

```bash
# 마운트 할 디렉토리 생성
mkdir /Projects

# 마운트
mount /dev/nvme1n1 /Projects
```

### 1-5. 영구 마운트

`/etc/fstab` 에 아래와 같이 등록하면 시스템 재시작시에도 마운트가 풀리지 않는다.

```bash
...
# 디바이스 이름    마운트위치     파일시스템   옵션
/dev/nvme1n1    /Projects    ext4    defaults,nofail    0 0
```

## 2. 마운트 해제

```bash
$ sudo umount /Projects
```

## 3. 스토리지 제거
1. EC2 > EBS > Volumes 메뉴 선택하여 생성된 전체 Volume을 조회한다.  
2. 제거하려는 Volume을 체크한다.
3. 체크된 Volume 라인에 오른쪽 마우스를 클릭한 후에 **[Detach Volume]** 을 클릭한다.
4. Detach 된 Volume 의 상태가 in-use -> available로 바뀐다.  
5. Volume을 완전히 삭제하려면, 삭제하려는 Volume을 우클릭해 **[Delete Volume]** 을 클릭해 완전히 삭제할 수 있다.