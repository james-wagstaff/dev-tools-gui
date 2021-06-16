$ProgressPreference = 'SilentlyContinue'

$my_app = $args[0]
$env = $args[1]

# Get config_server_key json
$config_server_key = $(cf service-key config-server config-server-key | sed '1,2d') | ConvertFrom-Json
# Get config server details from config_server_key variable
$access_token_uri = $config_server_key.access_token_uri
$client_id = $config_server_key.client_id
$client_secret = $config_server_key.client_secret
$uri = $config_server_key.uri

#Prepare headers for authentication
$pair = "$($client_id):$($client_secret)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

# Get the token using apps client credentials
$config_server_token = $(Invoke-WebRequest "$access_token_uri" -Headers $Headers -Body @{grant_type = 'client_credentials' } | ConvertFrom-Json).access_token

# Get the properties of my_app, in default profile
$my_app_properties = $(Invoke-WebRequest "$uri/$my_app/$env" -H @{"Authorization" = "bearer $config_server_token" })

$json = $($my_app_properties | ConvertFrom-Json)
$($json.propertySources | % {
        foreach ($info in $_.source.PSObject.Properties) {
            if ($info.Name -ne 'spring.profiles' -and $info.Name -ne 'configScope') {
                Add-Content "$my_app.properties" "$($info.Name)=$($info.Value)"
            }
        }
    })

# Get PCF ENV settings for app, allowing failure if app doesn't exist in current space, this used to fetch rabbit and mongo props
# $pcfEnvSettings = $(cf env $my_app)

Get-Content "$($my_app).properties"
Remove-Item "$($my_app).properties" -ErrorAction Ignore
