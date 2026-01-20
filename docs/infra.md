# Managing infrastructure with opentofu and sops

## Sops

### Adding new members

```sh
# Generate new key using MacOS secure enclave
age-plugin-se keygen --access-control=any-biometry -o ~/.config/sops/age/secure-enclave-key.txt

# Get the public key
cat ~/.config/sops/age/secure-enclave-key.txt | grep public | grep -o 'age1se[[:alnum:]]*'
```

Then add the public key into `.sops.yaml` as new user.
Then regenerate all secret files so that the new user can read them:

```sh
sops -r -i --add-age ${NEW-PUBLIC-AGE-KEY-HERE} secrets/infra.yaml
```

### Editing secrets

```sh
sops edit secrets/infra.yaml
```