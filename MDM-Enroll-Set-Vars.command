#!/bin/bash

if [[ "$SHELL" == "/bin/zsh" ]]; then
    envVarsFile=".zshenv"; fi

if [[ "$SHELL" == "/bin/bash" ]]; then
    envVarsFile=".bash_profile"; fi

echo 'export adminCredentialsURL=""' >> ~/"$envVarsFile"
echo 'export adminCredentialsPassphrase=""' >> ~/"$envVarsFile"
echo 'export logWebhookURL=""' >> ~/"$envVarsFile"
echo 'export logUpdateWebhookURL=""' >> ~/"$envVarsFile"
echo 'export organizationName=""' >> ~/"$envVarsFile"
