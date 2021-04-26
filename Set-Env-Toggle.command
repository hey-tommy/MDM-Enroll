#!/bin/bash
#
# Set-Env-Toggle 1.3
#
# Adds / removes environment variables needed for local testing of MDM-Enroll
#
### WARNING: To avoid accidentally committing or pushing your secrets, run the 
###########  following command once you've got this in your local repo!!!
###########
###########  >>>   git update-index --skip-worktree Set-Env-Toggle.command 
###########
###########  This will ensure that once you edit this scipt with your secrets, 
###########  those changes will NOT be tracked, comitted or pushed. Also, be  
###########  absolutely sure you do NOT commit your MDM-Enroll.command once 
###########  you've embedded your secrets directly inside it!
#
# NOTE 1: You must first edit the placeholder values (2nd parameter of toggleEnvVar)
# and replace them with your actual secrets before running this script.
#
# NOTE 2: Once you're ready to compile your MDM-Enroll script using bashapp, use 
# Set-Sec-Toggle.command to embed your secrets into MDM-Enroll.command, and run 
# this script (containing your secrets values you originally added), and it will
# remove the secrets environment variables from your testing user profile.
#
# NOTE 3: The environment variables set by this script always take priority over 
# any secrets you have embedded directly into MDM-Enroll.comnmand.
#
# NOTE 4: Depending on how you're testing (e.g. double-clicking script or 
# compiled app through Finder), you may need to log out & back in to ensure that 
# env variables are in effect after they've been set by this script.
#
# NOTE 5: The compiled script and app bundle should work fine with env variables.
# Only embed secrets into MDM-Enroll for final testing, and be sure to log out
# and back in after switching from env vars to embedded vars.


# toggleEnvVar Function
#
# Adds/removes secrets environment variables to the current user environment

toggleEnvVar ()
{
    # Parameter format:   toggleEnvVar [secretsVariableName]{string} [secretsValue]{string}
    
    if ! grep -q "^export $1" ~/"$envVarsFile"; then
        echo Setting environment variable for "$1" secret...
        echo export "$1"="$2" >> ~/"$envVarsFile"
    else
        echo Removing environment variable for "$1" secret...
        sed -i '' "/^export $1.*/d" ~/"$envVarsFile"
    fi
}


# Determine default user shell and set correct file for environment variables
if [[ "$SHELL" == "/bin/zsh" ]]; then
    envVarsFile=".zshenv"; fi
if [[ "$SHELL" == "/bin/bash" ]]; then
    envVarsFile=".bash_profile"; fi

echo

toggleEnvVar "adminCredentialsURL" "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
toggleEnvVar "adminCredentialsPassphrase" "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
toggleEnvVar "logWebhookURL" "[LOG WEBHOOK URL GOES HERE]"
toggleEnvVar "logUpdateWebhookURL" "[LOG UPDATE WEBHOOK URL GOES HERE]"
toggleEnvVar "organizationName" "[ORGANIZATION NAME GOES HERE]"

echo