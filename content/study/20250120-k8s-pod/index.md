---
title: "Pod"
date: 2025-01-20T12:02:09+09:00
draft: false
categories: [study]
tags: [k8s, concepts]
description: ""
slug: ""
series: [kubernetes]
series_order: 2
authors:
  - P373R
---

도커에서는 컨테이너가 배포의 최소단위지만, 쿠버네티스에서는 파드가 배포의 최소 단위다.  
파드는 컨테이너가 한개 또는 여러개가 배치될 수 있다.  

특수한 경우가 아니라면 관리하기 복잡해지기 때문에 일반적으로 멀티 컨테이너 파드보다는 1파드 1컨테이너로 배포하는편이다.  

## 1. 스태틱 파드

이전에 클러스터 구조에 대해 설명할 때 모든 컴포넌트들은 서로 직접 소통하지않고 kube-apiserver 를 통해서만 통신한다고 이야기한적이 있다. 그런데 이를 거치지않고 각 노드의 kubelet 이 직접 관리하는 파드가 있다. 그런 파드를 스태틱파드라고 부른다.  

> 특정 노드에 항상 실행되어야 하는 작업을 수행해야할때 사용한다.  

스태틱파드는 API서버를 통하지 않고 kubelet에 의존하여 관리되기 때문에, 해당 노드에서만 존재하며, API 서버를 통해 다른 노드로 쉽게 배포하거나 수정할 수 없다.  
스태틱파드의 업데이트는 `/etc/kubernetes/manifests` 디렉토리의 `.yaml` 파일을 수정해야 하며, 이는 수동 관리가 필요함을 의미한다.  
(해당 경로는 `/var/lib/kubelet/config.yaml` 에서 `staticPodPath` 에서 확인할 수 있다.)

일반적으로 시스템 컴포넌트(`kube-apiserver`, `kube-scheduler`)와 같은 매우 중요하거나 특정 노드에서만 실행되어야하는 작업에 사용된다.  

## 2. 파드 리소스 제어

```yaml
...
spec:
  containers: ...
  ...
  resources:
    requests:      # 최소 요구사항
      cpu: 0.1
      memory: 200M
    limits:        # 최대 요구사항
      cpu: 0.5
      memory: 16
```

cpu 의 소수점 포맷은 가중치를 뜻한다. cpu는 연산을 처리하는 **Core** 와 **Controller**로 구성되어있는데, 위에서 설정하는 부분은 `Core`에 대한것이다. 코어는 작업을 처리하기 위해 한번에 한개의 연산만 처리하는데 각 연산마다 할애할 시간을 가중치로써 조절하게 된다. 위 예시의 cpu의 소수점 수치는 cpu를 0.1개를 사용하겠다는 뜻이 아니고 1코어가 연산하는데 얼마나 시간을 할애할것인가를 뜻한다.  

이를 시각화 하는 방법은 아래와 같다.  

```bash
kubectl top pod
```

## 3. 파드 구성 패턴

### 3-1. 사이드카 패턴

![사이드카](./assets/k8s-sidecar.png)

예를들어 ai 분석을 위한 컨테이너를 배포한다고 가정하자. ai 분석 컨테이너는 분석만 수행해야 한다. ai 컨테이너가 문제없이 동작하기 위해서는 리소스 관리가 잘되어야한다. 이 리소스 관리를 위해서 해당 컨테이너의 로그를 주시하는 로그 수집기나 메트릭 수집기가 **추가로** 필요하다. 이 로그 수집기는 ai 컨테이너 내부에 있어도 되지만 ai 컨테이너는 분석에 충실해야 비용 효율적일것이다. 로그 수집기가 ai 컨테이너 내부에 위치한다면 ai 컨테이너가 죽으면 같이 죽어 없어져 지속적인 관찰이 불가능할것이다. 역할을 분리하고 안전하게 운영하기 위해 역할에 따라 컨테이너를 분리해야한다. ai 컨테이너는 원래의 목적인 분석만 하고 추가로 분리된 로그 수집 컨테이너는 ai 컨테이너 외부에서 ai 컨테이너를 주시하면서 로그를 수집하는 일에 집중할 수 있을것이다. 이렇듯 메인 컨테이너는 원래 목적의 기능에만 충실하도록 구성하고 나머지 공통 부가 기능들은 컨테이너를 분리해 추가해서 사용하는 형태를 사이드카 패턴이라고 부른다.  

### 3-2. 앰배서더 패턴

![앰배서더](./assets/k8s-ambassador.jpg)

앰배서더는 간단히 설명하면 어떤 그룹(조직)을 대표하는 직책을 뜻하는데 여기서도 그 의미로써 활용된다. 서비스(파드 그룹이라 볼수도 있음)를 대표해서 트래픽처리를 대신 알아서 처리하는 구조를 말하는데, 여기서 앰배서더는 프록시라는 직책을 맡아 트래픽을 세밀하게 제어하는 패턴이다.  

### 3-3. 어댑터 패턴

여기서의 어댑터역할을 하는 컨테이너(파드)는 주로 각 파드에 탑재된 특정 애플리케이션의 출력의 포맷을 필요에 맞게 다듬어서 통일하는 용도로 활용된다.  
오픈소스 애플리케이션을 무분별하게 도입하다보면 각각 엇비슷한 역할을 하는 프로그램임에도 로그 포맷이나 출력 포맷이 제각각인 경우가 많다. 이런 경우 나중에 버그를 찾거나 모니터링할때 눈이 너무 아프고 작업이 어려울 수 있다.  

이럴 때 어댑터 컨테이너로 stdout 의 포맷을 통일하면 추후 작업이 훨씬 간편해질것이다. 이때 사용하는것이 어댑터 패턴이다.  

## 4. 멀티 컨테이너 파드
위에서 1파드 1컨테이너로 운영한다고 언급했다.  
관리의 용이성때문에 보통 1파드 1컨테이너로 구성하지만, 멀티 컨테이너로 구성하는 경우도 흔하다.  
하나의 Pod 에 속한 컨테이너들은 서로 네트워크를 공유하기 때문에 localhost 로 통신이 가능하고, 디렉토리를 공유할수도 있는 등 장점도 있다.  

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: counter
  labels:
    app: sample-pod
spec:
  containers:
    - name: app
      image: ghcr.io/subicura/counter:latest
      env:
        - name: REDIS_HOST
          value: "localhost"
    - name: db
      image: redis
```