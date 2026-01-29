# Incident base de données (Galera)

## Symptômes
- App indisponible (erreurs DB)
- Perte de quorum Galera

## Diagnostic rapide
```bash
docker ps --filter name=galera
docker logs --tail=200 dc1-galera-1
```

## Actions de remédiation
1. Vérifier la connectivité réseau inter-nœuds.
2. Redémarrer le nœud isolé.
3. Si besoin, rejointe du cluster avec les paramètres gcomm.

## Validation
- Cluster en état Primary
- Requêtes DB OK
