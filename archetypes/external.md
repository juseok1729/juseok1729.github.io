---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
categories: [cat1, cat2]
tags: [tag1, tag2]
externalUrl: ""
summary: ""
showReadingTime: false
_build:
  render: "false"
  list: "local"
---
