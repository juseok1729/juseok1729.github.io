---
title: "[Apache] 웹서버 성능 튜닝하기"
date: 2024-10-14T18:18:00+09:00
draft: true
categories: [guide]
tags: [apahce, performance-tuning, optimization]
description: ""
slug: ""
series: ["Apache Performance Tuning"]
series_order: 1
authors:
  - P373R
---

```bash 
curl -sLf https://cloud-tech.cafe24.com/mpm | bash -
```

```bash
curl -sL https://raw.githubusercontent.com/richardforth/apache2buddy/master/apache2buddy.pl | perl
```

1. Apache MPM 모듈 종류 확인
```bash
apachectl -V | grep MPM
```



fields @timestamp, @message
| parse @message '"log":"*"' as logMessage
| sort @timestamp desc
| limit 10000
| display @timestamp, logMessage