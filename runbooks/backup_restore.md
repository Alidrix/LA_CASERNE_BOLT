# Backup & Restore

## Sauvegarde
- Sauvegarder volumes Passbolt (GPG/JWT)
- Sauvegarder volumes DB

```bash
sudo tar -czf backup-passbolt.tgz volumes/passbolt
sudo tar -czf backup-db.tgz volumes/db
```

## Restauration
```bash
sudo tar -xzf backup-passbolt.tgz -C /workspace/LA_CASERNE_BOLT
sudo tar -xzf backup-db.tgz -C /workspace/LA_CASERNE_BOLT
```

## Validation
- Passbolt démarre sans erreur
- Comptes accessibles
