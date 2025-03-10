---
title: "[CKA] Pod"
date: 2025-03-10T13:01:48+09:00
draft: true
categories: [study]
tags: [k8s, command]
description: ""
slug: ""
series: ["cka"]
series_order: 2
authors:
  - P373R
---

## 1. Pod 소개
플랫폼별 실행 최소 단위
- VM : Instance
- Docker : Container
- **Kubernetes** : **Pod**

Pod는 일반적으로 1개의 컨테이너, 많게는 3개, 그 이상의 컨테이너를 가질 수 있는데 실질적으로 3개 이상 넘어가는 경우는 거의 없다.  
Pod 내에 실행되는 컨테이너들은 반드시 동일 노드에 할당되고 동일한 생명주기를 갖는다.  
Pod 삭제 시, Pod 내의 모든 컨테이너가 함께 삭제된다.  
Pod 내의 컨테이너들은 같은 IP를 공유하고 포트로 구분된다. 때문에 한 Pod내의 컨테이너끼리 `localhost`로 통신이 가능하다.  
또한 볼륨도 공유가능해서 컨테이너간 서로 파일을 주고 받을 수 있다.  

쿠버네티스의 모든 리소스는 YAML 포맷의 매니페스트(템플릿 파일)를 사용하는데, `--dry-run`과 `-o yaml`을 조합하면 Pod를 실제로 생성하지 않고 템플릿파일(매니페스트)를 생성할 수 있다.  
```bash
k run mynginx --image nginx --dry-run=client -o yaml > mynginx.yaml
```
![dry-run](./assets/dry-run.png)
파일을 확인해보면 몇가지 property 가 있는데,
- `apiVersion`: 리소스마다 각기 다른 버전이 정의되어있다. 전 단원에서 학습했던 아래 명령어로 확인 가능하다.  
  ```bash
  k api-resources
  ```
- `kind`: 리소스의 타입이다. 이번엔 Pod라는 리소스에 대해 살펴볼 예정이다.  
- `metadata`: 위에서 정의했던 리소스의 메타데이터이다.  
  추후, 복제 및 배포 시 선택하는 구분자의 역할을 한다.  
- `spec`: 리소스의 상세 스펙이다.  
  - `containers`: 1개 이상의 컨테이너를 정의한다.
    - `name`: 컨테이너 이름
    - `image`: 이미지 이름

Pod를 생성하면 아래 순서로 실행된다.  
<div style="background-color:white; padding: 5px">
{{< mermaid >}}
flowchart LR
  u["User"]
  k["Kubectl"]
  a["API Server"]
  kl["Kubelet"]
  p["Pod"]
  c["Containers"]
  
  subgraph Client
  u-->k
  end
  
  subgraph Master
  k-->a
  end

  subgraph Node
    kl
    subgraph Pod
    p-->c
    end
    kl-->Pod
  end
  Master-->Node
{{< /mermaid >}}
</div>

## 2. 레이블링 시스템
```bash
# 레이블 부여 : k label po <NAME> <KEY>=<VALUE>
k label po mynginx iwanna=gohome
```
![label-create](./assets/create-label.png)

```bash
# 기본 레이블 : k run <NAME> ... 할때 NAME 이 run=<NAME> 으로 기본 설정된다.
k get po mynginx -L run
```
![default-label](./assets/default-label.png)

```bash
# 레이블을 이용한 조건 필터링
# key가 run인 Pod 출력
k get po -L run

# key가 run이고 value가 mynginx인 Pod 출력
k get po -L run=mynginx
```
![label-filter](./assets/filter-label.png)

```bash
# 레이블 조회 : k get no --show-labels
k get no --show-labels
```
![label-show](./assets/show-label.png)

### nodeSelector를 이용한 노드 선택
레이블링 시스템을 이용해 특정 노드에 파드를 할당되도록 스케줄링 할 수 있다.  
레이블을 추가하는건 위에서 해봤다. 편의상 `hostname=juseok` 인 노드에 할당해보겠다.  
```bash
# 노드 선택(nodeSelector)
cat << EOF > node-selector.yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-selector
spec:
  containers:
  - name: nginx
    image: nginx
  nodeSelector:
    kubernetes.io/hostname: juseok
EOF

k apply -f node-selector.yaml
```
![node-selector](./assets/node-selector.png)

레이블 수정은 템플릿 파일을 직접 수정하는 방법과 아래 명령어로 하는 방법이 있다.  
```bash
# 레이블 수정 : k label po <NAME> <KEY>=<NEW_VALUE> --overwrite
```
여기서는 파일을 직접 수정하겠다.  
![label-edit2](./assets/edit-label2.png)

에러가 발생했다. `jihoon` 이라는 레이블을 갖고있는 노드가 없기 때문이다.  
이 처럼 nodeSelector 로 파드가 실행될 노드를 직접 선택할 수 있다는 것을 알 수 있다.  
![invalid-label](./assets/invalid-label.png)

```bash
# 레이블 삭제 : k label po <NAME> <KEY>-
```
![label-delete](./assets/delete-label.png)

## 3. 실행 명령 및 파라미터 지정
Pod 생성 시, 커맨드와 파라미터를 전달할 수 있다.
|      설명                |    docker               |    kubernetes     |
|-------------------------|-------------------------|-------------------|
| 실행 명령                 | **ENTRYPOINT**          | `command`         |
| 실행 명령의 입력 파라미터     | **CMD**                 | `args`            |
| 재시작 정책                | **restart**             | `restartPolicy`<br>`['Always', 'Never', 'OnFailure']` |
- **Always** : Pod 정상 종료(exit 0)시 항상 재시작
- **Never** : 절대 재시작 X
- **OnFailure** : Pod 비정상 종료(exit != 0)시 재시작

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cmd
spec:
  restartPolicy: OnFailure
  containers:
  - name: nginx
    image: nginx
    command: ["/bin/echo"]
    args: ["hello"]
```
![pod-cmd](./assets/pod-cmd.png)
{{< alert icon="circle-info" cardColor="#F5F6CE" iconColor="#1d3557" textColor="#000000" >}}
cmd 파드 로그가 restart 되지 않고 한번만 찍히는 이유는, echo는 원래 한번 실행되고 종료되는 명령어이기 때문에 실패가 아닌 정상종료로 간주되기 때문이다.  
{{< /alert >}}  

## 4. 환경변수 설정
```bash
cat << EOF > env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: env
spec:
  containers:
  - name: nginx
    image: nginx
    env:
    - name: hello
      value: "world!"
EOF
```
- `env:name` : 환경 변수의 key
- `env:value` : 환경 변수의 value

![env](./assets/env.png)

## 5. 볼륨 연결
Pod 내부 스토리지는 휘발성이다. Pod가 사라지면 함께 사라진다.  
Pod 생명주기와 상관없이 지속되게 하려면 볼륨을 따로 연결해야한다.  
쿠버네티스에는 여러가지 볼륨타입이 존재한다.  
|    볼륨 타입                  |    설명                                               |
|-----------------------------|------------------------------------------------------|
| **emptyDir**                | 주로 캐시나 임시 파일 저장용                                |
| **hostPath**                | 파드가 실행 중인 노드의 파일 시스템                          |
| configMap                   | 애플리케이션 설정과 같은 텍스트 데이터를 저장용                  |
| secret                      | 비밀번호, API 키 등 민감한 데이터를 암호화된 상태로 저장용        |
| persistentVolumeClaim (PVC) | 영속성 데이터 저장소, 외부 스토리지 연결용                     |
| nfs (Network File System)   | 네트워크로 접근가능한 외부 저장소, 여러 파드가 동일한 NFS 공유 가능 |

### hostPath
hostPath는 docker의 `-v` 옵션과 유사하게 호스트 파일시스템에 Pod가 데이터를 저장할 수 있게 해준다.  
```bash
cat << EOF > volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: /container-volume
      name: my-volume
  volumes:
  - name: my-volume
    hostPath:
      path: /home
EOF
```
- volumeMounts: 컨테이너 내부 볼륨
  - mountPath: 컨테이너 내부 path
  - name: volumeMounts와 volumes를 연결하는 식별자
- volumes: Pod에서 사용할 volume
  - hostPath: 호스트 서버의 path
  - name: volumeMounts와 volumes를 연결하는 식별자

![volume](./assets/volume.png)

### emptyDir
emptyDir은 보통 컨테이너끼리 파일 데이터를 주고받을 때 사용한다.  
Pod와 운명공동체이다. Pod와 함께 제거된다.  
```bash
cat << EOF > volume-empty.yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-empty
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: /container-volume
      name: my-volume
  volumes:
  - name: my-volume
    emptyDir: {}
EOF
```

## 6. 리소스 관리


## 7. 상태 확인


## 8. 다중 컨테이너 실행


## 9. 초기화 컨테이너


## 10. Config 설정


## 11. Secret 관리


## 12. 메타데이터 전달