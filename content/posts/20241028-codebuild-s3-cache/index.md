---
title: "[CodeBuild] S3 캐시로 빌드 시간 줄이기"
date: 2024-10-28T14:42:30+09:00
draft: true
categories: [guide]
tags: [CodeBuild, S3, CICD]
description: ""
slug: ""
series: ["CodeBuild"]
series_order: 1
authors:
  - P373R
---
## 1. CodeBuild

### 1-1. 캐시용 S3 버킷 생성

### 1-2. CodeBuild 프로젝트 생성

### 1-3. CodeBuild 프로젝트 Role 권한 설정
```json
{
    "Effect": "Allow",
    "Resource": [
        "arn:aws:s3:::codepipeline-ap-northeast-2-*",
        "arn:aws:s3:::integration-crm-build-cache",
        "arn:aws:s3:::integration-crm-build-cache/*"
    ],
    "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:DeleteObject"
    ]
},
```

## 2. Buildspec.yml
### 2-1. Java
```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      java: corretto17
  build:
    commands:
      - chmod +x ./gradlew
      - ./gradlew assemble
  post_build:
    commands:
      - mv ./build/libs/*.jar ./build/libs/app.jar
      - echo $(basename ./build/libs/*.jar)
      - pwd
artifacts:
  files:
    - 'build/libs/*'
    - 'appspec.yml'
    - 'docker/**/*'
    - 'scripts/**/*'
  name: demo-be/$(date +%Y-%m-%d)
cache:
  paths:
    - '/root/.gradle/caches/**/*'
    - '/root/.gradle/wrapper/**/*'
```

### 2-2. Vue.js
```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 18.16
    commands:
      - echo "Check Node Version $(node -v)"
      - echo "Check NPM Version $(npm -v)"
  pre_build:
    commands:
      - npm install
  build:
    commands:
      - npm run build
      - ls -al ./dist/
      - pwd
artifacts:
  files:
    - '/tmp/env.txt'
    - 'dist/**/*'
    - 'appspec.yml'
    - 'scripts/**/*'
  name: demo-fe/$(date +%Y-%m-%d)
cache:
  paths:
    - '/root/node_modules/**/*'
    - '/root/.npm/**/*'
```