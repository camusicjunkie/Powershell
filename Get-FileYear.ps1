$share = Get-WmiObject -Class Win32_Share -Filter "Type=0 and name like 'Videos'"

Get-ChildItem $share.Path -Recurse -File | Select-Object FullName, LastWriteTime, Extension, 
                                     @{n="Age";e={(Get-Date) - $_.LastWriteTime}},
                                     @{n="Year";e={$_.LastWriteTime.Year}} | Group-Object Year -NoElement | Sort-Object Name