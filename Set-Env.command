#!/bin/bash

if [[ "$SHELL" == "/bin/zsh" ]]; then
    envVarsFile=".zshenv"; fi

if [[ "$SHELL" == "/bin/bash" ]]; then
    envVarsFile=".bash_profile"; fi

echo 'export adminCredentialsURL="[ENCRYPTED CREDENTIALS STRING URL GOES HERE]"' >> ~/"$envVarsFile"
echo 'export adminCredentialsPassphrase="[ENCRYPTED CREDENTIALS PASSPHRASE GOES HERE]"' >> ~/"$envVarsFile"
echo 'export logWebhookURL="[LOG WEBHOOK URL GOES HERE]"' >> ~/"$envVarsFile"
echo 'export logUpdateWebhookURL="[LOG UPDATE WEBHOOK URL GOES HERE]"' >> ~/"$envVarsFile"
echo 'export organizationName="[ORGANIZATION NAME GOES HERE]"' >> ~/"$envVarsFile"
