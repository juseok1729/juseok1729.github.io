---
title: "GitLab Issue 알림 봇"
date: 2025-02-10T01:08:47+09:00
draft: true
categories: [cat1, cat2]
tags: [tag1, tag2]
description: ""
slug: ""
series: []
series_order: 1
authors:
  - P373R
---

## 시퀀스 다이어그램
<div style="background-color:white; padding: 5px;">
{{< mermaid >}}
sequenceDiagram
    %%{init:{"themeVariables": {
      "noteBkgColor":"#FC6D27", 
      "noteTextColor":"white",
      "noteBorderColor":"#FC6D27"
    }}}%%
    
    autonumber
    participant pm as PM(기획)
    participant des as 디자이너
    participant gl as GitLab
    participant sl as Slack
    participant fi as Figma
    participant pl as PL(백엔드)
    participant dev as 개발자
    
    rect rgb(217, 234, 255)
      pm ->> +gl: issue 생성
      gl ->> -sl: issue 생성 알림
    end
    
    rect rgb(252, 212, 212)
      sl -->> des: 알림 수신
      des ->> +gl: issue 내용 확인
      Note over des,gl: Assignee 본인 할당<br/>Labels 상태 변경
      
      gl ->> -sl: assign 알림
      sl -->> des: assgin 알림 수신
      des ->> fi: 디자인 작업
      fi -->> +gl: 작업물 업로드(v1)
    end
    
    gl ->> -sl: issue 변경사항 알림
    
    alt 반려
      rect rgb(222, 222, 222)
        sl -->> pm: 알림 수신
        pm ->> +gl: 디자인 수정 요청
        gl ->> -sl: 수정 요청 알림
        sl -->> des: 알림 수신
        des ->> fi: 디자인 요청사항 반영
        fi -->> +gl: 작업물 업로드(v2)
      end
      
      gl ->> -sl: 변경사항 알림
      
    else 통과
      rect rgb(225, 252, 215)
        rect rgb(217, 234, 255)
          sl -->> pm: 알림 수신
          pm ->> gl: 수정사항 확인
          pm ->> +gl: 코멘트 해결
          gl ->> -sl: resolv 알림
          pm ->> +gl: mr 생성
          Note over pm,gl: Branch: feature/login<br/>Source: feature
        end
        
        gl ->> -sl: mr 생성 알림
        
        rect rgb(255, 246, 148)
          sl -->> dev: 알림 수신
          dev ->> gl: mr 확인 및 관련 issue 확인(기능 파악)
          gl -->> dev: feature/login  클론
          dev ->> +gl: 개발기능 commit
        end
        
        gl ->> -sl: 변경사항 알림(직접 멘션)
        
        rect rgb(226, 199, 255)
          sl -->> pl: 알림 수신
          pl ->> gl: 개발 페이지 검수
          pl ->> +gl: mr > commits 코드리뷰
        end
        
        gl ->> -sl: review 알림
        
        rect rgb(255, 246, 148)
          sl -->> dev: 알림 수신
          dev ->> +gl: 기능수정 commit
        end
        
        gl ->> -sl: 변경사항 알림(직접 멘션)
        
        rect rgb(226, 199, 255)
          sl -->> pl: 알림 수신
          pl ->> gl: 개발 페이지 검수
          pl ->> gl: mr > commits 리뷰
          pl ->> gl: Resolve thread(리뷰 완료)
          pl ->> gl: Mark as ready(Draft 플래그 제거)
          pl ->> gl: MR Approve(Optional)
          Note over pl,gl: Premium 라이센스부터 강제 가능
          pl ->> +gl: MR Merge
        end
        gl ->> -sl: MR 머지 알림
        sl -->> pm: 알림 수신
      end
    end
{{< /mermaid >}}
</div>