---
title: "SPOF"
date: 2024-10-23T12:33:18+09:00
draft: true
categories: [study]
tags: [SPOF, CS]
description: ""
slug: ""
series: ["Multi-Thread"]
series_order: 1
authors:
  - P373R
---

> SPOF : 단일 실패 지점



|   OSI 7 Layer   |        Protocol       |   TCP/IP Model   |                     Description                     |
|:-----------------:|---------------------|:------------------:|-----------------------------------------------------|
|        7        |  HTTP/HTTPS/FTP/DHCP  |  Application     |  프로토콜의 정보까지 인식해서 부하분산 가능                    |
|        4        |  TCP/UDP              |  Transport       |  부하분산 가능                                          |
|        3        |  IP                   |  Internet        |  다른 네트워크로 패킷 전송가능                              |
|        2        |  MAC                  |  DataLink        |  스위칭 허브, 정확한 목적지에 전송                           |
|        1        |  X                    |  Physical        |  더미 허브, 모두 전송 -> 임베디드(셋탑박스, 개발보드) 디버깅 할때  |