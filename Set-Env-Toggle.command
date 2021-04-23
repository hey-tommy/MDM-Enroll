#!/bin/bash
#
# Set-Env-Toggle 1.2
#
# Adds / removes environment variables needed for local testing of MDM-Enroll
#
### WARNING: Once you've edited this scipt with your secrets, be sure sure to 
###########  add it to your .git-ignore file!!!
#
# NOTE: You must first edit the placeholder values (2nd parameter of toggleEnvVar)
# and replace them with your actual secrets before running this script.
#
# Once you're ready to compile your MDM-Enroll script using Platypus, embed your 
# secrets into MDM-Enroll.command, and run this script (containing your secrets  
# values you originally added), and it will remove the secrets environment 
# variables from your testing user profile.
#
# NOTE: The environment variables set by this script always take priority over 
# any secrets you have embedded directly into MDM-Enroll.comnmand.


# Determine default user shell and set correct file for environment variables
if [[ "$SHELL" == "/bin/zsh" ]]; then
    envVarsFile=".zshenv"; fi
if [[ "$SHELL" == "/bin/bash" ]]; then
    envVarsFile=".bash_profile"; fi

# toggleEnvVar () Function
#
# Adds/removes secrets environment variables to the current user profile

toggleEnvVar ()
{
    # Parameter format:   toggleEnvVar [secretsVariableName]{string} [secretsValue]{string}
    
    if ! grep -q "^export $1" ~/"$envVarsFile"; then
        echo export "$1"="$2" >> ~/"$envVarsFile"
    else
        sed -i '' "/^export $1.*/d" ~/"$envVarsFile"
    fi
}

toggleEnvVar "adminCredentialsURL" "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
toggleEnvVar "adminCredentialsPassphrase" "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
toggleEnvVar "logWebhookURL" "[LOG WEBHOOK URL GOES HERE]"
toggleEnvVar "logUpdateWebhookURL" "[LOG UPDATE WEBHOOK URL GOES HERE]"
toggleEnvVar "organizationName" "[ORGANIZATION NAME GOES HERE]"
