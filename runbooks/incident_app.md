# Incident applicatif Passbolt

## Symptômes
- Erreurs 5xx sur l'UI Passbolt
- Traefik ne route plus vers l'app
- Temps de réponse anormalement long

## Diagnostic rapide
```bash
docker ps --filter name=passbolt
docker logs --tail=200 dc1-passbolt
```

## Actions de remédiation
1. Vérifier la connectivité DB depuis le conteneur.
2. Redémarrer le conteneur si besoin.

```bash
docker restart dc1-passbolt
```

## Validation
- Accès à l'URL Passbolt
- Logs applicatifs propres
