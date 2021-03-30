#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$authorization = @{ "AERIES-CERT" = $config.certificateKey }
#endregion Initialize default properties

#region Change mapping here
    $schoolCode     = $p.primaryContract.department.ExternalId;
    $studentId      = $p.ExternalId;
    $studentNumber  = $p.primaryContract.custom.StudentNumber

    #New Email Address
    $currentEmail = $p.Accounts.Google.primaryEmail

    $account = [PSCustomObject]@{
            "Columns"= @(
                            [PSCustomObject]@{
                                "ColumnCode"= "STE"
                                "NewValue"= $currentEmail
                            }
            )
    }
#endregion Change mapping here

#region Execute
try {
    
    # Retrieve Current Data
    $splat = [ordered]@{
                Uri = "$($config.baseUri)/api/v5/schools/$($schoolCode)/SchoolSupplemental/$($studentId)"
                Method = 'GET'
                Headers = $authorization
                Verbose = $False
            }
        
           Write-Information $splat.Uri
           $previousAccount = (Invoke-RestMethod @splat).Columns | Where-Object { $_.ColumnCode -eq 'STE' }
           $existingEmail = $previousAccount.Value
    
    if($existingEmail -eq $currentEmail) {
        Write-Information "No update required. Email Address matches"
        $auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Found and correlated account. No update required"     
                IsError = $false
            });
        
        $newAccount = $previousAccount
    }
    else {
        if(-Not($dryRun -eq $True)) {
            $splat = [ordered]@{
                    Body = [System.Text.Encoding]::UTF8.GetBytes(($account | ConvertTo-Json -Depth 10))
                    Uri = "$($config.baseUri)/api/v5/UpdateSchoolSupplemental/$($schoolCode)/$($studentNumber)"
                    Method = 'POST'
                    Headers = $authorization
                    Verbose = $False
                    ContentType = "application/json"
                }
                
                Write-Information $splat.Uri;
                Write-Information ($account | ConvertTo-Json -Depth 50)
            $newAccount = (Invoke-RestMethod @splat).Columns | Where-Object { $_.ColumnCode -eq 'STE' }

            Write-Information "Found and updated Student Email Address from [$($existingEmail)] to [$($currentEmail)]";
            $auditLogs.Add([PSCustomObject]@{
                    Action = "CreateAccount"
                    Message = "Found and updated Student Email Address from [$($existingEmail)] to [$($currentEmail)]"     
                    IsError = $false;
                });
            
        }
    }
    $success = $true;
}
catch {
    Write-Error -Verbose $_; 
    $auditLogs.Add([PSCustomObject]@{
                    Action = "CreateAccount"
                    Message = "Failed to Update Student Email Address $($_)"     
                    IsError = $true;
                });
}
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success = $success
    AccountReference = [PSCustomObject]@{ studentId = $studentid; studentNumber = $studentNumber; schoolCode = $schoolCode }
    AuditLogs = $auditLogs;
    Account = $newAccount
    PreviousAccount = $previousAccount

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{
        StudentEmailAddress = $currentEmail;
    }
}

Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion build up result