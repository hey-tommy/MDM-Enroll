#!/bin/bash

if [[ "$SHELL" == "/bin/zsh" ]]; then
    echo 'export adminCredentialsURL=""' >> ~/.zshenv
    echo 'export adminCredentialsPassphrase=""' >> ~/.zshenv
    echo 'export logWebhookURL=""' >> ~/.zshenv
    echo 'export logUpdateWebhookURL=""' >> ~/.zshenv
    echo 'export organizationName=""' >> ~/.zshenv
fi

if [[ "$SHELL" == "/bin/bash" ]]; then
    echo 'export adminCredentialsURL=""' >> ~/.bash_profile
    echo 'export adminCredentialsPassphrase=""' >> ~/.bash_profile
    echo 'export logWebhookURL=""' >> ~/.bash_profile
    echo 'export logUpdateWebhookURL=""' >> ~/.bash_profile
    echo 'export organizationName=""' >> ~/.bash_profile
fi
