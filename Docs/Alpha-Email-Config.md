# Alpha Email Configuration

This document describes the environment-specific email configuration scaffold for AuthServer.

## Environment behavior

- **Development** uses Papercut (`Email.Mode=DevPapercut`) with localhost SMTP defaults for local testing.
- **Alpha** uses sandbox SMTP (`Email.Mode=AlphaSandbox`) and forces delivery to a central inbox via `Email.OverrideRecipients`.
- **Beta** disables email delivery (`Email.Mode=Disabled`).

## Secrets management

Do not commit real SMTP credentials to source control.

Use one of the following for sensitive values (for example `Email:Smtp:Username` and `Email:Smtp:Password`):

- .NET user-secrets for local development.
- Environment variables in deployed environments.

Keep committed `appsettings*.json` values non-sensitive placeholders only.
