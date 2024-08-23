# Define parameters
$opsviewBaseUrl = "https://sales.cloud.opsview.com/rest"  # Replace with your Opsview API base URL
$username = 'your_user_name'  # Replace with your Opsview username
$password = 'your_password'  # Replace with your Opsview password
$hostId = $env:computername  # Replace with the ID of the host or service
$durationMinutes = 15

# Authenticate and obtain the token
$loginUrl = "$opsviewBaseUrl/login"
$loginPayload = @{
    "username" = $username
    "password" = $password
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginPayload -ContentType "application/json"
    $token = $loginResponse.token
} catch {
    Write-Error "Failed to authenticate: $_"
    exit
}

# Create a timestamp for the start of the downtime (current time) and the end of the downtime (15 minutes later)
$startTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$endTime = (Get-Date).AddMinutes($durationMinutes).ToString("yyyy-MM-dd HH:mm:ss")

# Construct the API URL for scheduling downtime
$downtimeUrl = "$opsviewBaseUrl/downtime?hst.hostname=$env:computername"

# Create the downtime payload
$downtimePayload = @{
    "starttime" = $startTime
    "endtime" = $endTime
    "comment" = "Scheduled downtime via PowerShell script"
} | ConvertTo-Json

# Set up the headers with the obtained token
$headers = @{
    "X-Opsview-Token" = $token
}

write-host $downtimePayload

# Send the API request to schedule downtime
try {
    $response = Invoke-RestMethod -Uri $downtimeUrl -Method Post -Body $downtimePayload -ContentType "application/json" -Headers $headers
    Write-Output "Downtime successfully scheduled from $startTime to $endTime."
} catch {
    Write-Error "Failed to schedule downtime: $_"
}