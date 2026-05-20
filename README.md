# with-secrets

A tiny cross-platform CLI that loads project secrets from **AWS SSM Parameter
Store** into your process environment via [`chamber`](https://github.com/segmentio/chamber).
One tool, many repos, no `.env` files in your working tree.

```sh
with-secrets bin/rails console
with-secrets -e staging bin/dev
with-secrets --dotenv > .env.local
```

## Why

- Stop committing `.env.example` and pasting secrets into chat to onboard people.
- One source of truth (AWS) for development env vars, with audit log + version history.
- IAM-controlled access — teammates get secrets by being in your AWS org, not by
  copying files.
- Works identically across all your repos. Per-repo configuration is a single
  optional file (`.chamber`).

## Install

### macOS / Linux

```sh
curl -fsSL https://raw.githubusercontent.com/dokioco/with-secrets/main/install.sh | bash
```

Or with chamber + awscli bundled in:

```sh
INSTALL_CHAMBER=1 curl -fsSL https://raw.githubusercontent.com/dokioco/with-secrets/main/install.sh | bash
```

This drops `with-secrets` into `~/.local/bin`. Make sure that's on your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"   # add to ~/.zshrc or ~/.bashrc
```

### Dependencies

- [`chamber`](https://github.com/segmentio/chamber) — `brew install chamber` (macOS)
  or download the Linux binary release.
- [`awscli`](https://aws.amazon.com/cli/) — v1 or v2.

## Usage

In any project that has secrets stored under a known SSM path:

```sh
with-secrets <command> [args...]
```

The default environment is `development`. To target another env:

```sh
with-secrets -e staging bin/rails console
WITH_SECRETS_ENV=test with-secrets bin/rspec
```

Other modes:

```sh
with-secrets --print          # KEY=value lines (read-only inspection)
with-secrets --export         # `export KEY=value` lines (eval-friendly)
with-secrets --dotenv         # standard .env file format
with-secrets --service-name   # show resolved chamber service path
```

## Per-repo configuration

`with-secrets` resolves the chamber service path automatically. In most cases
you don't need any config: dropping the tool into a repo named `foo` will pull
from `/foo/development/*` by default.

If you want to override or share defaults, drop a `.chamber` file at the repo
root:

```ini
# .chamber
service_prefix=foo            # SSM path prefix (combined with env)
env=development               # default env
profile=dokio-dev             # default AWS profile
region=us-east-1              # default AWS region
```

For full override (ignores `--env`):

```ini
service=acme/dokio/development
```

### Service resolution order

First match wins:

1. `--service` CLI flag
2. `CHAMBER_SERVICE` env var
3. `service=` in `.chamber`
4. `service_prefix=` + env in `.chamber`
5. `<repo-name>/<env>` derived from `git remote get-url origin` or directory
   basename

### Env / profile / region precedence

| Source                              | Service | Env | Profile | Region |
|-------------------------------------|:-------:|:---:|:-------:|:------:|
| CLI flag                            | 1       | 1   | 1       | 1      |
| Existing process env var            | 2       | 2   | 2       | 2      |
| `.chamber` file                     | 3       | 3   | 3       | 3      |
| Built-in default                    | repo-name + env | `development` | (none) | `us-east-1` |

## Adopting in a new repo

1. Decide your SSM path. If your repo is `acme/my-service`, the default is
   `/my-service/development/*`. Override via `.chamber` if you need an
   org/team prefix.
2. Upload your existing env file:
   ```sh
   # convert .env to JSON
   ruby -r json -e '
     h = {}
     File.foreach(".env.development.local") do |l|
       l = l.strip; next if l.empty? || l.start_with?("#")
       k, v = l.split("=", 2); next unless k && v
       v = v[1..-2] if v =~ /\A".*"\z/ || v =~ /\A'\''.*'\''\z/
       h[k] = v unless v.to_s.empty?
     end
     File.write("/tmp/secrets.json", JSON.pretty_generate(h))
   '
   CHAMBER_KMS_KEY_ALIAS=aws/ssm chamber import my-service/development /tmp/secrets.json
   shred -u /tmp/secrets.json 2>/dev/null || rm -f /tmp/secrets.json
   ```
3. (Optional) add a `.chamber` file if defaults aren't right.
4. Done. Run `with-secrets <your command>`.

## AWS setup

### IAM policy (per AWS account)

Attach this policy to whoever needs to read/write dev secrets:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ChamberSSMReadWrite",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:ListTagsForResource",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource"
      ],
      "Resource": "arn:aws:ssm:*:<ACCOUNT-ID>:parameter/*"
    },
    {
      "Sid": "ChamberSSMDescribeAll",
      "Effect": "Allow",
      "Action": "ssm:DescribeParameters",
      "Resource": "*"
    },
    {
      "Sid": "ChamberKMSForSecureString",
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:Encrypt"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "ssm.us-east-1.amazonaws.com",
            "ssm.ap-southeast-4.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

Tighten the `Resource` ARN to `parameter/<prefix>/*` if you want per-prefix
scoping (e.g. one team can only touch `/platform/*`).

### Encryption

Secrets are encrypted at rest with KMS. By default `chamber` looks for an alias
called `parameter_store_key`. To use the free AWS-managed key
(`alias/aws/ssm`):

```sh
export CHAMBER_KMS_KEY_ALIAS=aws/ssm   # add to your shell rc, or set per repo
```

`with-secrets` does not override this — set it once in your shell.

## Direct chamber usage

`with-secrets` is just a thin convenience layer. For one-off operations:

```sh
chamber list <service>                  # list keys (no values)
chamber read <service> KEY
chamber write <service> KEY 'value'
chamber delete <service> KEY
chamber history <service> KEY
chamber import <service> file.json      # bulk import
chamber export -f dotenv <service>      # bulk export
```

## License

MIT.
