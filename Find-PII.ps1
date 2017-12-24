$path


Rename-Item -Path .\Resume.docx -NewName Resume.zip
Expand-Archive .\Resume.zip
[xml]$docx = Get-Content -Path .\Resume\word\document.xml
$docx
$patternSocial = '(\d{3}[-| ]\d{2}[-| ]\d{4})|(\d{9})'
$docx.document.body.p.r.t | Select-String -Pattern $patternSocial -Quiet