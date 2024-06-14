#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"
hugo server -D -b http://localhost -p 1313 --bind 0.0.0.0

# gh-pages branch
cd public
git add .

msg="🔁 Ci: 배포 `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"
git push origin gh-pages


# main branch
cd ..
git add .

msg="🔁 Ci: 배포 `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"
git push origin main
