---
title: "Probe"
date: 2025-01-21T14:08:42+09:00
draft: false
categories: [study]
tags: [k8s, object]
description: ""
slug: ""
series: [kubernetes]
series_order: 7
authors:
  - P373R
---

쿠버네티스는 **Probe** 라는 오브젝트로 상태 모니터링 기능을 제공하고 있다.  
템플릿(`.yml`)으로 바라는 상태를 쿠버네티스 클러스터에 반영하면 파드가 생성되는데,  
이때 파드의 Status는 **Pending** -> **Running** 순서로 상태가 변한다.  
**Running** 상태가 된다음 파드의 **Conditions**가 `Ready=True` 일때 외부에서 접근할 수 있는 상태이다.  
**Pending** 단계에서는 보통 애플리케이션이나 서버의 초기화가 이루어지는데(~~자바 초기화.. 읍읍..~~) 이때 접근을 시도하면 에러페이지가 출력된다. 
그래서 위와 같이 초기화가 완료되기전에 서비스되지 않도록 쿠버네티스는 애플리케이션이 완전히 준비가 된 상태에서만 트래픽을 받을 수 있게 설정이 가능한것이다.  

## 1. LivenessProbe

livenessProbe 는 컨테이너에 이상이 있는지 없는지 내부적으로 접근해서 상태를 확인하여 문제가 발견되면 파드를 재시작하고, 문제가 없으면 파드의 상태를 준비로 변경하고 외부에서 접근할 수 있도록 트래픽을 오픈한다.  
> 문제가 생기면 컨테이너를 재시작한다.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-lp
  labels:
    app: test
spec:
  containers:
    - name: test
      image: test
      livenessProbe:
        httpGet:
          path: /not/exist
          port: 8080
        initialDelaySeconds: 5      # 생성된뒤 처음 5초 후에 http 요청을 하겠다.
        timeoutSeconds: 2           # 타임아웃 최대 2초
        periodSeconds: 5            # 5초마다 상태체크
        failureThreshold: 1         # 상태체크 횟수 1회
```
위 설정 파일의 **livenessProbe** 는 선언한 path(`/not/exist`)에 내부적으로 **HTTP(GET)** 요청을 보내서 응답이 있으면 파드의 상태를 준비상태로 변경하고 외부에서 접근할 수 있도록 트래픽을 연다. 응답이 없으면 파드를 재시작한다음 똑같이 선언한 path에 http GET 요청을 보내서 문제가 없으면 파드의 상태를 준비로 변경하고 서비스 트래픽을 열어 외부에서 접근할 수 있도록 세팅한다.  

## 2. ReadinessProbe

readinessProbe 는 정상적인 Pod 에만 트래픽을 보내고 싶을때 사용한다.  
예를들어 Pod 10개를 생성했다고 가정하자. 준비상태 Pod 5개, 생성상태 Pod 5개라면, 준비상태 Pod 5개에만 트래픽을 라우팅하게 된다.  
> 문제가 생기면 외부 트래픽을 차단한다.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-rp
  labels:
    app: test
spec:
  containers:
    - name: test
      image: test
      readinessProbe:           # 차이점은 이 부분만
        httpGet:
          path: /not/exsit
          port: 8080
        initialDelaySeconds: 5
        timeoutSeconds: 2
        periodSeconds: 5
        failureThreshold: 1
```

## 3. LivenessProbe + ReadinessProbe

실제 서비스 운영시에는 보통 두개를 같이 설정하는 편이다.  
정상적으로 서버가 떴을 때 요청도 받고, 문제가 생기면 자동으로 재시작도 되도록 구성하기 위함이다.  
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-rplp
  labels:
    app: test
spec:
  containers:
    - name: test
      image: test
      livenessProbe:
        httpGet:
          path: /
          port: 3000
      readinessProbe:
        httpGet:
          path: /
          port: 3000
```

## 4. Probe 방식
Probe 방식은 총 4가지이다.  

### 4-1. httpGet
HTTP GET 요청으로 컨테이너 상태를 체크한다.  
지정된 Path 로 HTTP GET 요청을 보내고 리턴되는 HTTP 응답코드가 200~3xx 라면 정상으로 판단한다.  
- `path` : HTTP에 액세스할 경로, 기본값은 `/`
- `host` : 연결할 호스트이름, 기본값은 Pod 의 IP
- `port` : 컨테이너에서 액세스할 포트의 번호, 포트 범위는 1~65535
- `httpHeaders` : 리퀘스트 사용자 정의 헤더
- `scheme` : 호스트에 연결할때 사용할 스키마 타입(HTTP/HTTPS), 기본값은 HTTP
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/e2e-test-images/agnhost:2.40
    args:
    - liveness
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
```

### 4-2. exec
- `command` : 상태 진단(Probe)을 쉘 명령으로 수행하고 결과에 따라 정상 여부를 체크한다.  
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

### 4-3. tcpSocket
TCP Probe 는 Pod가 아니라 Node에서 Probe 연결을 구성한다. 
- `port` : 컨테이너에서 액세스할 포트의 번호, 포트 범위는 1~65535
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: registry.k8s.io/goproxy:0.1
    ports:
    - containerPort: 8080
    readinessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
```

### 4-4. grpc
{{< alert icon="circle-info" cardColor="#326CE5" iconColor="white" textColor="white" >}}
**Update**: kubernetes v1.27
{{< /alert >}}

- `port` : 컨테이너에서 액세스할 포트의 번호, 포트 범위는 1~65535
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: etcd-with-grpc
spec:
  containers:
  - name: etcd
    image: registry.k8s.io/etcd:3.5.1-0
    command: [ "/usr/local/bin/etcd", "--data-dir",  "/var/lib/etcd", "--listen-client-urls", "http://0.0.0.0:2379", "--advertise-client-urls", "http://127.0.0.1:2379", "--log-level", "debug"]
    ports:
    - containerPort: 2379
    livenessProbe:
      grpc:
        port: 2379
      initialDelaySeconds: 10

```

## 5. Probe 설정
- `initialDelaySeconds` : 컨테이너가 시작된 후 Probe가 시작되기 전 기다리는 시간
- `periodSeconds` : Probe를 수행하는 빈도(주기)
- `timeoutSeconds` : Probe가 시간초과로 간주되기까지의 시간
- `successThreshold` : Probe가 성공으로 간주되기 위해 연속적으로 성공해야하는 최소 횟수
- `failureThreshold` : kubernetes가 실패했다고 판단하는 Probe 연속 실패 횟수 
- `terminationGracePeriodSeconds` : kubelet이 실패한 컨테이너의 중지를 트리거하고, 컨테이너 런타임을 강제로 중지시키기 전에 대기하는 유예 시간