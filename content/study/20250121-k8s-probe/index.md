---
title: "Probe"
date: 2025-01-21T14:08:42+09:00
draft: false
categories: [study]
tags: [k8s, object]
description: ""
slug: ""
series: [k8s]
series_order: 1
authors:
  - P373R
---

쿠버네티스는 **Probe** 라는 오브젝트로 상태 모니터링 기능을 제공하고 있다.  
템플릿(`.yml`)으로 바라는 상태를 쿠버네티스 클러스터에 반영하면 파드가 생성되는데,  
이때 파드는 **생성** -> **준비** 순서로 상태가 변한다.  
**준비** 상태가 되었을 때가 외부에서 접근할 수 있는 상태이다.  
**생성** 단계에서는 보통 애플리케이션이나 서버의 초기화가 이루어지는데(~~자바 초기화.. 읍읍..~~) 이때 접근을 시도하면 에러페이지가 출력된다. 
그래서 위와 같이 초기화가 완료되기전에 서비스되지 않도록 쿠버네티스는 애플리케이션이 완전히 준비가 된 상태에서만 트래픽을 받을 수 있게 처리 가능하다.  

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