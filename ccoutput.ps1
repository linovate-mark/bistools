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
            $dateconv = [Datetime]::ParseExact($dateorig, 'dd/MM/yyyy', $null)
            $_.Date = [DateTime]$dateconv

      }

      Write-Host "[*] Scan for Payment Lines"
      $data | Foreach-Object {
            $data_amount = $($_.Amount.ToString())
            $data_merchant = ($_.Merchant.ToString())
            if($data_amount -like "*-*" -and $data_merchant -like "*DIRECT DEBIT*")
            {
              Write-Host "Creating Payment Line for  $($_.Date)"
              $_ | ft
              $_.IN = $_.Out.Replace('-','')
              $_.Out = ''
              $_.Merchant = 'Business Credit Card Payment'

            }

      }

      $data | select -Property Date, 'IN', Out, Merchant, Balance | Sort-Object -Property Date | ft

    }
}
