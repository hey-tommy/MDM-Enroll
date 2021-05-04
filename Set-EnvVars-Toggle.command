#!/bin/bash
#
# Set-EnvVars-Toggle 1.5
#
# Adds / removes environment variables needed for local testing of MDM-Enroll
#
### WARNING: To avoid accidentally committing or pushing your secrets, run the 
###########  following once you've got this in your local repo:
###########
###########  >>>   git update-index --skip-worktree Set-EnvVars-Toggle.command 
###########
###########  This will ensure that once you edit this scipt with your secrets, 
###########  those changes will NOT be tracked, comitted or pushed (you can undo
###########  later via no-skip-worktree). Also, be sure you do NOT commit your 
###########  MDM-Enroll.command once you've embedded secrets inside it.
#
# HOW-TO: Before running this script, edit the placeholder values in function 
# calls at bottom (2rd parameter of toggleEnvVar), replacing them with secrets
#
# NOTE 1: Once you're ready to compile your MDM-Enroll script using bashapp, run 
# your edited Set-Secrets-Toggle to embed your secrets into MDM-Enroll.command. 
# You should then run this script again to remove your secrets env variables.
#
# NOTE 2: The secrets variables embedded by Set-Secrets-Toggle take precedece 
# over any environment variables set by this script
#
# NOTE 4: Depending on how you're testing (e.g. double-clicking script or the
# compiled app in Finder), you may need to log out & back in before env 
# variables are in effect after they've been set by this script.
#
# NOTE 5: The compiled script and app bundle work fine with env variables.
# Only embed secrets into MDM-Enroll for final testing or prior to compilation.


# toggleEnvVar Function
#
# Adds/removes secrets environment variables to the current user environment

toggleEnvVar ()
{
    # Parameter format:   toggleEnvVar [secretsVariableName]{string} 
    #                                  [secretsValue]{string}
    
    if ! grep -q "^export $1" ~/"$envVarsFile"; then
        echo Setting environment variable for "$1" secret...
        echo export "$1"=\""$2"\" >> ~/"$envVarsFile"
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

toggleEnvVar "adminCredentialsURL" \
    "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
toggleEnvVar "adminCredentialsPassphrase" \
    "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
toggleEnvVar "logWebhookURL" \
    "[LOG WEBHOOK URL GOES HERE]"
toggleEnvVar "logUpdateWebhookURL" \
    "[LOG UPDATE WEBHOOK URL GOES HERE]"
toggleEnvVar "moreInfoURL" \
    "[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
toggleEnvVar "organizationName" \
    "[ORGANIZATION NAME GOES HERE]"

echo
