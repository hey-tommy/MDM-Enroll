#!/bin/bash
#
# Set-Secrets-Toggle 1.3
#
# Adds / removes secrets variables in MDM-Enroll for FINAL testing & deployment
#
### WARNING: To avoid accidentally committing or pushing your secrets, run the 
###########  following once you've got this in your local repo:
###########
###########  >>>   git update-index --skip-worktree Set-Secrets-Toggle.command 
###########
###########  This will ensure that once you edit this scipt with your secrets, 
###########  those changes will NOT be tracked, comitted or pushed (you can undo
###########  later via no-skip-worktree). Also, be sure you do NOT commit your 
###########  MDM-Enroll.command once you've embedded secrets via this script,
#
# NOTE 1: If you're just testing in your local environment, you should be using
# Set-EnvVars-Toggle instead, which uses environment variables to pass secrets 
# to MDM-Enroll. You should ONLY use this script in the final phase of testing, 
# or just prior to deployement before compiling using bashapp.
#
# NOTE 2: The secrets variables embedded by this script take precedece over any 
# environment variables set via Set-EnvVars-Toggle
#
# HOW-TO: Before running this script, edit all 1st occurences of placeholder 
# values in the function calls below at the bottom of this script (2nd parameter 
# of toggleSecVar), replacing them with your actual secrets


# toggleSecVar Function
#
# Sets secrets or replaces them with placeholders in MDM-Enroll script

toggleSecVar ()
{
    # Parameter format:   toggleSecVar [secretsVariableName]{string} 
    #                                  [secretsValue]{string}
    #                                  [secretsPlaceholder]{string} 

    anchor="declare -a secretsActualValues=[^)]+?"
    escapedPlaceholder="$(echo "$3" | perl -pe 's{\[}{\\\[}')"
    findPlaceholderCommand="exit 1 if !m{(?:$anchor)$escapedPlaceholder}s"
    findSecretCommand="exit 1 if !m{(?:$anchor)$2}s"

    if perl -0777 -ne "$findPlaceholderCommand" "$scriptPath"; then
        replacePlaceholderCommand="s{($anchor)$escapedPlaceholder}{\${1}$2}s"
        echo Embedding "$1" secret into "$scriptName"...
        perl -0777 -i -pe "$replacePlaceholderCommand" "$scriptPath"
    elif perl -0777 -ne "$findSecretCommand" "$scriptPath"; then
        replaceSecretCommand="s{($anchor)\"$2\"}{\${1}\"$escapedPlaceholder\"}s"
        echo Removing "$1" secret and replacing with placeholder...
        perl -0777 -i -pe "$replaceSecretCommand" "$scriptPath"
    fi
}


# Set target script name
scriptName="MDM-Enroll"
scriptFileName="$scriptName"'.command'

# Get script directory & set target script path
scriptDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
scriptPath="$scriptDirectory"'/'"$scriptFileName"

echo

toggleSecVar "adminCredentialsURL" \
    "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]" \
    "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
toggleSecVar "adminCredentialsPassphrase" \
    "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]" \
    "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
toggleSecVar "logWebhookURL" \
    "[LOG WEBHOOK URL GOES HERE]" \
    "[LOG WEBHOOK URL GOES HERE]"
toggleSecVar "logUpdateWebhookURL" \
    "[LOG UPDATE WEBHOOK URL GOES HERE]" \
    "[LOG UPDATE WEBHOOK URL GOES HERE]"
toggleSecVar "moreInfoURL" \
    "[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]" \
    "[INTERNAL MDM ENROLLMENT INFO URL GOES HERE]"
toggleSecVar "organizationName" \
    "[ORGANIZATION NAME GOES HERE]" \
    "[ORGANIZATION NAME GOES HERE]"

echo
