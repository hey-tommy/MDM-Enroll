#!/bin/bash

if [[ "$SHELL" == "/bin/zsh" ]]; then
    sed -i '' '/^export adminCredentialsURL.*/d' ~/.zshenv
    sed -i '' '/^export adminCredentialsPassphrase.*/d' ~/.zshenv
    sed -i '' '/^export logWebhookURL.*/d' ~/.zshenv
    sed -i '' '/^export logUpdateWebhookURL.*/d' ~/.zshenv
    sed -i '' '/^export organizationName.*/d' ~/.zshenv
fi

if [[ "$SHELL" == "/bin/bash" ]]; then
    sed -i '' '/^export adminCredentialsURL.*/d' ~/.bash_profile
    sed -i '' '/^export adminCredentialsPassphrase.*/d' ~/.bash_profile
    sed -i '' '/^export logWebhookURL.*/d' ~/.bash_profile
    sed -i '' '/^export logUpdateWebhookURL.*/d' ~/.bash_profile
    sed -i '' '/^export organizationName.*/d' ~/.bash_profile
fi
