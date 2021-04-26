#!/bin/bash
#
# Set-Sec-Toggle 1.1
#
# Sets / removes secrets variables into MDM-Enroll for FINAL testing & deployment
#
### WARNING: Once you've edited this scipt with your secrets, be sure sure to 
###########  add it to your .git-ignore file!!! Also, be absolutely sure you 
###########  do NOT commit your MDM-Enroll.command to your VCS once you've 
###########  embedded your secrets into it using this script!!!
#
# NOTE 1: If you're just testing in your local environment, you should be using
# Set-Env-Toggle.command instead, which uses environment variables to pass
# secrets to MDM-Enroll. You should ONLY use this in the final phase of testing
# or just prior to deployement, right before compiling MDM-Enroll using bashapp.
#
# NOTE 2: You must first edit all 2nd occurences of placeholder values 
# (3rd parameter of toggleSecVar) and replace them with your actual secrets 
# before running this script.
#
# NOTE 3: The environment variables set by Set-Env-Toggle.command always take 
# priority over any secrets you embed directly into MDM-Enroll.comnmand. To make
# sure any directly embedded secrets are in effect, run Set-Env-Toggle.command
# to remove environment variables.
#
# NOTE 4: When switching from env vars to embedded vars, be sure to log out
# and back in to ensure env vars are no longer propagating from the parent 
# process (especially when double-clicking in Finder).


# toggleSecVar Function
#
# Sets secrets or replaces them with placeholders in MDM-Enroll script

toggleSecVar ()
{
    # Parameter format:   toggleSecVar [secretsVariableName]{string} [secretsPlaceholder]{string} [secretsValue]{string}

    if grep -Fq "$1=\"$2\"" "$scriptDirectory"/MDM-Enroll.command; then
        echo Embedding "$1" secret into MDM-Enroll...
        sed -i '' -Ee "s|$1=\"[^\"]+\"|$1=\"$3\"|g" "$scriptDirectory"/MDM-Enroll.command
    elif grep -Fq "$1=\"$3\"" "$scriptDirectory"/MDM-Enroll.command; then
        echo Removing "$1" secret and replacing with placeholder...
        sed -i '' -Ee "s|$1=\"[^\"]+\"|$1=\"$2\"|g" "$scriptDirectory"/MDM-Enroll.command
    fi
}


# Change to script's directory
scriptDirectory="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo

toggleSecVar "adminCredentialsURL" "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]" "[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"
toggleSecVar "adminCredentialsPassphrase" "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]" "[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"
toggleSecVar "logWebhookURL" "[LOG WEBHOOK URL GOES HERE]" "[LOG WEBHOOK URL GOES HERE]"
toggleSecVar "logUpdateWebhookURL" "[LOG UPDATE WEBHOOK URL GOES HERE]" "[LOG UPDATE WEBHOOK URL GOES HERE]"
toggleSecVar "organizationName" "[ORGANIZATION NAME GOES HERE]" "[ORGANIZATION NAME GOES HERE]"

echo
