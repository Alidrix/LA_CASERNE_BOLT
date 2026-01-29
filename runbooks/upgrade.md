# Upgrade

## Pré-requis
- Sauvegarde complète réalisée
- Fenêtre de maintenance validée

## Étapes
1. Mettre à jour les versions d'images dans les fichiers compose.
2. Redémarrer les services par DC.

```bash
docker compose -f compose/dc1/passbolt-app.compose.yml pull
docker compose -f compose/dc1/passbolt-app.compose.yml up -d
```

## Validation
- UI Passbolt OK
- Logs applicatifs propres
