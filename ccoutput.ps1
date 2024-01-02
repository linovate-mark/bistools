$reconciledir = "/tmp/reconcile"

if(Test-Path $reconciledir)
{
    Write-Host("[*] Working Directory ready")
    $reconciledir_present = 1
}
else {
    Write-Host("[!] Working Directory Missing - Seeding")
    New-Item -Force -Path "$reconciledir" -ItemType Directory
}

if($reconciledir_present -eq $true)
{
    Write-Host "[*] Scanning available transaction data"
    $dircheck = Get-ChildItem -Path "$reconciledir" -Filter 'LinovateCC*'
    if($dircheck -eq $null)
    {
      Write-Host "[!] No actionable files found"
      Exit(1)
    }
    else
    {
      Write-Host "[*] Reading Data"
      ## Import CSVs
      $data = Import-Csv -Path  (Get-ChildItem -Path $reconciledir -Filter 'LinovateCC*').FullName

      # Add our extra properties to the objects
      $data | Add-Member -MemberType NoteProperty -Name 'Balance' -Value ''
      $data | Add-Member -MemberType NoteProperty -Name 'IN' -Value ''

      # Alias Property of Amount to Out
      $data | Add-Member -MemberType AliasProperty -Name 'Out' -Value 'Amount'

      Write-Host "[*] Casting Date to actual dates"
      $data | Foreach-Object {

            $dateorig = $_.Date.Replace('-', '/')
            $_.Date = [Datetime]::ParseExact($dateorig, 'dd/MM/yyyy', $null).ToString('yyyy/MM/dd')
      }

      Write-Host "[*] Scan for Payment Lines"
      $data | Foreach-Object {
            $data_amount = $($_.Amount.ToString())
            $data_merchant = ($_.Merchant.ToString())
            if($data_amount -like "*-*" -and $data_merchant -like "*PAYMENT RECEIVED*")
            {
              Write-Host "[i] Detected OOB Payment Line for $($_.Date) of $data_amount"
              # Move value from Out to IN
              $_.IN = $_.Out.Replace('-','')
              $_.Out = ''
              $_.Merchant = 'Business Credit Card Payment'
            }

            if($data_amount -like "*-*" -and $data_merchant -like "*DIRECT DEBIT*")
            {
              Write-Host "[i] Detected DD Payment Line for $($_.Date) of $data_amount"
              # Move value from Out to IN
              $_.IN = $_.Out.Replace('-','')
              $_.Out = ''
              $_.Merchant = 'Business Credit Card Payment'

            }

      }

      Write-Host "[*] Writing out CSV file"
      $data_processed = $data | select -Property Date, 'IN', Out, Merchant, Balance | Sort-Object -Property Date | Export-Csv .\Test.csv
      Write-Host "[*] Sanitising Date Fields"
      ((Get-Content -path .\Test.csv -Raw) -replace ' 00:00:00','') | Set-Content -Path .\Test.csv

      # FIXME - Add in range select
      # $incoming_balance = Read-Host -Prompt "[?] Please enter Balance from overlapping (already in accounting system) statement entry [eg. -123.98]):"
      # $incoming_bal_date = Read-Host -Prompt "[?] Please enter Merchant string from overlapping statement entry:"

    }
}
