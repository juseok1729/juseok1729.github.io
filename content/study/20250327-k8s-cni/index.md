---
title: "CNI"
date: 2025-03-27T16:46:22+09:00
draft: false
categories: [study]
tags: [k8s, concepts]
description: ""
slug: ""
series: [kubernetes]
series_order: 6
authors:
  - P373R
---

![ecpu](./assets/bench-ecpu.png "CNI 효율 차트, [benchmark-cni-2024](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-40gbit-s-network-2024-156f085a5e4e)")

## 1. 클러스터 스펙별 추천

### 1. 저사양 클러스터(Edge)
{{< alert icon="circle-info" cardColor="#dbe9fe" iconColor="#1d3557" textColor="#000000" >}}
**✅ 추천 CNI : Kube-router**  
1. 경량화된 설계
2. Network Policies 기본 제공
3. 다양한 아키텍처(amd64, arm64, riscv64 등)를 지원

{{< /alert >}}
**👉 대안 : Flannel, Canal**

### 2. 표준 클러스터
{{< alert icon="circle-info" cardColor="#dbe9fe" iconColor="#1d3557" textColor="#000000" >}}

**✅ 추천 CNI : Cilium**  
1. 오픈소스 버전 기능이 풍부하고 마지막 벤치마크 이후 리소스 사용량이 크게 감소  
2. kube-proxy를 eBPF로 대체  
3. 관찰성 도구 및 Layer 7 정책을 제공  
4. 트러블 슈팅 및 구성을 위한 CLI
  
{{< /alert >}}
**👉 대안 : Calico, Antrea**  

{{< alert icon="circle-info" cardColor="#ffcc75" iconColor="#1d3557" textColor="#000000" >}}
**🐝 eBPF 란?**  
리눅스 커널 내에서 샌드박스 프로그램을 실행할 수 있게 해주는 기술로, 네트워크 패킷 처리를 포함한 다양한 커널 작업을 안전하고 효율적으로 확장하는 기술
{{< /alert >}}  
Cilium을 사용하면 기존의 kube-proxy 컴포넌트를 비활성화하고 대신 Cilium의 eBPF 프로그램이 해당 기능을 수행한다. 이는 특히 대규모 클러스터 환경이나 네트워크 처리량이 많은 환경에서 큰 이점을 제공한다.  

![iptables-vs-ebpf](./assets/iptables-ebpf.png "iptables(좌), ebpf(우)")
기존의 kube-proxy는 userspace에 위치한 iptables를 사용해 트래픽처리를 하는데, iptables는 일치하는 라우팅 규칙을 찾을 때까지 모든 규칙을 평가하는 특징이 있어서 파드/서비스가 많아질수록 규칙을 찾는 시간이 지연되므로 네트워크 성능에 영향을 끼친다.  
파드 1개가 생성될때 iptables는 5개 이상 생성될 수 있다. 파드/서비스가 많아질수록 iptables는 기하급수적으로 증가한다. 그리고 iptables에 새로운 규칙이 추가될때마다 기존의 전체 규칙을 바꿔야한다. 이 과정에서 또한번 지연이 발생한다.  

하지만, eBPF는 여러 네트워크 스택을 거치면서 발생하는 오버헤드가 없다. 커널레벨에서 동작하기 때문이다. 커널레벨에서 동작해서 Pod와 Container 레벨의 패킷 추적과 네트워크 통계가 가능하다.  
Host에 구성되는 eBPF가 Pod, Container 레벨의 추적이 가능한 이유는 Host와 Pod가 같은 cgroup namespace를 사용하고 'cgroup-bpf' 프로그램을 사용하기 때문이다.  
즉, cgroup의 프로세스에서 들어오고 나가는 모든 패킷에 대해 BPF를 실행 할 수 있기때문에 추적이 가능한것이다.  

### 3. 고성능 최적화 클러스터
{{< alert icon="circle-info" cardColor="#F5BCA9" iconColor="#1d3557" textColor="#000000" >}}
**✅ 추천 CNI : Calico VPP**  
하드웨어(NIC, 네트워크 패브릭, 마더보드, 프로세서 등)와 소프트웨어(운영 체제, 드라이버 등)를 광범위하게 미세 조정할 수 있는 경우에 추천

{{< /alert >}}
**👉 대안 : Calico, Antrea**

## 2. 환경별 추천
- 대규모 환경: ***Cilium[^cilium1]*** > Calico > Weave Net > Flannel
- 보안 환경: ***Cilium[^cilium2]*** > Calico > Weave Net > Flannel
- 개발/테스트: Flannel > Weave Net > Calico > **Cilium[^cilium3]**
- 암호화 필요: Weave Net > ***Cilium*** > Calico > Flannel

[^cilium1]: 처리량과 지연시간 측면에서 가장 우수  
[^cilium2]: L7 보안과 정책관리에서 최고성능  
[^cilium3]: 학습곡선이 가장 가파름(사용하기 어려움)  