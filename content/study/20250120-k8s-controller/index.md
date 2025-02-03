---
title: "Controller"
date: 2025-01-20T12:02:20+09:00
draft: false
categories: [study]
tags: [k8s, concepts]
description: ""
slug: ""
series: [kubernetes]
series_order: 3
authors:
  - P373R
---

## 1. Replication Controller
**ReplicationController** 는 `selector` 정의가 필요없다.  `selector` 없이도 동작한다.  
`template` 에서 정의한 `labels` 에 대해서만 관리한다.  

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: app-rc
  labels:
    app: app
    type: mongodb
spec:
  replicas: 3
  template:
    metadata:
      name: rc-pod
      labels:
        app: app
        type: mongodb
    spec:
      containers:
        - name: rc-c
          image: mongo:4
```


## 2. ReplicaSet
ReplicationController와 마찬가지로 Pod의 고가용성, 로드밸런싱, 스케일링을 위해 설계되었다.  
해당 리소스는 복제본 갯수를 제어하기위해서 `selector` 정의가 꼭 필요하다. (필수값)  
`selector` 로 `labels` 를 기준으로 Pod를 체크하기 때문에 label 이 겹치지 않게 신경써서 배포해야한다. 
**ReplicaSet**은 `template` 에서 **정의하지 않은 Pod들을 포함**하여 복제본 수를 관리할수도 있다.  

아래 예시를 살펴보자.  

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: only-pod
  labels:
    app: app
    tier: mongodb
spec:
  containers:
    - name: app
      image: mongo:4

---

apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: app-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      tier: mongodb
  template:
    metadata:
      name: rs-pod
      labels:
        app: app
        tier: mongodb
    spec:
      containers:
        - name: rs-c
          image: mongo:4
```
  
단일 Pod 가 먼저 1개 생성된 뒤, ReplicaSet 에서 설정한 `.spec.selector` 에 의해 `app=app, tier=mongodb` 를 준수하는 파드 3개(`.spec.replicas`)를 맞추려고 할것이다.  
이미 같은 `labels`의 파드 1개가 띄워져 있으니, 3개를 충족하기 위해 2개를 추가 생성한다.  

아래는 실행 결과이다.  
```bash
NAME               READY   STATUS    RESTARTS   AGE
pod/app-rs-hnkwr   1/1     Running   0          3s
pod/app-rs-mdxwj   1/1     Running   0          3s
pod/only-pod       1/1     Running   0          3s

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   47h

NAME                     DESIRED   CURRENT   READY   AGE
replicaset.apps/app-rs   3         3         3       3s
```
  
### 차이점
#### 1. Selector
- ReplicationController: `selector`가 **선택값**이다. 없어도 동작한다.   
- ReplicaSet: `selector`가 **필수값**이다. 없으면 동작하지 않는다.  
  
#### 2. Label Matching
- ReplicationController: `matchLabels`만 지원한다.  
(특정 labels 를 **정적**으로 선언해 선택할 수 있다.)  
- ReplicaSet: `matchExpressions`을 추가 지원한다.  
(Operator 연산자를 통해 **동적**으로 다양한 Pod를 유연하게 선택할 수 있다.)

#### 3. Updates and Rollbacks
- ReplicationController: RollingUpdate 를 지원하지 않는다. **Deployment 와 통합되지 않는다.**
- ReplicaSet: **Deployment 와 통합사용이 가능**해 여러가지 배포 옵션을 활용할 수 있다.  

> "최신 릴리즈 기준 ReplicationController 보다는 **ReplicaSet** 사용을 권장한다."  

## 3. Deployment
가장 많이 사용하는 컨트롤러이다.  
ReplicaSet과 통합해 Pod를 업데이트하거나 버전을 확인해 롤백하는데 사용된다.  
템플릿 문법은 ReplicaSet과 완전히 동일하고 `kind` 만 **Deployment** 로 치환해 작성하면 동작한다.  
Deployment의 진가는 새로운 버전으로 교체할때 발휘된다.  

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      tier: mongodb
  template:
    metadata:
      name: dp-pod
      labels:
        app: app
        tier: mongodb
    spec:
      containers:
        - name: dp-c
          image: mongo:3
```

위 템플릿을 실행하면 아래와 같다.  

```bash
❯ k get rs -w
NAME               DESIRED   CURRENT   READY   AGE
app-dp-dcb44d4b9   3         0         0       0s
app-dp-dcb44d4b9   3         0         0       0s
app-dp-dcb44d4b9   3         3         0       0s
app-dp-dcb44d4b9   3         3         1       1s
app-dp-dcb44d4b9   3         3         2       1s
app-dp-dcb44d4b9   3         3         3       1s
```

같은 파일에서 컨테이너의 버전만 수정했다.  
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      tier: mongodb
  template:
    metadata:
      name: dp-pod
      labels:
        app: app
        tier: mongodb
    spec:
      containers:
        - name: dp-c
          image: mongo:4    # mongo:3 -> mongo:4
```

아래는 실행 결과이다.  
`dcb44d4b9` replicaset이 제거되고 `bb78bc4fd` replicaset이 재배포 됬다.  
Deployment 의 업데이트 방식은 이전 버전의 Pod를 제거하고 새로운 버전을 생성하는 방식으로 이루어진다.  
```bash
NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/app-dp-bb78bc4fd   3         3         3       62s
replicaset.apps/app-dp-dcb44d4b9   0         0         0       4m57s
```

```bash
❯ k get rs -w
NAME               DESIRED   CURRENT   READY   AGE
app-dp-bb78bc4fd   1         0         0       0s #     ⎫ 새버전 배포 1:0
app-dp-bb78bc4fd   1         0         0       0s #     ⎭
app-dp-bb78bc4fd   1         1         0       0s #     ⎫ 새버전 배포 1:1
app-dp-bb78bc4fd   1         1         1       1s #     ⎭
# ================================================
app-dp-dcb44d4b9   2         3         3       3m56s #  ⎫ 구버전 배포 2:3
app-dp-dcb44d4b9   2         3         3       3m56s #  ⎭ 
# ================================================
app-dp-bb78bc4fd   2         1         1       1s    #  ⎫
app-dp-dcb44d4b9   2         2         2       3m56s # ----> 구버전 배포 2:2
app-dp-bb78bc4fd   2         1         1       1s    #  ⎬ 새버전 배포 2:2
app-dp-bb78bc4fd   2         2         1       1s    #  ⎪
app-dp-bb78bc4fd   2         2         2       2s    #  ⎭
# ================================================
app-dp-dcb44d4b9   1         2         2       3m57s #  ⎫
app-dp-dcb44d4b9   1         2         2       3m57s #  ⎬ 구버전 배포 1:2
app-dp-bb78bc4fd   3         2         2       2s # -------> 새버전 배포 3:2
app-dp-dcb44d4b9   1         1         1       3m57s #  ⎭
# ================================================
app-dp-bb78bc4fd   3         2         2       2s #     ⎫
app-dp-bb78bc4fd   3         3         2       2s #     ⎬ 새버전 배포 3:3
app-dp-bb78bc4fd   3         3         3       3s #     ⎭
# ================================================
app-dp-dcb44d4b9   0         1         1       3m58s #  ⎫
app-dp-dcb44d4b9   0         1         1       3m58s #  ⎬ 구버전 배포 0:0
app-dp-dcb44d4b9   0         0         0       3m58s #  ⎭
```

> Deployment 기본값은 RollingUpdate (위 사례)

위 실행과정을 살펴보면 구버전의 **Deployment** 갯수(=replicas)를 1개씩 제거하고 새버전을 1개씩 생성했다. 
**Deployment** 의 업데이트는 사실 기존것을 업데이트한다기보다는 **"기존의것을 없애고 새로 생성한다"** 가 정확한 표현이다.  

## 4. DaemonSet
DaemonSet은 ReplicaSet의 특수한 형태라고 할 수 있다. 왜냐하면 각 Node에 Pod를 하나씩 배치하는 리소스이기 때문이다. 
노드가 새로 추가되었을때에도 Pod 한개가 무조건 배치된다.  

> 주로 로그나 메트릭을 수집하는 Fluentd, Fluentbit, Datadog 같은 프로세스를 위해 사용한다.  

문법은 Deployment, ReplicaSet 과 마찬가지로 `kind` 부분만 **DaemonSet** 으로 변경하면 된다.  
각 노드별 무조건 Pod 1개를 배치하기 때문에 `spec.replicas` 옵션은 없다.  

예를 들면 아래와 같다.  
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: app-ds
spec:
  selector:
    matchLabels:
      app: app
      tier: mongodb
  template:
    metadata:
      name: ds-pod
      labels:
        app: app
        tier: mongodb
    spec:
      containers:
        - name: ds-c
          image: mongo:4
```

아래는 실행 결과이다. juseok 노드에 Pod 1개 배포되어있는것을 확인할 수 있다.  
```bash
❯ k get po -o wide
NAME            READY   STATUS    RESTARTS   AGE   IP            NODE     NOMINATED NODE   READINESS GATES
mongodb-psmpq   1/1     Running   0          96s   10.244.0.78   juseok   <none>           <none>
```

DaemonSet 도 Deployment 와 마찬가지로 배포 전략을 선택할 수 있다.  
`spec.updateStrategy.type` 으로 지정가능하고, 유효한 type에는 `OnDelete`, `RollingUpdate` 가 있다. 
**OnDelete** 는 배포 템플릿을 변경 적용해도 기존 배포된것은 건드리지 않고 진행되는 방식을 말하고, **RollingUpdate** 는 각 노드별 배포 노드가 무조건 1개이기때문에 Deployment와는 달리 maxSurge(최대 파드 수)를 지정할 수 없고 maxUnavailable(동시 정지 가능 최대 파드 수)를 지정해 n개씩 동시에 업데이트해 나가는 형태로 업데이트가 이루어진다.  
(여기서 n개씩 동시 업데이트라고 하는것은 n개의 노드를 말하는 것이다.)  

## 5. StatefulSet
**StatefulSet** 은 디스크, 네트워크 아이덴티티 처럼 **상태를 유지해야하는 애플리케이션**을 위해 설계되었다. 
문법은 ReplicaSet 과 동일하고 마찬가지로 `kind` 만 StatefulSet 으로 치환해서 작성하면 된다.  

### 5-1. 활용 사례

#### 데이터베이스 클러스터
- MySQL
- MongoDB

#### 메시징 시스템
- Redis
- Kafka
- RabbitMQ

#### 모니터링 및 로깅시스템
- Elasticsearch
- Prometheus
- Loki

#### CI/CD
- GitLab
- Jenkins

### 5-2. 배포 순서
무작위로 생성, 삭제가 이루어지는 **ReplicaSet** 과는 달리 먼저 생성된것이 가장 나중에 제거되는 Stack 처럼 동작한다.  

```bash
❯ k get po -w | grep 1/1
db-0   1/1     Running             0          22s   # <-- 0번 db 배포
db-1   1/1     Running             0          24s   # <-- 1번 db 배포
db-2   1/1     Running             0          26s   # <-- 2번 db 배포
db-3   1/1     Running             0          28s   # <-- 3번 db 배포
db-4   1/1     Running             0          30s   # <-- 4번 db 배포
# ==================================================================
db-4   1/1     Terminating         0          49s
db-4   1/1     Running             0          1s    # <-- 4번 db 교체
db-3   1/1     Terminating         0          48s
db-3   1/1     Running             0          1s    # <-- 3번 db 교체
db-2   1/1     Terminating         0          48s
db-2   1/1     Running             0          1s    # <-- 2번 db 교체
db-1   1/1     Terminating         0          48s
db-1   1/1     Running             0          1s    # <-- 1번 db 교체
db-0   1/1     Terminating         0          48s
db-0   1/1     Running             0          1s    # <-- 0번 db 교체
```

하지만 이 순서를 없앨수도 있다.  
순서가 있는 기본옵션(`OrderedReady`)은 동시에 1개의 Pod 를 업데이트하는 방식이기 때문에 업데이트 속도가 느리다. 
개발이나 테스트환경같이 배포가 수시로 빨리 이루어져야하는 경우나 데이터 일관성이 상관없는 경우에는 이러한 순서가 필요없다. 
그렇기 때문에 순서를 없애서 배포하기도 한다.  
`.spec.podManagementPolicy` 를 `Parallel`로 설정함으로써 순서를 없앨 수 있다.  

### 5-3. 매니페스트 업데이트
Kubernetes에서 **StatefulSet**의 컨테이너 스펙 수정은 문제가 안되지만, `name` 필드를 수정하고 해당 변경 사항을 기존 **StatefulSet**에 적용하려 한다면, 이는 단순히 `kubectl apply`로는 해결되지 않는다. **StatefulSet**의 `name`을 변경하는 것은 단순한 **수정 이상의 의미**를 가지기 때문이다.

따라서 단순 매니페스트 수정으로 불가능하고 직접 기존 **StatefulSet** 을 삭제하고 새로운 `name` 의 **StatefulSet** 을 배포해야한다.  

기본적으로 Kubernetes의 **StatefulSet**은 각각의 인스턴스에 고유한 네임을 부여하며, 이는 `name` 필드의 변경을 통해 자동으로 갱신되지 않는다. 왜냐하면 **StatefulSet**의 `name`은 생성된 리소스와 직접적으로 연결되기 때문이다.  

### 5-4. PVC & PV
#### 1. 볼륨의 종류
- **Volume** : hostPath, nfs, iSCSI, Ceph 등 매니페스트에 직접 지정하여 구성
- **PersistentVolume** : 매니페스트에서 PV 리소스를 생성하고 외부 시스템(Public Cloud)과 연계하여 구성

일반 **Volume** 은 k8s 클러스터에서 관리할 수 없다. 사람이 직접 일일이 생성해야한다. 즉, 매니페스트를 통해 새 볼륨을 생성하거나 기존 볼륨을 삭제하지 못한다.  
반면, **PersistentVolume** 은 k8s 클러스터 자체적으로 관리할 수 있다. 매니페스트를 통해 PV 리소스를 생성하고 외부 시스템과 연계하여 구성이 가능하다.  

#### 2. Volume
다음은 볼륨 플러그인의 예시이다.  
- hostPath : 노드상의 영역을 컨테이너에 매핑하는 플러그인
- emptyDir : 파드용 임시 디스크 영역(ex. 캐시영역), 파드가 종료되면 같이 삭제된다. 호스트와 별개의 공간이다.  
- NFS
- iSCSI
- CephFS

#### 3. PersistentVolume
**PV(영구 볼륨)** 은 파드에서 정의하는 Volume과는 달리 개별 리소스로 생성한 후 사용한다.  
즉, 매니페스트를 통해서 **PV** 를 생성해야 한다.  
PV는 기본적으로 네트워크를 통해 디스크를 Attach하는 디스크 타입이다.  
- GCE Persistent Disk
- AWS Elastic Block Store
- Azure File
- NFS
- iSCSI
- ceph(RBD, CephFS)
- OpenStack Cinder
- GlusterFS
- Container Storage Interface(CSI)

#### 4. PVC(PersistentVolumeClaim)
이름 그대로 영구 볼륨 요청을 위한 리소스이다.  
영구 볼륨(PV)은 클러스터의 볼륨리스트에 등록만 하기때문에 파드에 연결해서 사용하려면 PVC를 정의해야한다.  

#### 5. 정적 프로비저닝
정적 프로비저닝의 플로우는 아래와 같다. 아래 예시는 aws ebs 를 사용하는 예시이다.  
정적 프로비저닝의 경우, 프로비저너로 사용할 외부시스템에 디스크를 미리 생성한 후에 적용해야한다.  
아래 예시에서는 AWS EBS에 스토리지를 미리 생성해야한다.  

1. 관리자가 볼륨을 직접 생성해서 PV에 등록한다.
    ```yaml
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: my-ebs-pv
    spec:
      capacity:
        storage: 10Gi  # EBS 볼륨 크기 (미리 생성한 볼륨과 일치해야 함)
      accessModes:
        - ReadWriteOnce
      awsElasticBlockStore:
        volumeID: vol-0123456789abcdef0  # 미리 생성한 EBS 볼륨의 ID
        fsType: ext4
    ```

2. 개발자는 PVC를 배포하고 해당 요청 사항에 맞는 Volume을 찾아 바인딩한다.  
    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: my-ebs-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi  # 요청하는 스토리지 크기 (미리 생성한 볼륨과 일치해야 함)
    ```

3. Pod에서 Volume 부분에 PVC를 넣어서 구성한다.  
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: my-ebs-pod
    spec:
      containers:
      - name: my-container
        image: my-container-image
        volumeMounts:
        - mountPath: /data  # 컨테이너 내 마운트 경로
          name: ebs-storage
      volumes:
      - name: ebs-storage
        persistentVolumeClaim:
          claimName: my-ebs-pvc  # 참조할 PVC 이름
    ```
관리자가 직접 PV를 프로비저닝 해야하기 때문에 번거롭다.  

PVC 배포시 요청사항에 맞는 PV가 있다면, PVC는 조건에 맞는 PV 와 바인딩된다.  
Pod는 PVC에 바인딩된 PV를 확인해 마운트한다.  

#### 6. 동적 프로비저닝
StorageClass 와 Provisioner를 사용해 자동으로 PV를 생성해서 PVC와 바인딩하는 방법이다.  
Provisioner 에 접속할 스토리지의 연결 정보가 있다.  
PVC가 배포되면 Provisioner 는 해당 요청사항에 맞는 볼륨을 프로비저닝해서 Pool에 넣고 해당 PV는 PVC와 storageClassName 을 통해 자동으로 바인딩된다.  

1. aws ebs 를 동적 프로비저닝에 사용할 `StorageClass` 를 정의한다.  
    ```yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: standard-ebs
    provisioner: kubernetes.io/aws-ebs
    parameters:
      type: gp2  # EBS 볼륨 유형 (gp2, io1 등)
      fsType: ext4
    reclaimPolicy: Delete  # PVC 삭제 시 EBS 볼륨도 삭제
    ```
2. PVC를 생성할 때 `StorageClass` 를 참조해 동적으로 PV를 프로비저닝한다.  
    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: my-ebs-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: standard-ebs  # 위에서 정의한 StorageClass 이름
    ```
3. PVC를 사용하는 Pod 를 정의한다.  
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: my-ebs-pod
    spec:
      containers:
      - name: my-container
        image: my-container-image
        volumeMounts:
        - mountPath: /data  # 컨테이너 내 마운트 경로
          name: ebs-storage
      volumes:
      - name: ebs-storage
        persistentVolumeClaim:
          claimName: my-ebs-pvc  # 참조할 PVC 이름
    ```

## 6. Job

**Job** 과 ReplicaSet 의 차이점은 **"기동중인 파드가 정지되는것을 전제로 만들어졌는가이다."**  
ReplicaSet에서 Pod의 정지는 예상치 못한 에러이다. 반면, **Job에서는 Pod의 정지는 정상 동작이다.**

### 6-1. restartPolicy
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cal-pi
spec:
  template:
    spec:
      containers:
        - name: cal-pi
          image: perl
          command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
```

```bash
❯ k get job
NAME   STATUS     COMPLETIONS   DURATION   AGE
test   Complete   1/1           6s         2m37s
```

### 6-2. 병렬성
`completions`, `parallism`, `backoffLimit` 으로 생성 파드 갯수를 조절할 수 있다.  


### 6-3. 잡 구성 패턴
Job을 통해 생성된 각 Pod들은 서로 통신하지 않는다. 각자 맡은일을 수행하고 종료되는것이 보장되어있는 리소스이다.  
Job은 보통 메일을 보내거나 파일을 변환하는등 분산작업을 위해 사용한다.  

### 6-4. 크론잡
{{< katex >}}
\\(\text{Pod} \subset \text{ReplicaSet} \subset \text{Deployment} \\)  
\\(\text{Pod} \subset \text{Job} \subset \text{CronJob}\\)  

**CronJob** 이 Job을 관리하고 Job이 파드를 관리하는 관계이다.  
**CronJob** 은 스케줄링된 시간에 Job을 생성해야할 때 사용한다.  

`.spec.startingDeadlineSeconds` 필드는 예약된 시간에 크론잡이 실행되지 못했을 때 해당 필드값으로 설정한 시간이 지나면 크론잡이 실행되지 않도록 처리한다. 간단히 타임아웃이라고 보면된다. 만약 이 필드값을 지정하지 않았다면 실행시간이 지나더라도 잡이 실행된다.  
`.spec.concurrencyPolicy` 필드는 잡의 동시성을 관리한다.  