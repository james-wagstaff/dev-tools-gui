function getCFApi {
    return [System.Environment]::getEnvironmentVariable('CF_API', [System.EnvironmentVariableTarget]::User)
}
function global:getCFUser {
    return [System.Environment]::getEnvironmentVariable('CF_USER', [System.EnvironmentVariableTarget]::User)
}

function global:getCFPassword {
    return [System.Environment]::getEnvironmentVariable('CF_PASSWORD', [System.EnvironmentVariableTarget]::User)
}

function global:setCFApi($apiEndpoint) {
    [System.Environment]::SetEnvironmentVariable('CF_API', $apiEndpoint, [System.EnvironmentVariableTarget]::User)
}
function global:setCFUser($username) {
    [System.Environment]::SetEnvironmentVariable('CF_USER', $username, [System.EnvironmentVariableTarget]::User)
}

function global:setCFPassword($password) {
    [System.Environment]::SetEnvironmentVariable('CF_PASSWORD', $password, [System.EnvironmentVariableTarget]::User)
}

function global:areCFPropsSet {
    return -Not [string]::IsNullOrEmpty($(getCFApi)) 
    -and -Not [string]::IsNullOrEmpty($(getCFUser)) 
    -and -Not [string]::IsNullOrEmpty($(getCFPassword))
}