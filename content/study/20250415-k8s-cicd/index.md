---
title: "[CKA] CI/CD"
date: 2025-04-15T11:18:52+09:00
draft: false
categories: [study]
tags: [k8s, concepts]
description: ""
slug: ""
series: ["cka"]
series_order: 12
authors:
  - P373R
---

## 1. DevOps와 CI/CD
DevOps는 개발(Dev)과 운영(Ops)의 합성어로 개발과 운영을 따로 분리하지않고 연결된 하나의 큰 워크플로우로 생각하여 지속적으로 소프트웨어를 고도화하는 방법론을 말한다.  
`# SRE 엔지니어` `# 플랫폼 엔지니어` `# 데브옵스 엔지니어`
- **SRE 엔지니어**: 장애대응, 모니터링, 자동화를 통해 개발과 운영 사이의 다리역할, 장애 재발방지
- **플랫폼 엔지니어**: 인프라, CI/CD 파이프라인, 개발 환경등의 플랫폼 서비스 제공, DX(개발자 경험)에 초점
- **데브옵스 엔지니어**: 개발 생명주기 전반의 효율성 증대가 목표, CI/CD 파이프라인 구축으로 빠른 배포 피드백 루프 강화가 목표, 모니터링, 로깅, 알림 시스템 구축이 관심사

**데브옵스 플로우**
1. Plan : 개발하고자 하는 소프트웨어가 무엇인지 정의하고 요구사항들을 정리
2. Coding : 코드를 개발하고 리뷰하며 코드 저장소에 코드를 저장
3. Building : 텍스트인 코드를 실행 가능한 형태로 빌드
4. Testing : 실행 파일을 테스트
5. Packaging : 테스트를 거친 결과물들을 패키징하여 배포 가능한 형태로 저장
6. Deploy : 출시된 산출물을 실제 환경에 배포
7. Operate : 배포된 애플리케이션이 정상적으로 동작하도록 관리
8. Monitor : 애플리케이션의 성능 측정, 사용성등을 관측

위의 플로우를 자동화하고 지속적으로 코드의 변경사항을 적용해 빠르게 변화하는 요구사항에 대응하고 생산성과 안정성 모두를 꾀하는 개발 방법론이다.    

### 1-1. CI/CD란?
- CI : 반복적인 코드 통합을 자동화하는것
- CD : 반복적인 소프트웨어 배포를 자동화하는것

### 1-2. CI(지속적 통합)
개발자는 하루에도 수십번 수백번씩 코드를 수정한다. 이것을 git 저장소에 push 하고, 테스트하고, 빌드하여 배포를 준비한다.  
이과정을 자동화해 개발자들이 코드 개발에만 집중할 수 있게 한다.  

### 1-3. CD(지속적 배포)
CD는 패키징과 배포를 자동화하는것을 말한다. 자동으로 소프트웨어를 패키징하고 운영 환경에 배포한다.  
배포시 발생할 수 있는 문제를 빠르게 인지하고 롤백할 수 있는 방법을 제공한다. 변경점을 안전하고 빠르게 배포할 수 있게 한다.  

### 1-4. 장점
**빠른 제품 반영**  
개발의 최종목적은 소프트웨어를 통해 비즈니스적 가치를 창출하는것인데, 비즈니스 요구사항의 변화에 따라 소프트웨어를 빠르게 릴리즈하여 사용자의 요구사항을 신속하게 제품에 반영할 수 있다.  

**운영 안정성 확보**  
자동화를 통해 휴먼에러를 최소화 할 수 있다.  
이를 통해 개발/운영 환경에서의 장애를 최소화하고 높은 안정성을 확보할 수 있다.  

**빠른 피드백**  
CI와 CD를 통해 문제점을 빠르게 발견해 신속히 버그를 수정해 높은 품질의 소프트웨어를 제공할 수 있다.  

**품질 향상**  
빠른 피드백과 잦은 배포를 통해 소프트웨어의 품질을 자연스럽게 햐상시킬 수 있다.  

**협력성 증대**  
개발자로 하여금 소프트웨어를 수정하는 부담을 줄인다.  
반복적 노가다 작업을 CI/CD 툴에게 위임해 협업하기 편한 환경을 만든다.  
CI/CD 과정 중에 발생하는 커뮤니케이션 비용을 줄여 보다 중요한 일에 집중할 수 있게 만들어 준다.  


## 2. CI 파이프라인
### 2-1. 젠킨스(Jenkins)
젠킨스는 인기있는 대표적인 오픈소스 CI/CD 툴이다.  
마찬가지로 helm chart로 손쉽게 구성이 가능하다.  
```bash
# 젠킨스 차트 다운로드
h fetch --untar stable/jenkins --version 2.3.0

# 젠킨스 설정파일 수정
vi jenkins/values.yaml
```

젠킨스 Ingress를 설정한다.  
```yaml
ingress:
  enable: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hostName: jenkins.10.0.1.1.sslip.io
```

젠킨스를 배포한다.
```bash
h install jenkins ./jenkins
```

`watch` 로 파드의 상태를 확인해 **READY**가 될때까지 기다린다.  
또는 특정 상태를 조건걸어 확인할 수도 있다.
```bash
# 상태 확인 방법 1
watch kubectl get po

# 상태 확인 방법 2
k wait --forcondition=Ready pod jenkins-xxx-xxx
```

설치(배포)가 완료(READY) 되었다면, 계정정보는 아래 명령어로 확인이 가능하다.  
```bash
# username은 admin 이다.
printf $(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

젠킨스 접속을 성공했다면, 바로 다음과 같은 Job을 생성하고 실행한다.  
1. New item > Free style project > Enter an item name: myfirstjob > OK
2. Build > Add build step > Execute shell
3. Command > echo "hello world!" 입력 > Save
4. Build Now > #1 > Console Output

```bash
watch kubectl get po
```
방금 실행한 빌드 잡이 실행되면서 파드가 한개 생성되었다가 사라지는것을 목격할 수 있다.  
쿠버네티스를 통해 배포된 젠킨스 워커는 Dynamic Worker 로써 필요에 따라서 생성/삭제되어 리소스를 지속적으로 점유하지 않는다.  

**Dynamic worker의 장점**
- 확장성 : 물리노드가 고정된게 아니라 Pod로 동작하기 때문에 작업부하가 커지면 Pod의 개수만 늘리면 된다. 
- 리소스 효율 : 지정된 노드가 아니기 때문에 빌드작업이 없을때는 동일한 노드에 다른 Pod를 실행시킬 수 있다.  
- 관리 용이 : 젠킨스 클러스터를 따로 모니터링 할 필요 없이 쿠버네티스에게 전적으로 맡길 수 있다.  
- 비용 : 물리적인 노드를 고정 점유하는것이 아니라서 비용효울이 높다.  

**Dynamic worker의 단점**
- 노드 콜드 스타트 : 물리적 노드가 아니더라도 필요할때마다 Pod(가상 노드)를 생성해야하기 때문에 그 만큼의 지연시간이 발생한다.  
- 아티팩트 휘발 : 워커에서 생성된 결과(artifact)가 잡이 종료되면 같이 삭제되기 때문에 별도 중앙 저장소에 저장해야한다. (PVC)
- 어려운 디버깅 : Pod가 삭제되 로그기록도 같이 사라져 디버깅이 어려울 수 있다.  

Dynamic Worker의 단점을 보완하기 위해 쿠버네티스 클러스터 위에서 가상노드(Pod)를 고정시켜 젠킨스 클러스터를 운용할 수도 있다.  

**가상노드(worker)를 고정하는 경우**
- 리소스 요구사항 : 특정 빌드 작업이 많은 메모리나 CPU를 필요로 하는 경우, 해당 리소스가 충분한 특정 노드에 워커를 고정할 수 있습니다.
- 특수 하드웨어 활용 : GPU나 특수 스토리지가 필요한 빌드 작업은 해당 하드웨어가 있는 노드에 워커를 고정해야 합니다.
- 성능 일관성 : Dynamic Worker는 매번 다른 노드에 스케줄링될 수 있어 성능 편차가 발생할 수 있습니다. 고정된 워커는 일관된 성능을 제공합니다.
- 캐시 활용 : 빌드 캐시, 의존성 캐시 등이 로컬에 저장되어 있을 때, 같은 노드에서 실행되면 캐시 활용도가 높아져 빌드 속도가 향상됩니다.
- 네트워크 효율성 : 특정 네트워크 구성이나 서비스에 가까운 노드에 워커를 배치하면 네트워크 지연 시간을 줄일 수 있습니다.
- 보안 요구사항 : 특정 보안 구성이나 격리가 필요한 빌드 작업은 해당 조건을 만족하는 노드에 고정될 수 있습니다.
- 안정성 : Dynamic Worker는 언제든 종료되고 새로 생성될 수 있어 장기 실행 작업에 불안정할 수 있습니다. 고정된 워커는 더 안정적으로 유지됩니다.

### 2-2. CI 파이프라인
```bash
checkout -> build -> test -> push
```

이것을 코드로 작성하면 다음과 같다.  
```bash
# checkout
git clone $PROJECT
git checkout $BRANCH

# build
docker build . -t $USERNAME/$PROJECT

# test
docker run --entrypoint /test $USERNAME/$PROJECT

# push
docker login --username $USERNAME --password $PASSWORD
docker push $USERNAME/$PROJECT
```

### 2-3. DinD
젠킨스가 컨테이너로 구동되고 젠킨스 안에서 도커 이미지를 호스트에 생성해야 하기 때문에 결과적으로 도커안에서 도커를 사용하는 모양이 된다.  
도커안에서 도커를 실행시키는 방법은 크게 아래 두가지가 있다.  
보통 두번째 방법을 사용하고, 첫번째 방법은 문제가 발생할 소지가 있으므로 지양한다.  
1. 컨테이너 안에 도커 데몬서버를 내장시키는 방법
2. 컨테이너 안에서 호스트의 도커 서버를 참조하는 방법
  ```bash
  # docker socket을 볼륨으로 바인딩하여 참조하는 방법
  docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock docker
  ```

jenkins의 CI 파이프라인은 groovy라는 언어의 jenkinsfile로 정의되는데 간략하게 요약하면 아래 동작을 수행한다.  
```yaml
checkout:
  command: <
    bash -c "
    git clone \$PROJECT_URL"

build:
  command: <
    bash -c "
    cd \$PROJECT_NAME/pipeline-sample
    docker build -t \$PROJECT_NAME . "

test:
  command: <
    bash -c "
    docker run --entrypoint /test \$PROJECT_NAME"

push:
  command: <
    bash -c "
    docker login -u ${DOCKER_HUB_USER} -p ${DOCKER_HUB_PASSWORD}"
    docker tag \$PROJECT_NAME ${DOCKER_HUB_USER}/\$PROJECT_NAME
    docker push ${DOCKER_HUB_USER}/\$PROJECT_NAME"
```
요약하면,
- checkout : $PROJECT_URL 환경변수에 깃 리파지토리를 checkout 한다.  
- build : 해당 리파지토리의 도커 이미지를 생성한다.  
- test : 생성된 이미지를 /test 라는 명령으로 테스트한다.  
- push : 테스트가 완료된 이미지를 도커 허브에 업로드한다.  

파이프라인 완료 후 빌드된 이미지가 도커허브에 생성된것을 확인할 수 있다.  


## 3. GitOps를 이용한 CD
### 3-1. GitOps란?

### 3-2. SSOT(단일 진실의 원천)
하나의 소스로 통합되어 배포까지 흘러가느냐, 각자 로컬에서 각기 다른 로컬 브랜치로 각기 배포하느냐의 차이.
git 저장소를 단일 진실의 원천으로 활용해 협업하는것을 GitOps라 한다.  

### 3-3. GitOps의 원칙
1. 선언형 배포 작업 정의서(YAML)
2. git을 이용한 배포 버전 관리
3. 변경 사항 운영 반영 자동화
4. 이상 탐지 및 자가 치유


### 3-4. FluxCD
GitOps 구현체 중 하나이다.  
helm chart 로 손쉽게 구성해볼 수 있다.
```bash
# flux repo 추가
h repo add fluxcd https://charts.fluxcd.io

# repo 업데이트
h repo update

# crd 생성
k apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml

# 네임스페이스 생성
k create ns flux

# fluxcd 차트 배포
h install get-started fluxcd/flux \
  --version 1.4.0 \
  --set git.url=https://github.com/core_kuberenetes.git \
  --set git.readonly=true \
  --set git.path=gitops \
  --namespace flux
```
- `git.url` : 소스 repo (SSOT)
- `git.readonly` : git pull 만 수행하겠다. 라는 뜻
- `git.path` : git repo의 특정 디렉토리 아래만 참조하겠다는 뜻

fluxcd 차트 배포가 완료되면 개발자가 직접 배포 스크립트를 작성하지 않아도 fluxcd가 소스변경점을 감지해 소스(git.url)를 참조하여 대신 배포해준다.  

### 3-5. ArgoCD
GitOps 구현체 중 하나이다.  
fluxcd 와는 다르게 웹 UI를 지원해 웹 인터페이스를 통해 쿠버네티스 리소스를 배포할 수 있다.  
fluxcd는 git repo마다 세팅해줘야 하는데 ArgoCD는 하나 설치하면 여러 git repo를 연결해 배포시스템을 구축할 수 있다.  

Dive to Argo : https://dive-argo.haulrest.me

## 4. 로컬 쿠버네티스 개발
### 4-1. skaffold
skaffold는 가볍고 사용하기 간단한 툴이지만 기능은 그렇지않은? 낭낭한 툴이다.  
코드 수정시 이미지 빌드, 이미지 업로드, Pod 교체, 로깅까지 자동으로 대신 해주는 툴이다. 
```bash
# skaffold 바이너리 설치
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/
```

### 4-2. skaffold 세팅
```bash
├── Dockerfile
├── pod.yaml
└── app.py
```

```bash
# 이미지로 배포되기 전에 도커 허브에 로그인 되어있어야 한다.
docker login

# 개발 디렉토리 안에서 실행
skaffold init
```

### 4-3. skaffold 배포
아래 명령어 실행 시 자동으로 이미지 빌드, 도커허브에 푸시, 클러스터에 배포까지 자동으로 수행한다.  
```bash
skaffold run
```

아래 명령어만 입력하면 logging 까지 자동으로 연결해준다.  
```bash
skaffold run --tail
```

마지막으로 `skaffold dev` 를 실행하면 `skaffold run` 과 동일하지만 소스코드나 도커파일을 수정하면 변경 사항을 인지하고 자동으로 다시 빌드부터 배포까지 수행하는 핫 리로드 기능이 활성화된다.  