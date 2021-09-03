[CmdletBinding()]
Param 
(
    [Parameter (Mandatory=$true, HelpMessage="Personal access token granting permissions to make calls to Appcenter api")]
    [ValidateNotNullOrEmpty()]
    [string]$PAT,
    [Parameter(Mandatory = $True, HelpMessage="Appcenter account alias")]
    [ValidateNotNullOrEmpty()]
    [string]$ownerName,
    [Parameter(Mandatory = $True, HelpMessage="Application name")]
    [ValidateNotNullOrEmpty()]
    [string]$appName
)

function Send-APIRequestWithBody {
    Param
    (
        [Parameter(Mandatory = $True)]
        [string]$uri,
        [string]$method = "Get",
        [string]$authorization = "X-API-Token",
        [string]$requestBody
    )
    
    try {
        if ($requestBody) {
            $request = Invoke-RestMethod -ContentType "application/json" -Uri $uri -Headers @{$authorization = $PAT } -Method $method -body $requestBody
        } else {
            $request = Invoke-RestMethod -ContentType "application/json" -Uri $uri -Headers @{$authorization = $PAT } -Method $method
        }
        return $request
    } catch {
        Write-Warning "Unable to get data from '$uri': $($_.Exception.Message)"
    }
}

$branchUri = "https://api.appcenter.ms/v0.1/apps/$($ownerName)/$($appName)/branches"
#Get list of branches
$branches = Send-APIRequestWithBody -uri $branchUri
#Sample body json for queue build api call
$bodyJson = '{
    "debug": true
  }'

#Queueing and build and monitoring it sequentially
  foreach ($branch in $branches) {
    #Branch name from the branch object as a separate variable
    $branchName = $branch.branch.name
    $buildUri = "https://api.appcenter.ms/v0.1/apps/$($ownerName)/$($appName)/branches/$($branchName.Replace('/', '%2F'))/builds"
    #Queue build
    $build = Send-APIRequestWithBody -uri $buildUri -Method Post -requestBody $bodyJson
    Write-Output "Queued build $($build.buildNumber) for branch $($branchName) status $($build.status)"
    $queuedBuildUri = "https://api.appcenter.ms/v0.1/apps/$($ownerName)/$($appName)/builds/$($build.buildNumber)"
    #Monitoring queued build
    while ($build.status -ne "completed") {
        $build = Send-APIRequestWithBody -uri $queuedBuildUri
        Write-Output "build $($build.buildNumber) for branch $($branchName) status $($build.status)"
        Start-Sleep -Seconds 10
    }
    #Calculating build duration
    $duration = (Get-Date $build.finishTime) - (Get-Date $build.startTime)
    $logs = Send-APIRequestWithBody -uri "https://api.appcenter.ms/v0.1/apps/$($ownerName)/$($appName)/builds/$($build.buildNumber)/downloads/logs"
    Write-Output "build $($build.buildNumber) for branch $($branchName) status $($build.status) result $($build.result) in $($duration.Seconds) seconds"
    Write-Output "You can download build logs by the following link: $($logs.uri)"
}
