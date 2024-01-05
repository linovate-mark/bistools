param (
    [string]$prefix = $(throw "-prefix is required."),
    [string]$reconciledir = "$PSScriptRoot/reconcile",
    [string]$outputdir = "$PSScriptRoot/output"
)

if(Test-Path $reconciledir)
{
    Write-Host("[*] Working Reconcile Directory $reconciledir ready")
    $reconciledir_present = 1
}
else {
    Write-Host("[!] Working Directory Missing - Seeding")
    New-Item -Force -Path "$reconciledir" -ItemType Directory
}

if(Test-Path $outputdir)
{
    Write-Host("[*] Output Directory $outputdir ready")
    $outputdir_present = 1
}
else {
    Write-Host("[!] Working Directory Missing - Seeding")
    New-Item -Force -Path "$outputdir" -ItemType Directory
}

if($reconciledir_present -eq $true -and $outputdir_present -eq $true)
{
    Write-Host "[*] Scanning available transaction data"
    $dircheck = Get-ChildItem -Path "$reconciledir" -Filter '*.csv'
    if($dircheck -eq $null)
    {
      Write-Host "[!] No actionable files found"
      Exit(1)
    }
    else
    {
      Write-Host "[*] Reading Data"
      ## Import CSVs
      $data = Import-Csv -Path  (Get-ChildItem -Path $reconciledir -Filter '*.csv').FullName

      # Add our extra properties to the objects
      $data | Add-Member -MemberType NoteProperty -Name 'Balance' -Value ''
      $data | Add-Member -MemberType NoteProperty -Name 'IN' -Value ''

      # Alias Property of Amount to Out
      $data | Add-Member -MemberType AliasProperty -Name 'Out' -Value 'Amount'

      Write-Host "[*] Reformat Dates to slash dates"
      $data | Foreach-Object {
            $dateorig = $_.Date.Replace('-', '/')
            $_.Date = "$dateorig"
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

      # Sort the object into date order
      $data_processed = $data | Select-Object -Property @{
        Name='Date';
        Expression={
            [datetime]::ParseExact($($_.Date),'dd/MM/yyyy',$culture)}
        }, 'IN', Out, Merchant, Balance | Sort-Object -Property Date

      # Extract the date range of the first and last object
      $data_processed_range_start = $data_processed | Select-Object -First 1 -Property Date
      $data_processed_range_end = $data_processed | Select-Object -Last 1 -Property Date
      # Flatten the slashes to make date range safe for filenames
      $date_start = $($data_processed_range_start.Date).ToString().Replace('/','')
      $date_end = $($data_processed_range_end.Date).ToString().Replace('/','')
      # Render these to variables to be used during output
      $outputfilename = "$prefix-$date_start-to-$date_end".Replace(' 00:00:00','')
      $outputfilepath = "$outputdir/$outputfilename"

      if(Test-Path "$outputfilepath.csv" -PathType Leaf)
      {
        Write-Host "[!] Error: CSV already exists, refusing to overwrite."
        Exit(1)
      }

      Write-Host "[*] Writing out CSV file to $outputdir/$outputfilename.csv"
      $data_processed | Export-Csv -NoTypeInformation "$outputfilepath.csv"
      Write-Host "[*] Sanitising Date Fields on resulting CSV"
      ((Get-Content -path "$outputfilepath.csv" -Raw) -replace ' 00:00:00','') | Set-Content -Path "$outputfilepath.csv"

      # FIXME - Add in range select
      # $incoming_balance = Read-Host -Prompt "[?] Please enter Balance from overlapping (already in accounting system) statement entry [eg. -123.98]):"
      # $incoming_bal_date = Read-Host -Prompt "[?] Please enter Merchant string from overlapping statement entry:"
      Write-Host "[i] Finished Processing please inspect the output carefully"
    }
}
