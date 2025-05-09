---
title: "Teleport 쿠버네티스에 배포하기"
date: 2025-05-02T09:55:00+09:00
draft: true
categories: [guide]
tags: [teleport, self-hosted, k8s]
description: ""
slug: ""
series: [teleport]
series_order: 2
authors:
  - P373R
---

### 사전 요구사항
- 도메인(let's encrypt 로 인증서 발급하기 위해)
- DNS 레코드 설정
  | Type |           Record         |            Source          |
  |------|--------------------------|----------------------------|
  | A    | `teleport.example.com`   | 123.xxx.xxx.xxx(Public IP) |
  | A    | `*.teleport.example.com` | 123.xxx.xxx.xxx(Public IP) |
- Metallb : 기존 공식 가이드에서는 CSP의 LB를 준비하라고 되어있지만, 여기서는 로컬 LB를 사용하여 구현 예정
- Persistent Volume, dynamic volume provisioner
  ```bash
  k get pv
  k get storageclasses
  ```
- helm >= 3.4.2
- kubernetes >= v1.17.0

## 1. Metallb 설치
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```
### 1-1. coredns 설정
```bash
kubectl edit cm -n kube-system coredns
```
다음과 같이 수정한다.  
```bash
forward . 8.8.8.8 8.8.4.4
```
그리고 CoreDNS를 재시작한다.  
```bash
kubectl rollout restart deployment -n kube-system coredns
```

```
helm install cilium cilium/cilium --version 1.17.3 --namespace kube-system --set k8sServiceHost=10.17.73.160 --set k8sServicePort=6443 --set debug.enabled=true --set rollOutCiliumPods=true --set routingMode=native --set autoDirectNodeRoutes=true --set bpf.masquerade=true --set bpf.hostRouting=true --set endpointRoutes.enabled=true --set ipam.mode=kubernetes --set k8s.requireIPv4PodCIDR=true --set kubeProxyReplacement=true --set ipv4NativeRoutingCIDR=10.17.0.0/16 --set installNoConntrackIptablesRules=true --set hubble.ui.enabled=true --set hubble.relay.enabled=true --set prometheus.enabled=true --set operator.prometheus.enabled=true --set hubble.metrics.enableOpenMetrics=true --set hubble.metrics.enabled=“{dns:query;ignoreAAAA,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}” --set operator.replicas=1
```

### 1-2. IPAddressPool 생성
- 서비스에 할당할 수 있는 IP 주소 범위이다.  
- Metallb는 IPAddressPool로 서비스를 위한 외부 IP주소를 관리하고, 서비스가 생성될 때 해당 IP 주소를 동적으로 할당한다.  
```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: teleport-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.17.73.200-10.17.73.220
EOF
```

🐛 **IPAddressPool** 생성 중 아래 에러가 발생한다면, 웹훅 검증을 우회하여 해결할 수 있다.  
```bash
Error from server (InternalError): error when creating "STDIN":  Internal error occurred: failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io": failed to call webhook: Post "https://metallb-webhook-service.metallb-system.svc:443/validate-metallb-io-v1beta1-ipaddresspool?timeout=10s": context deadline exceeded
```
```bash
# 웹훅 검증 우회
kubectl delete validatingwebhookconfigurations metallb-webhook-configuration
```

### 1-3. L2Advertisement 생성
- 클러스터 내의 서비스가 외부 네트워크에 IP주소를 노출하는 방식을 정의하는 방법
- Layer2 방식으로 클러스터 내의 서비스 IP 주소를 노출해 외부에서 해당 IP 주소에 접근할 수 있도록 한다.  
```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: teleport-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - teleport-pool
  interfaces:
  - ens3
EOF
```



## 2. helm 설치
```bash
{
wget https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz
tar -zxvf helm-v3.17.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm-v3.17.0-linux-amd64.tar.gz
}
```

## 2. 볼륨 프로비저너 설치
hostPath 기반 로컬 스토리지를 위한 프로비저너를 설치한다.  
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

## 3. StorageClass 설정
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
```bash
# StorageClass 확인
k get storageclasses

# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  59m
```

<!-- ### 3-1. PVC 수동 생성
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: teleport-cluster
  namespace: teleport-cluster
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path  # 앞서 생성한 StorageClass 사용
EOF
``` -->

## 4. teleport-cluster 헬름 차트 추가
```bash
{
helm repo add teleport https://charts.releases.teleport.dev
helm repo update
}
```

## 5. teleport-cluster 리소스 추가
```bash
{
kubectl create ns teleport-cluster
kubectl label ns teleport-cluster 'pod-security.kubernetes.io/enforce=baseline'
kubectl config set-context --current --namespace=teleport-cluster
}
```

## 6. chart values 작성
```bash
cat << EOF > teleport-cluster-values.yaml
clusterName: teleport.p373r.net
proxyListenerMode: multiplex
acme: true
acmeEmail: juseok@example.com
EOF
```

```bash
helm install teleport-cluster teleport/teleport-cluster --version 17.4.6 --values teleport-cluster-values.yaml
```

## 5. Teleport 서비스에 HTTP(80) 포트 추가
차트 배포가 완료되면 `teleport-cluster-proxy-xxxx` 파드에서는 에러 로그를 출력하고 있을것이다. 이는 아래 과정때문에 발생하는 문제다.  
1. `teleport-cluster-proxy-xxxx` 파드가 시작될때 acme 프로세스를 시작한다.  
2. `teleport-cluster-proxy-xxxx` 파드는 80포트를 통해 Let's Encrypt의 HTTP-01 챌린지를 수신한다.  
3. Let's Encrypt가 도메인 소유권을 확인하고 인증서를 발급한다.  
4. `teleport-cluster-proxy-xxxx` 파드가 발급받은 인증서를 사용해 443 포트로 HTTPS 연결을 수립한다.  

Teleport에서 제공하는 헬름 차트는 기본적으로 CSP의 LB 사용을 전제로 설계되어 있기 때문에 발생하는 문제이다.  
클라우드 환경에서는 일반적으로 아래 과정으로 인증서 구성이 진행된다.  
1. 클라우드 LB가 HTTP(80) -> HTTPS(443) 리다이렉션 자동 처리
2. 또는 클라우드 LB에서 인증서 자체 관리 가능

아래 명령어로 서비스에 HTTP(80)포트를 추가해야 위 문제를 해결할 수 있다.  
```bash
kubectl patch svc teleport-cluster -n teleport-cluster --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "http", "port": 80, "protocol": "TCP", "targetPort": 3080}}]'
```

