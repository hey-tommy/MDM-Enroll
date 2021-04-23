#!/bin/bash

if [[ "$SHELL" == "/bin/zsh" ]]; then
    envVarsFile=".zshenv"; fi

if [[ "$SHELL" == "/bin/bash" ]]; then
    envVarsFile=".bash_profile"; fi

sed -i '' '/^export adminCredentialsURL.*/d' ~/"$envVarsFile"
sed -i '' '/^export adminCredentialsPassphrase.*/d' ~/"$envVarsFile"
sed -i '' '/^export logWebhookURL.*/d' ~/"$envVarsFile"
sed -i '' '/^export logUpdateWebhookURL.*/d' ~/"$envVarsFile"
sed -i '' '/^export organizationName.*/d' ~/"$envVarsFile"
